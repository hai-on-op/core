#!/usr/bin/env node
// Unsigned Safe call preparation only. Actual migrated IDs/receipts are mandatory; no prediction or sending.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {Contract,Interface,JsonRpcProvider,ZeroAddress} from 'ethers';
import {same,verifyRuntime} from './verification.mjs';
import {UPSTREAM_COMMIT,AERO,SAERO,VOTER,TREASURY,verifyIssuerDeployment,verifyBaseMigratorDeployment} from './prepare-deployment.mjs';
export const MIGRATIONS = {
  aerodrome:{address:'0x22a2F7340a3fB4C7C389D91eE954766B12476721',runtimeCodeHash:'0xb83856ce3d2c9475c52a8f598a9a17366288acf5777d9994ca3c1562895e5401'},
  velodrome:{address:'0x6daE95FE833f190640dB1176F8C8a2e50C6a66c0',runtimeCodeHash:'0xa3706a387e8400985e81333cdd0793d5f0c8b43a0e374414786839eedb034894'}
};
const need=(ok,message)=>{if(!ok)throw new Error(message);};
const events=new Interface(['event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)',
  'event VeNFTMigrated(address indexed depositor,address indexed recipient,uint256 indexed oldTokenId,uint256 amount,uint256 output,bool permanent,bool liquid)',
  'event Migrated(uint64 indexed nonce,address indexed recipient,uint256 amount,bool liquid)']);
const escrowAbi=['function ownerOf(uint256) view returns(address)','function staked(uint256) view returns(uint128 amount,uint48 end,bool isPermanent)',
  'function TOKEN() view returns(address)','function VOTER() view returns(address)',
  'function increaseStakingPeriod(uint256,uint48)','function upgradeToPermanentStake(uint256)'];
const issuerAbi=['function owner() view returns(address)','function treasury() view returns(address)','function BASE_TOKEN() view returns(address)',
  'function BASE_TOKEN_NFT() view returns(address)','function deploymentChainId() view returns(uint256)','function paused() view returns(bool)',
  'function principalOf(uint256) view returns(uint256)','function unpause()','function pause()','function depositNFTs(address,uint256[])'];
const rawUint=(value)=>typeof value==='string' && /^(0|[1-9][0-9]*)$/.test(value);

export function validateIntake(plan) {
  need(plan.schemaVersion===1 && plan.chainId===8453 && plan.positionsReviewed===true,'Reviewed Base intake selection required');
  need(plan.recipient==='treasury' || plan.recipient==='base-migrator','Recipient must be treasury or the verified Base migrator');
  need(Array.isArray(plan.positions) && plan.positions.length>0,'Actual migrated NFT positions required');
  const ids=new Set(),sourceKeys=new Set();
  for(const position of plan.positions) {
    need(MIGRATIONS[position.origin] && rawUint(position.tokenId) && BigInt(position.tokenId)>0n
      && rawUint(position.principal) && BigInt(position.principal)>0n,'Valid origin, actual NFT ID and exact principal required');
    need(!ids.has(position.tokenId),'Duplicate intake NFT');ids.add(position.tokenId);
    const sourceId=position.origin==='aerodrome'?position.oldTokenId:position.nonce;
    need(rawUint(sourceId),'Actual original NFT ID or settled nonce required');
    const sourceKey=position.origin+':'+sourceId;
    need(!sourceKeys.has(sourceKey),'Duplicated migration claim');sourceKeys.add(sourceKey);
    need(/^0x[0-9a-f]{64}$/i.test(position.transactionHash) && Number.isSafeInteger(position.blockNumber) && position.blockNumber>0
      && /^0x[0-9a-f]{64}$/i.test(position.blockHash),'Actual migration receipt and canonical block evidence required');
  }
}

export function verifyMigratedNFT(position,receipt) {
  need(receipt?.status===1,'Migration receipt failed or missing');
  const migration=MIGRATIONS[position.origin];
  const ordered=receipt.logs.map((log)=>({...log,order:log.index ?? log.logIndex})).sort((a,b)=>Number(a.order)-Number(b.order));
  let segmentStart=-1,matched=false;
  for(const log of ordered.filter((item)=>same(item.address,migration.address))) {
    let event;try{event=events.parseLog(log);}catch{continue;}
    if(!event || event.name!==(position.origin==='aerodrome'?'VeNFTMigrated':'Migrated'))continue;
    const identity=position.origin==='aerodrome'?event.args.oldTokenId:event.args.nonce;
    const expected=position.origin==='aerodrome'?position.oldTokenId:position.nonce;
    if(identity===BigInt(expected)) {
      need(!matched,'Duplicate matching settlement event');
      need(same(event.args.recipient,TREASURY) && !event.args.liquid,'Migration must settle sAERO directly to the treasury Safe');
      if(position.origin==='aerodrome') {
        need(same(event.args.depositor,TREASURY),'Unexpected source NFT depositor');
        need(event.args.amount===event.args.output,'Base migration must preserve canonical 1:1 principal');
      }
      need((position.origin==='aerodrome'?event.args.output:event.args.amount)===BigInt(position.principal),'Migration principal mismatch');
      const transfers=ordered.filter((item)=>same(item.address,SAERO.address) && Number(item.order)>segmentStart && Number(item.order)<Number(log.order))
        .flatMap((item)=>{try{const parsed=events.parseLog(item);return parsed?.name==='Transfer'?[parsed.args]:[];}catch{return [];}});
      const received=transfers.filter((t)=>same(t.from,migration.address) && same(t.to,TREASURY));
      need(received.length===1 && received[0].tokenId===BigInt(position.tokenId),'Settlement does not identify the selected received NFT');
      need(transfers.some((t)=>same(t.from,ZeroAddress) && same(t.to,migration.address) && t.tokenId===BigInt(position.tokenId)),
        'Selected NFT was not minted by this actual settlement');
      matched=true;
    }
    segmentStart=Number(log.order);
  }
  need(matched,'Canonical migration receipt lacks the selected settlement');
}

export function encodeIntakeCalls(issuer,recipient,positions,paused,timestamp) {
  const escrow=new Interface(escrowAbi),wrapper=new Interface(issuerAbi),transactions=[];
  const add=(to,iface,method,args,description)=>transactions.push({to,value:'0',data:iface.encodeFunctionData(method,args),description});
  if(paused)add(issuer,wrapper,'unpause',[],'Temporarily enable intake inside this atomic Safe batch');
  for(const position of positions) {
    if(!position.isPermanent) {
      if(BigInt(position.end)<=BigInt(timestamp))add(SAERO.address,escrow,'increaseStakingPeriod',[position.tokenId,1],
        'Renew expired funded stake to the next week boundary before permanent conversion');
      add(SAERO.address,escrow,'upgradeToPermanentStake',[position.tokenId],'Convert actual migrated sAERO to permanent mode without changing principal');
    }
  }
  add(issuer,wrapper,'depositNFTs',[recipient,positions.map((p)=>p.tokenId)],'Recognize selected previously unissued treasury principal exactly once');
  if(paused)add(issuer,wrapper,'pause',[],'Restore the issuer paused state within the same atomic Safe batch');
  return transactions;
}

export async function prepareIntake(manifest,plan,provider) {
  validateIntake(plan);
  need(Number(BigInt(await provider.send('eth_chainId',[])))===8453,'Base RPC required');
  const block=await provider.getBlock('finalized');need(block?.hash,'Finalized snapshot required');
  const snapshot={blockNumber:block.number,blockHash:block.hash,finalizedBlockNumber:block.number},options={blockTag:block.number};
  await verifyIssuerDeployment(manifest,provider,snapshot);
  for(const identity of [AERO,SAERO,VOTER])await verifyRuntime(provider,identity,block.number);
  const issuerAddress=manifest.base.wrapper.address,issuer=new Contract(issuerAddress,issuerAbi,provider);
  need(same(await issuer.owner(options),TREASURY) && same(await issuer.treasury(options),TREASURY)
    && same(await issuer.BASE_TOKEN(options),AERO.address) && same(await issuer.BASE_TOKEN_NFT(options),SAERO.address)
    && await issuer.deploymentChainId(options)===8453n,'Actual issuer identities differ from reviewed Safe custody');
  let recipient=TREASURY;
  if(plan.recipient==='base-migrator') {
    need(manifest.base.migrator,'Actual Base migrator receipt required');
    await verifyBaseMigratorDeployment(manifest,provider,snapshot);
    const migrator=new Contract(manifest.base.migrator.address,['function outputToken() view returns(address)','function treasury() view returns(address)',
      'function owner() view returns(address)','function deploymentChainId() view returns(uint256)'],provider);
    need(same(await migrator.outputToken(options),issuerAddress) && same(await migrator.treasury(options),TREASURY)
      && same(await migrator.owner(options),TREASURY) && await migrator.deploymentChainId(options)===8453n,'Actual Base migrator identities differ');
    recipient=manifest.base.migrator.address;
  }
  const escrow=new Contract(SAERO.address,escrowAbi,provider),positions=[];
  need(same(await escrow.TOKEN(options),AERO.address) && same(await escrow.VOTER(options),VOTER.address),'Canonical escrow bindings changed');
  for(const position of plan.positions) {
    const receipt=await provider.getTransactionReceipt(position.transactionHash);
    need(receipt?.status===1 && receipt.blockNumber===position.blockNumber && same(receipt.blockHash,position.blockHash)
      && receipt.blockNumber<=block.number,'Migration receipt changed or not finalized');
    need(same((await provider.getBlock(receipt.blockNumber)).hash,position.blockHash),'Migration receipt block is not canonical');
    await verifyRuntime(provider,MIGRATIONS[position.origin],receipt.blockNumber);
    verifyMigratedNFT(position,receipt);
    const stake=await escrow.staked(position.tokenId,options);
    need(same(await escrow.ownerOf(position.tokenId,options),TREASURY) && stake.amount===BigInt(position.principal),
      'Selected migrated principal is not currently held unchanged by the Safe');
    need(await issuer.principalOf(position.tokenId,options)===0n,'Selected NFT principal has already been issued');
    if(position.origin==='velodrome') {
      const entrypoint=new Contract(MIGRATIONS.velodrome.address,['function noncesUsed(uint64) view returns(bool)'],provider);
      need(await entrypoint.noncesUsed(position.nonce,options),'Destination nonce is not settled');
    }
    positions.push({...position,end:stake.end,isPermanent:stake.isPermanent});
  }
  const paused=await issuer.paused(options),transactions=encodeIntakeCalls(issuerAddress,recipient,positions,paused,block.timestamp);
  const canonical=await provider.getBlock(block.number);need(same(canonical.hash,block.hash),'Snapshot changed during preparation');
  return {schemaVersion:1,unsigned:true,broadcast:false,chainId:8453,upstreamCommit:UPSTREAM_COMMIT,snapshot,executionAuthority:TREASURY,
    issuer:issuerAddress,recipient,observedPaused:paused,
    validationScope:{atomicSafeMultiSendRehearsed:false,expiredRenewalUsed:positions.some((p)=>!p.isPermanent && p.end<=BigInt(block.timestamp)),expiredRenewalForkVerified:false},expectedMintedPrincipal:positions.reduce((sum,p)=>sum+BigInt(p.principal),0n),positions,transactions,
    safeTransactionBuilder:{version:'1.0',chainId:'8453',createdAt:Date.now(),meta:{name:'Recognize migrated sAERO backing',description:'Execute the complete ordered batch atomically; no NFT approval or custody transfer is required.',txBuilderVersion:'1.16.5',createdFromSafeAddress:TREASURY},
      transactions:transactions.map(({to,value,data})=>({to,value,data,contractMethod:null,contractInputsValues:null}))},
    limitations:['Unsigned preparation only. User executes the complete ordered Safe batch atomically; refresh evidence before signing.',
      'upgradeToPermanentStake preserves principal and re-anchors the Voter internally; no reset/deallocation is required for this conversion.',
      'Existing remote leaf allocation weights may need subsequent refresh through normal Safe voting operations.',
      'Previously issued backing must not be recycled through replacement IDs. Receipt-linked first intake does not remove the trusted Safe custody assumption.',
      'This mints receipts only against the selected actual Safe-owned migrated principal; it does not bridge, activate migration or initialize collateral.']};
}
async function main() {
  const args=process.argv.slice(2),option=(name)=>{const i=args.indexOf(name);return i<0?undefined:args[i+1];};
  const input=option('--manifest'),selection=option('--positions'),output=option('--output');
  need(input && selection && output,'Usage: --manifest ACTUAL_DEPLOYMENTS.json --positions ACTUAL_MIGRATED_NFTS.json --output PATH');
  need(!fs.existsSync(output),'Output already exists; choose a new evidence path');
  const manifest=JSON.parse(fs.readFileSync(input,'utf8')),plan=JSON.parse(fs.readFileSync(selection,'utf8'));validateIntake(plan);
  const provider=new JsonRpcProvider(manifest.base.rpcUrl,undefined,{batchMaxCount:1});
  try{const report=await prepareIntake(manifest,plan,provider);fs.writeFileSync(output,JSON.stringify(report,(_,v)=>typeof v==='bigint'?v.toString():v,2)+'\n',{flag:'wx'});
    console.log(JSON.stringify({unsigned:true,broadcast:false,positions:report.positions.length,calls:report.transactions.length,output}));
  }finally{provider.destroy();}
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href)main().catch((error)=>{console.error(error.code?`Read-only preparation failed: ${error.code}`:error.message);process.exitCode=1;});

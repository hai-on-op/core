#!/usr/bin/env node
// Disposable local fork only: rehearse actual finite legacy NFT migration, permanent conversion and issuer intake.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import {spawn} from 'node:child_process';
import {Contract,ContractFactory,JsonRpcProvider,JsonRpcSigner,keccak256,parseEther,toBeHex} from 'ethers';
import {DEPLOYER,TREASURY,AERO,SAERO} from './prepare-deployment.mjs';
import {MIGRATIONS,prepareIntake} from './prepare-intake.mjs';
const BLOCK=53038227,expiredScenario=process.argv.includes('--expired'),server=net.createServer();
await new Promise((r)=>server.listen(0,'127.0.0.1',r));const port=server.address().port;await new Promise((r)=>server.close(r));
const child=spawn('anvil',['--host','127.0.0.1','--port',String(port),'--fork-url',process.env.AERO_FORK_RPC||'https://mainnet.base.org','--fork-block-number',String(BLOCK),'--hardfork','prague','--chain-id','8453','--silent'],{stdio:'ignore'});
const provider=new JsonRpcProvider(`http://127.0.0.1:${port}`,8453,{batchMaxCount:1,pollingInterval:50,staticNetwork:true,cacheTimeout:-1});
async function mined(promise){const tx=await promise;for(let i=0;i<300;i++){const r=await provider.send('eth_getTransactionReceipt',[tx.hash]);if(r){assert.equal(r.status,'0x1');return r;}await new Promise((r)=>setTimeout(r,100));}throw new Error(`Local receipt timeout: nonce=${tx.nonce}, latest=${await provider.send('eth_getTransactionCount',[tx.from,'latest'])}, pending=${await provider.send('eth_getTransactionCount',[tx.from,'pending'])}, gas=${tx.gasLimit}`);}
try{
 let ready=false;for(let i=0;i<150;i++){if(child.exitCode!==null)throw new Error('Local Anvil exited');try{await provider.send('eth_chainId',[]);ready=true;break;}catch{await new Promise((r)=>setTimeout(r,100));}}
 assert(ready);assert.match(await provider.send('web3_clientVersion',[]),/anvil/i);
 const getBlock=provider.getBlock.bind(provider);provider.getBlock=async(tag)=>{if(tag!=='finalized')return getBlock(tag);const b=await provider.send('eth_getBlockByNumber',['latest',false]);return{number:Number(BigInt(b.number)),hash:b.hash,timestamp:Number(BigInt(b.timestamp))};};
 for(const address of [DEPLOYER,TREASURY]){await provider.send('anvil_impersonateAccount',[address]);await provider.send('anvil_setBalance',[address,toBeHex(parseEther('10'))]);}
 const deployer=new JsonRpcSigner(provider,DEPLOYER),safe=new JsonRpcSigner(provider,TREASURY);
 const artifact=JSON.parse(fs.readFileSync('out/HaiAero.sol/HaiAero.json','utf8'));
 const issuer=await new ContractFactory(artifact.abi,artifact.bytecode.object,deployer).deploy(AERO.address,SAERO.address,TREASURY,TREASURY,8453);
 const creation=await mined(issuer.deploymentTransaction());
 const migration=new Contract(MIGRATIONS.aerodrome.address,['function V2_ESCROW() view returns(address)','function depositVeNFT(uint256,address) payable'],safe);
 const oldEscrow=new Contract(await migration.V2_ESCROW(),['function ownerOf(uint256) view returns(address)','function approve(address,uint256)'],safe);
 assert.equal(await oldEscrow.ownerOf(8814),TREASURY);await mined(oldEscrow.approve(MIGRATIONS.aerodrome.address,8814));
 const receipt=await mined(migration.depositVeNFT(8814,TREASURY,{gasLimit:10000000}));
 const escrow=new Contract(SAERO.address,['function tokenId() view returns(uint256)','function staked(uint256) view returns(uint128 amount,uint48 end,bool isPermanent)','function ownerOf(uint256) view returns(address)'],safe);
 const id=await escrow.tokenId(),stake=await escrow.staked(id);assert.equal(stake.isPermanent,false);assert(stake.amount>0n);
 const manifest=JSON.parse(fs.readFileSync('script/aero/deployment.example.json','utf8'));
 manifest.base.wrapper={address:await issuer.getAddress(),runtimeCodeHash:keccak256(await provider.getCode(await issuer.getAddress())),transactionHash:creation.transactionHash,blockNumber:Number(BigInt(creation.blockNumber)),blockHash:creation.blockHash};
 const plan={schemaVersion:1,chainId:8453,positionsReviewed:true,recipient:'treasury',positions:[{origin:'aerodrome',oldTokenId:'8814',tokenId:id.toString(),principal:stake.amount.toString(),transactionHash:receipt.transactionHash,blockNumber:Number(BigInt(receipt.blockNumber)),blockHash:receipt.blockHash}]};
 if(expiredScenario){await provider.send('evm_setNextBlockTimestamp',[Number(stake.end)+1]);await provider.send('evm_mine',[]);}
 const prepared=await prepareIntake(manifest,plan,provider);assert.equal(prepared.transactions.length,expiredScenario?5:4);assert.equal(prepared.expectedMintedPrincipal,stake.amount);
 for(const {to,value,data}of prepared.transactions)await mined(safe.sendTransaction({to,value,data,gasLimit:10000000}));
 assert.equal(await issuer.paused(),true);assert.equal(await issuer.balanceOf(TREASURY),stake.amount);assert.equal(await issuer.principalOf(id),stake.amount);
 const permanent=await escrow.staked(id);assert.equal(permanent.amount,stake.amount);assert.equal(permanent.isPermanent,true);assert.equal(permanent.end,0n);assert.equal(await escrow.ownerOf(id),TREASURY);
 await assert.rejects(prepareIntake(manifest,plan,provider),/already been issued/);
 const report={localForkOnly:true,scenario:expiredScenario?'expired migrated position':'active finite migrated position',chainId:8453,pinnedBlock:BLOCK,pinnedBlockHash:(await getBlock(BLOCK)).hash,checks:['Actual legacy Base finite NFT8814 migrates through canonical migration contract','New NFT ID and exact principal derive from actual canonical settlement receipt','Reviewed issuer deployment initcode, sender, runtime and Safe identities verified','Verified upgradeToPermanentStake succeeds without reset or deallocation','Safe-owned intake mints exact principal without transferring custody','Issuer returns to paused state and duplicate recognition is rejected'],limits:['Confirmed deployer and Safe are impersonated only on the local fork; no production transaction occurred.','Anvil finality is simulated. Calls run sequentially in the rehearsal; the production Safe package requires the whole ordered batch atomically.']};
 if(expiredScenario)report.checks.push('Expired migrated stake renews via increaseStakingPeriod(id,1), becomes permanent and issues unchanged principal');
 if(process.env.AERO_INTAKE_FORK_REPORT)fs.writeFileSync(process.env.AERO_INTAKE_FORK_REPORT,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}finally{provider.destroy();child.kill('SIGTERM');}

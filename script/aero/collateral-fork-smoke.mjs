#!/usr/bin/env node
// Rehearses both preparation phases against real HAI contracts, only on a disposable loopback Anvil fork.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import {spawn} from 'node:child_process';
import {Contract, ContractFactory, JsonRpcProvider, JsonRpcSigner, encodeBytes32String, keccak256, parseEther, toBeHex} from 'ethers';
import {CORE, prepareCollateral} from './prepare-collateral.mjs';
const BLOCK = 158633871, AUTHORITY = '0xd68e7D20008a223dD48A6076AAf5EDd4fe80a899';
const server = net.createServer();
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port; await new Promise((resolve) => server.close(resolve));
const child = spawn('anvil', ['--host','127.0.0.1','--port',String(port),'--fork-url',process.env.AERO_OP_FORK_RPC || 'https://mainnet.optimism.io','--fork-block-number',String(BLOCK),'--hardfork','prague','--chain-id','10','--silent'], {stdio:'ignore'});
const provider = new JsonRpcProvider(`http://127.0.0.1:${port}`, 10, {batchMaxCount:1, pollingInterval:50, staticNetwork:true});
async function mined(promise) {
  const tx = await promise;
  for (let i=0; i<300; ++i) {
    const r = await provider.send('eth_getTransactionReceipt',[tx.hash]);
    if (r) { assert.equal(r.status,'0x1'); return r; }
    await new Promise((r) => setTimeout(r,100));
  }
  throw new Error('Local transaction timeout');
}
async function evidence(address, receipt) {
  return {address, runtimeCodeHash:keccak256(await provider.getCode(address)), transactionHash:receipt.transactionHash, blockNumber:Number(BigInt(receipt.blockNumber)), blockHash:receipt.blockHash};
}
const stringify = (value) => JSON.parse(JSON.stringify(value, (_,v) => typeof v === 'bigint' ? v.toString() : v));
try {
  let connected=false;
  for (let i=0; i<150; ++i) {
    if (child.exitCode !== null) throw new Error('Local Anvil exited');
    try { await provider.send('eth_chainId',[]); connected=true; break; } catch { await new Promise((r) => setTimeout(r,100)); }
  }
  assert(connected); assert.match(await provider.send('web3_clientVersion',[]), /anvil/i);
  // Anvil has no consensus finality for newly mined local blocks. Simulate that checkpoint only for this loopback test.
  const getBlock = provider.getBlock.bind(provider);
  provider.getBlock = async (tag) => {
    if (tag !== 'finalized') return getBlock(tag);
    const local = await provider.send('eth_getBlockByNumber', ['latest', false]);
    return {number:Number(BigInt(local.number)), hash:local.hash, timestamp:Number(BigInt(local.timestamp))};
  };
  const account = await provider.getSigner(0);
  const artifact = JSON.parse(fs.readFileSync('out/AeroMigrationMocks.sol/AeroMigrationTokenMock.json','utf8'));
  const token = await new ContractFactory(artifact.abi,artifact.bytecode.object,account).deploy();
  const tokenReceipt = await mined(token.deploymentTransaction());
  const oldType=encodeBytes32String('HAIAERO');
  const se=new Contract(CORE.safeEngine.address,['function cParams(bytes32) view returns(uint256 debtCeiling,uint256 debtFloor)'],provider);
  const or=new Contract(CORE.oracleRelayer.address,['function cParams(bytes32) view returns(address oracle,uint256 safetyCRatio,uint256 liquidationCRatio)'],provider);
  const le=new Contract(CORE.liquidationEngine.address,['function cParams(bytes32) view returns(address collateralAuctionHouse,uint256 liquidationPenalty,uint256 liquidationQuantity)'],provider);
  const tc=new Contract(CORE.taxCollector.address,['function cParams(bytes32) view returns(uint256 stabilityFee)'],provider);
  const legacy={safe:await se.cParams(oldType),oracle:await or.cParams(oldType),liquidation:await le.cParams(oldType),tax:await tc.cParams(oldType)};
  const oldAuction=new Contract(legacy.liquidation.collateralAuctionHouse,['function params() view returns(uint256 minimumBid,uint256 minDiscount,uint256 maxDiscount,uint256 perSecondDiscountUpdateRate)'],provider);
  const ap=await oldAuction.params();
  // Fixture parameters mirror current old HAIAERO only for this local integration rehearsal. They are NOT production recommendations.
  const manifest={schemaVersion:1,chainId:10,reviewed:true,cType:'AEROFORKTEST',executionAuthority:AUTHORITY,
    token:await evidence(await token.getAddress(),tokenReceipt),oraclePolicy:'reuse-existing-haiaero-pyth',oracle:{address:legacy.oracle.oracle,runtimeCodeHash:keccak256(await provider.getCode(legacy.oracle.oracle))},
    risk:{debtCeiling:'0',debtFloor:legacy.safe.debtFloor.toString(),safetyCRatio:legacy.oracle.safetyCRatio.toString(),liquidationCRatio:legacy.oracle.liquidationCRatio.toString(),
      liquidationPenalty:legacy.liquidation.liquidationPenalty.toString(),liquidationQuantity:legacy.liquidation.liquidationQuantity.toString(),stabilityFee:legacy.tax.toString(),secondaryTaxPolicy:'primary-only',
      auction:{minimumBid:ap.minimumBid.toString(),minDiscount:ap.minDiscount.toString(),maxDiscount:ap.maxDiscount.toString(),perSecondDiscountUpdateRate:ap.perSecondDiscountUpdateRate.toString()}}};
  await provider.send('anvil_impersonateAccount',[AUTHORITY]); await provider.send('anvil_setBalance',[AUTHORITY,toBeHex(parseEther('10'))]);
  const signer=new JsonRpcSigner(provider,AUTHORITY);
  const phase1=await prepareCollateral(manifest,'factories',provider), receipts=[];
  for(const {to,value,data} of phase1.transactions) receipts.push(await mined(signer.sendTransaction({to,value,data,gasLimit:10000000})));
  const key=encodeBytes32String(manifest.cType);
  const jf=new Contract(CORE.joinFactory.address,['function collateralJoins(bytes32) view returns(address)'],provider);
  const af=new Contract(CORE.auctionFactory.address,['function collateralAuctionHouses(bytes32) view returns(address)'],provider);
  const join=await jf.collateralJoins(key),auction=await af.collateralAuctionHouses(key);
  manifest.children={join:{...await evidence(join,receipts[0]),factoryDeployment:{factory:CORE.joinFactory,eventAbi:'event DeployCollateralJoin(bytes32 indexed _cType,address indexed _collateral,address indexed _collateralJoin)',addressArgument:'_collateralJoin'}},
    auction:{...await evidence(auction,receipts[1]),factoryDeployment:{factory:CORE.auctionFactory,eventAbi:'event DeployCollateralAuctionHouse(bytes32 indexed _cType,address indexed _collateralAuctionHouse)',addressArgument:'_collateralAuctionHouse'}}};
  const phase2=await prepareCollateral(manifest,'initialize',provider);
  for(const {to,value,data} of phase2.transactions) await mined(signer.sendTransaction({to,value,data,gasLimit:10000000}));
  assert.equal((await se.cParams(key)).debtCeiling,0n); assert.equal((await or.cParams(key)).oracle,legacy.oracle.oracle);
  assert.deepEqual(stringify(await se.cParams(oldType)),stringify(legacy.safe));
  assert.deepEqual(stringify(await or.cParams(oldType)),stringify(legacy.oracle));
  assert.deepEqual(stringify(await le.cParams(oldType)),stringify(legacy.liquidation)); assert.equal(await tc.cParams(oldType),legacy.tax);
  await assert.rejects(prepareCollateral(manifest,'initialize',provider), /already initialized/);
  const report={localForkOnly:true,chainId:10,pinnedBlock:BLOCK,pinnedBlockHash:(await provider.getBlock(BLOCK)).hash,runtime:'prague',checks:['Pinned real HAI runtimes and live execution authorization','Canonical factory calls create actual join and auction','Finalized local receipts, canonical blocks and exact factory events validate children','Existing HAIAERO Pyth oracle reused unchanged','Ordered initialization succeeds with debtCeiling zero','Legacy collateral core parameters unchanged','Duplicate initialization rejected'],limits:['New token is a local test fixture. Existing collateral risk values are integration fixtures, not new collateral recommendations.','Local finality is simulated because Anvil does not finalize its mined blocks. Production preflight requires actual finalized RPC blocks.', 'Authority is impersonated only on the disposable local fork; this is not a governance proposal, deployment receipt or production approval.']};
  if(process.env.AERO_COLLATERAL_FORK_REPORT) fs.writeFileSync(process.env.AERO_COLLATERAL_FORK_REPORT,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report,null,2));
}finally{provider.destroy();child.kill('SIGTERM');}

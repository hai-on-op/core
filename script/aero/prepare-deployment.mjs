#!/usr/bin/env node
// Read-only creation-payload preparation. No Wallet, Signer, private key or transaction-sending API.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {AbiCoder, Contract, JsonRpcProvider, concat, getAddress, keccak256, toQuantity} from 'ethers';
import {same, verifyDeployment, verifyRuntime} from './verification.mjs';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const UPSTREAM_COMMIT = '8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf';
export const DEPLOYER = '0xbd8EC4cb226EBaE228F8829E2ec23070b09165d3';
export const TREASURY = '0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3';
export const AERO = {address:'0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee',runtimeCodeHash:'0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9'};
export const SAERO = {address:'0xBF7977E1521e9a3032bf7243Ee4712f311f13915',runtimeCodeHash:'0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e'};
export const VOTER = {address:'0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6',runtimeCodeHash:'0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b'};
const need = (condition, message) => { if (!condition) throw new Error(message); };
const errorLabel = (error) => error.code ? `RPC error: ${error.code}` : 'Read-only RPC estimation unavailable';

export function verifyArtifact(artifact, policy, reviewed, readSource) {
  need(artifact && typeof artifact.rawMetadata === 'string', 'Compiled metadata required; build the reviewed source first');
  need(same(keccak256(Buffer.from(artifact.rawMetadata)), reviewed.metadataHash), 'Artifact metadata differs from reviewed compilation');
  const metadata = JSON.parse(artifact.rawMetadata);
  need(metadata.compiler.version === policy.compilerVersion && metadata.settings.evmVersion === policy.evmVersion
    && metadata.settings.optimizer?.enabled === true && metadata.settings.optimizer.runs === policy.optimizerRuns,
  'Unexpected compiler or optimization settings');
  need(Object.keys(metadata.settings.compilationTarget).length === 1
    && metadata.settings.compilationTarget[reviewed.source] === reviewed.contractName, 'Unexpected compilation target');
  const constructor = artifact.abi.filter((item) => item.type === 'constructor');
  need(constructor.length === 1 && constructor[0].stateMutability === 'nonpayable'
    && JSON.stringify(constructor[0].inputs.map((input) => input.type)) === JSON.stringify(reviewed.constructorTypes), 'Unexpected constructor ABI');
  const bytecode = artifact.bytecode?.object;
  need(typeof bytecode === 'string' && /^0x[0-9a-fA-F]+$/.test(bytecode) && bytecode.length % 2 === 0
    && same(keccak256(bytecode), reviewed.creationBytecodeHash), 'Creation bytecode differs from reviewed and tested artifact');
  need(Object.keys(artifact.bytecode.linkReferences ?? {}).length === 0 && Object.keys(metadata.settings.libraries ?? {}).length === 0,
    'Linked libraries require a separate reviewed deployment procedure');
  const sources = {};
  for (const [name, identity] of Object.entries(metadata.sources)) {
    need(!path.isAbsolute(name) && !name.split(/[\\/]/).includes('..'), 'Invalid artifact source path');
    const content = readSource(name);
    need(same(keccak256(content), identity.keccak256), `Artifact source hash mismatch: ${name}`);
    sources[name] = identity.keccak256;
  }
  need(Object.hasOwn(sources, reviewed.source), 'Expected contract source is absent');
  return {bytecode, constructor:constructor[0], sourceHashes:sources, metadataHash:reviewed.metadataHash};
}

export function validateDeploymentInputs(manifest, kind, chainId) {
  need(manifest.schemaVersion === 1 && manifest.upstreamCommit === UPSTREAM_COMMIT, 'Expected migration manifest and upstream source pin required');
  need(same(manifest.deployer,DEPLOYER) && same(manifest.owner,TREASURY) && same(manifest.treasury,TREASURY), 'Confirmed deployer and treasury Safe roles must match exactly');
  need(chainId === 8453 || chainId === 10, 'Unsupported deployment chain');
  const config = chainId === 8453 ? manifest.base : manifest.optimism;
  need(config?.chainId === chainId, 'Manifest chain mismatch');
  if (kind === 'issuer') {
    need(chainId === 8453, 'Issuer can only be prepared for Base');
    return {config, args:[AERO.address,SAERO.address,TREASURY,TREASURY,8453]};
  }
  need(kind === 'migrator', 'Kind must be issuer or migrator');
  const output = chainId === 8453 ? config.wrapper : config.output;
  need(output?.address && output.runtimeCodeHash && (output.transactionHash || output.deploymentTransactionHash),
    'Migrator requires a real output deployment receipt and runtime; a predicted address is insufficient');
  need(chainId !== 10 || manifest.bridgeRouteReviewed === true, 'OP output route review must be explicitly recorded');
  need(Array.isArray(config.sourceCaps) && config.sourceCaps.length === (chainId === 8453 ? 1 : 3), 'Explicit caps in canonical source order required');
  const caps = config.sourceCaps.map((value) => {
    need(typeof value === 'string' && /^(0|[1-9][0-9]*)$/.test(value) && BigInt(value) < 2n ** 256n, 'Invalid raw-unit source cap');
    return BigInt(value);
  });
  return {config, output, args:[getAddress(output.address),TREASURY,chainId,caps,TREASURY]};
}

export function encodeCreation(verified, types, args, chainId) {
  const encodedArguments = AbiCoder.defaultAbiCoder().encode(types,args);
  const data = concat([verified.bytecode,encodedArguments]);
  return {transaction:{from:DEPLOYER,chainId,value:'0',data}, constructorArguments:{types,values:args,encoded:encodedArguments},initcodeHash:keccak256(data)};
}

export function fundingStatus(balance, gas, gasPrice) {
  if (balance === 0n) return 'unfunded-zero-balance';
  if (gas === null || gasPrice === null) return 'execution-cost-unknown';
  return balance >= gas * gasPrice ? 'covers-estimated-execution-cost-only' : 'below-estimated-execution-cost';
}

export function loadReviewedArtifact(name) {
  const policy = JSON.parse(fs.readFileSync(path.join(ROOT,'script/aero/artifacts-reviewed.json'),'utf8'));
  const reviewed = {...policy.contracts[name],contractName:name};
  const artifact = JSON.parse(fs.readFileSync(path.join(ROOT,reviewed.artifact),'utf8'));
  const verified = verifyArtifact(artifact,policy,reviewed,(source) => fs.readFileSync(path.join(ROOT,source)));
  return {policy,reviewed,verified};
}

export async function verifyIssuerDeployment(manifest, provider, snapshot) {
  const {args} = validateDeploymentInputs(manifest,'issuer',8453);
  const entry = manifest.base.wrapper;
  need(entry,'Actual issuer deployment evidence required');
  await verifyDeployment(provider,entry,snapshot);
  const {reviewed,verified} = loadReviewedArtifact('HaiAero');
  const expected = encodeCreation(verified,reviewed.constructorTypes,args,8453);
  const receipt = await provider.getTransactionReceipt(entry.deploymentTransactionHash ?? entry.transactionHash);
  const transaction = await provider.getTransaction(entry.deploymentTransactionHash ?? entry.transactionHash);
  need(same(receipt.contractAddress,entry.address) && same(transaction?.from,DEPLOYER)
    && same(transaction.data,expected.transaction.data), 'Issuer receipt must prove direct deployment of the exact reviewed initcode by the confirmed deployer');
}

export async function verifyBaseMigratorDeployment(manifest, provider, snapshot) {
  const {args} = validateDeploymentInputs(manifest,'migrator',8453);
  const entry = manifest.base.migrator;
  need(entry,'Actual Base migrator deployment evidence required');
  await verifyDeployment(provider,entry,snapshot);
  const {reviewed,verified} = loadReviewedArtifact('HaiAeroMigrator');
  const expected = encodeCreation(verified,reviewed.constructorTypes,args,8453);
  const receipt = await provider.getTransactionReceipt(entry.deploymentTransactionHash ?? entry.transactionHash);
  const transaction = await provider.getTransaction(entry.deploymentTransactionHash ?? entry.transactionHash);
  need(same(receipt.contractAddress,entry.address) && same(transaction?.from,DEPLOYER)
    && same(transaction.data,expected.transaction.data), 'Base migrator must prove direct deployment of reviewed initcode by the confirmed deployer');
}

export async function prepareDeployment(manifest, kind, chainId, provider, {estimateGas = true} = {}) {
  const {config,output,args} = validateDeploymentInputs(manifest,kind,chainId);
  const name = kind === 'issuer' ? 'HaiAero' : 'HaiAeroMigrator';
  const {policy,reviewed,verified} = loadReviewedArtifact(name);
  need(Number(BigInt(await provider.send('eth_chainId',[]))) === chainId, 'RPC chain mismatch');
  const block = await provider.getBlock('finalized');
  need(block?.hash && block.number > 0, 'Finalized source snapshot required');
  const snapshot = {blockNumber:block.number,blockHash:block.hash,finalizedBlockNumber:block.number};
  const options = {blockTag:block.number};
  const treasuryCode = await provider.getCode(TREASURY,block.number);
  need(treasuryCode !== '0x', 'Treasury Safe must exist on the selected chain');
  const safe = new Contract(TREASURY,['function getOwners() view returns(address[])','function getThreshold() view returns(uint256)'],provider);
  const owners = await safe.getOwners(options), threshold = await safe.getThreshold(options);
  need(threshold > 0n && threshold <= BigInt(owners.length), 'Invalid observed Safe threshold');
  if (kind === 'issuer') {
    for (const identity of [AERO,SAERO,VOTER]) await verifyRuntime(provider,identity,block.number);
    const escrow = new Contract(SAERO.address,['function TOKEN() view returns(address)','function VOTER() view returns(address)'],provider);
    need(same(await escrow.TOKEN(options),AERO.address) && same(await escrow.VOTER(options),VOTER.address), 'Canonical sAERO token/voter bindings changed');
  } else {
    if (chainId === 8453) await verifyIssuerDeployment(manifest,provider,snapshot);
    else await verifyDeployment(provider,output,snapshot);
    const token = new Contract(output.address,['function decimals() view returns(uint8)',
      'function BASE_TOKEN() view returns(address)','function BASE_TOKEN_NFT() view returns(address)',
      'function treasury() view returns(address)','function owner() view returns(address)','function deploymentChainId() view returns(uint256)'],provider);
    need(await token.decimals(options) === 18n,'Output token must have 18 decimals');
    if (chainId === 8453) need(same(await token.BASE_TOKEN(options),AERO.address) && same(await token.BASE_TOKEN_NFT(options),SAERO.address)
      && same(await token.owner(options),TREASURY) && same(await token.treasury(options),TREASURY)
      && await token.deploymentChainId(options) === 8453n,'Actual Base output issuer identities differ');
  }
  const creation = encodeCreation(verified,reviewed.constructorTypes,args,chainId);
  const balance = await provider.getBalance(DEPLOYER,block.number);
  const nonce = await provider.getTransactionCount(DEPLOYER,block.number);
  let gas = null, gasPrice = null, estimateError = null;
  if (estimateGas) {
    try {
      gas = BigInt(await provider.send('eth_estimateGas',[{from:DEPLOYER,value:'0x0',data:creation.transaction.data},toQuantity(block.number)]));
      gasPrice = BigInt(await provider.send('eth_gasPrice',[]));
    } catch (error) { estimateError = errorLabel(error); }
  }
  need(same((await provider.getBlock(block.number)).hash,block.hash),'Finalized deployment snapshot changed during preparation');
  return {schemaVersion:1,unsigned:true,broadcast:false,kind,chainId,contractName:name,contractSourceCommit:policy.contractSourceCommit,
    upstreamCommit:UPSTREAM_COMMIT,snapshot,artifact:{path:reviewed.artifact,compilerVersion:policy.compilerVersion,evmVersion:policy.evmVersion,
      optimizerRuns:policy.optimizerRuns,creationBytecodeHash:reviewed.creationBytecodeHash,metadataHash:reviewed.metadataHash,sourceHashes:verified.sourceHashes},
    ...creation, roles:{deployer:DEPLOYER,owner:TREASURY,treasury:TREASURY},
    observedSafe:{address:TREASURY,runtimeCodeHash:keccak256(treasuryCode),owners,threshold},
    deployerStatus:{balanceWei:balance,observedNonce:nonce,status:fundingStatus(balance,gas,gasPrice)},
    gasEstimate:{requested:estimateGas,gas,gasPriceWei:gasPrice,estimatedExecutionCostWei:gas !== null && gasPrice !== null ? gas * gasPrice : null,error:estimateError},
    outputDeployment:output ?? null,
    limitations:['Unsigned creation data only. No transaction was signed, sent, deployed or activated.',
      'The user wallet must supply current nonce, gas limit and fees. No predicted address is accepted as deployment evidence.',
      'Balance and gas observations are temporary; execution-cost estimates do not prove coverage of all L1 data/operator fees.',
      'Contracts deploy paused. Verify actual canonical receipt, runtime and roles before funding or activation.',
      'Gas estimation failure or an unfunded deployer does not prevent emitting this review package.']};
}

async function main() {
  const args = process.argv.slice(2), option = (name) => {const i=args.indexOf(name);return i<0?undefined:args[i+1];};
  const input=option('--manifest'), output=option('--output'), kind=option('--kind'), chainId=Number(option('--chain-id'));
  need(input && output,'Usage: --manifest PATH --kind issuer|migrator --chain-id 8453|10 --output PATH [--skip-gas-estimate]');
  need(!fs.existsSync(output),'Output already exists; choose a new evidence path');
  const manifest=JSON.parse(fs.readFileSync(input,'utf8'));
  const {config}=validateDeploymentInputs(manifest,kind,chainId);
  const provider=new JsonRpcProvider(config.rpcUrl,undefined,{batchMaxCount:1});
  try {
    const report=await prepareDeployment(manifest,kind,chainId,provider,{estimateGas:!args.includes('--skip-gas-estimate')});
    fs.writeFileSync(output,JSON.stringify(report,(_,v)=>typeof v==='bigint'?v.toString():v,2)+'\n',{flag:'wx'});
    console.log(JSON.stringify({unsigned:true,broadcast:false,kind,chainId,initcodeHash:report.initcodeHash,fundingStatus:report.deployerStatus.status,output}));
  } finally {provider.destroy();}
}
if(process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error)=>{console.error(error.code?`Read-only preparation failed: ${error.code}`:error.message);process.exitCode=1;});
}

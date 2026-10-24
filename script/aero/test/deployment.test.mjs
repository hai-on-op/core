import test from 'node:test';
import assert from 'node:assert/strict';
import {AbiCoder, keccak256} from 'ethers';
import {DEPLOYER,TREASURY,verifyArtifact,validateDeploymentInputs,encodeCreation,fundingStatus} from '../prepare-deployment.mjs';
const source='src/contracts/tokens/HaiAero.sol',content=Buffer.from('reviewed source fixture'),bytecode='0x6001600055';
function artifactFixture() {
  const policy={compilerVersion:'0.8.20+commit.a1b79de6',evmVersion:'shanghai',optimizerRuns:10000};
  const metadata={compiler:{version:policy.compilerVersion},settings:{evmVersion:policy.evmVersion,optimizer:{enabled:true,runs:10000},compilationTarget:{[source]:'HaiAero'},libraries:{}},sources:{[source]:{keccak256:keccak256(content)}}};
  const rawMetadata=JSON.stringify(metadata),types=['address','address','address','address','uint256'];
  return {policy,reviewed:{contractName:'HaiAero',source,metadataHash:keccak256(Buffer.from(rawMetadata)),creationBytecodeHash:keccak256(bytecode),constructorTypes:types},
    artifact:{rawMetadata,abi:[{type:'constructor',stateMutability:'nonpayable',inputs:types.map((type)=>({type}))}],bytecode:{object:bytecode,linkReferences:{}}}};
}
function manifest() {return {schemaVersion:1,upstreamCommit:'8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf',deployer:DEPLOYER,owner:TREASURY,treasury:TREASURY,base:{chainId:8453},optimism:{chainId:10}};}
test('artifact identity binds constructor, compiled code, metadata and every source',()=>{
  const {artifact,policy,reviewed}=artifactFixture();
  assert.equal(verifyArtifact(artifact,policy,reviewed,()=>content).bytecode,bytecode);
  assert.throws(()=>verifyArtifact(artifact,policy,reviewed,()=>Buffer.from('changed source')),/source hash/);
  assert.throws(()=>verifyArtifact({...artifact,bytecode:{object:'0x00'}},policy,reviewed,()=>content),/Creation bytecode/);
  const altered=structuredClone(artifact);altered.abi[0].inputs.pop();
  assert.throws(()=>verifyArtifact(altered,policy,reviewed,()=>content),/constructor ABI/);
});
test('artifact verification refuses altered compiler metadata or linked libraries',()=>{
  const {artifact,policy,reviewed}=artifactFixture();
  assert.throws(()=>verifyArtifact({...artifact,rawMetadata:artifact.rawMetadata+' '},policy,reviewed,()=>content),/metadata differs/);
  assert.throws(()=>verifyArtifact({...artifact,bytecode:{object:bytecode,linkReferences:{Library:[{}]}}},policy,reviewed,()=>content),/Linked libraries/);
});
test('issuer constructor and unsigned creation data use confirmed fixed identities',()=>{
  const input=validateDeploymentInputs(manifest(),'issuer',8453);
  assert.equal(input.args[2],TREASURY);assert.equal(input.args[3],TREASURY);assert.equal(input.args[4],8453);
  const types=['address','address','address','address','uint256'];
  const report=encodeCreation({bytecode},types,input.args,8453);
  assert.equal(report.transaction.from,DEPLOYER);assert.equal(report.transaction.value,'0');assert(!Object.hasOwn(report.transaction,'to'));
  assert(!Object.hasOwn(report.transaction,'nonce'));assert(!Object.hasOwn(report,'predictedAddress'));
  assert.equal(report.transaction.data,bytecode+AbiCoder.defaultAbiCoder().encode(types,input.args).slice(2));
  assert.equal(report.initcodeHash,keccak256(report.transaction.data));
});
test('preparation rejects chain or role substitution',()=>{
  assert.throws(()=>validateDeploymentInputs(manifest(),'issuer',10),/Base/);
  const altered=manifest();altered.owner=DEPLOYER;
  assert.throws(()=>validateDeploymentInputs(altered,'issuer',8453),/roles must match/);
});
test('migrator refuses absent output receipt, missing caps and unreviewed OP route',()=>{
  const m=manifest();assert.throws(()=>validateDeploymentInputs(m,'migrator',8453),/real output deployment/);
  m.base.wrapper={address:TREASURY,runtimeCodeHash:'0x'+'00'.repeat(32),transactionHash:'0x'+'11'.repeat(32)};
  assert.throws(()=>validateDeploymentInputs(m,'migrator',8453),/Explicit caps/);
  m.base.sourceCaps=['123'];assert.equal(validateDeploymentInputs(m,'migrator',8453).args[3][0],123n);
  m.optimism.output=m.base.wrapper;m.optimism.sourceCaps=['1','2','3'];
  assert.throws(()=>validateDeploymentInputs(m,'migrator',10),/route review/);
});
test('funding observations never prevent generation or imply full L2 fee coverage',()=>{
  assert.equal(fundingStatus(0n,100n,2n),'unfunded-zero-balance');
  assert.equal(fundingStatus(1000n,null,null),'execution-cost-unknown');
  assert.equal(fundingStatus(199n,100n,2n),'below-estimated-execution-cost');
  assert.equal(fundingStatus(200n,100n,2n),'covers-estimated-execution-cost-only');
});

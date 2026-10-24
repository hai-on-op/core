import test from 'node:test';
import assert from 'node:assert/strict';
import {Interface, keccak256, ZeroAddress, zeroPadValue} from 'ethers';
import {verifyDeployment, verifyRuntime, IMPLEMENTATION_SLOT, ADMIN_SLOT} from '../verification.mjs';
const target = '0x1111111111111111111111111111111111111111';
const factory = '0x2222222222222222222222222222222222222222';
const impl = '0x3333333333333333333333333333333333333333';
const runtime = '0x6001600055', hash = keccak256(runtime), blockHash = '0x' + 'ab'.repeat(32);
const entry = {address: target, runtimeCodeHash: hash, transactionHash: '0x' + 'cd'.repeat(32), blockNumber: 5, blockHash};
const snapshot = {blockNumber: 20, finalizedBlockNumber: 18};
function fixture() {
  const receipt = {status: 1, blockNumber: 5, blockHash, contractAddress: target, logs: []};
  const provider = {getCode: async (address, block) => address.toLowerCase() === target && block === 4 ? '0x' : runtime, getStorage: async () => zeroPadValue(ZeroAddress, 32), getBlock: async () => ({hash: blockHash}), getTransactionReceipt: async () => receipt};
  return {provider, receipt};
}
test('direct finalized deployment requires current runtime and canonical creation receipt', async () => {
  const {provider} = fixture();
  assert.equal(await verifyDeployment(provider, entry, snapshot), target);
  await assert.rejects(verifyDeployment(provider, {...entry, runtimeCodeHash: '0x' + '00'.repeat(32)}, snapshot), /Runtime identity/);
  await assert.rejects(verifyDeployment(provider, {...entry, blockHash: '0x' + '00'.repeat(32)}, snapshot), /receipt/);
  await assert.rejects(verifyDeployment(provider, entry, {...snapshot, finalizedBlockNumber: 4}), /receipt/);
  provider.getBlock = async () => ({hash: '0x' + '00'.repeat(32)});
  await assert.rejects(verifyDeployment(provider, entry, snapshot), /canonical/);
});
test('failed or missing creation receipt never counts as deployment', async () => {
  const {provider, receipt} = fixture(); receipt.status = 0;
  await assert.rejects(verifyDeployment(provider, entry, snapshot), /receipt/);
  provider.getTransactionReceipt = async () => null;
  await assert.rejects(verifyDeployment(provider, entry, snapshot), /receipt/);
});
test('factory deployment is tied to verified factory emitter and actual child argument', async () => {
  const {provider, receipt} = fixture(); receipt.contractAddress = null;
  const eventAbi = 'event Created(address indexed child)';
  const iface = new Interface([eventAbi]);
  const log = iface.encodeEventLog(iface.getEvent('Created'), [target]);
  receipt.logs = [{address: factory, ...log}];
  const config = {...entry, factoryDeployment: {factory: {address: factory, runtimeCodeHash: hash}, eventAbi, addressArgument: 'child'}};
  assert.equal(await verifyDeployment(provider, config, snapshot), target);
  const originalGetCode=provider.getCode; provider.getCode=async () => runtime;
  await assert.rejects(verifyDeployment(provider, config, snapshot), /already existed/); provider.getCode=originalGetCode;
  receipt.logs[0].address = target;
  await assert.rejects(verifyDeployment(provider, config, snapshot), /does not prove/);
  await assert.rejects(verifyDeployment(provider, entry, snapshot), /Factory creation/);
});
test('proxy implementation is explicit and runtime verified; beacons fail closed', async () => {
  const {provider} = fixture();
  provider.getStorage = async (_, slot) => zeroPadValue(slot === IMPLEMENTATION_SLOT ? impl : ZeroAddress, 32);
  await assert.rejects(verifyRuntime(provider, entry, 20), /Implementation address/);
  assert.equal(await verifyRuntime(provider, {...entry, implementation: {address: impl, runtimeCodeHash: hash}}, 20), target);
  provider.getStorage = async () => zeroPadValue(impl, 32);
  await assert.rejects(verifyRuntime(provider, entry, 20), /Beacon/);
});

test('nonzero proxy admin always requires a matching reviewed identity', async () => {
  const {provider}=fixture(); provider.getStorage=async (_,slot) => zeroPadValue(slot === ADMIN_SLOT ? factory : ZeroAddress,32);
  await assert.rejects(verifyRuntime(provider,entry,20),/administrator identity/);
  assert.equal(await verifyRuntime(provider,{...entry,proxyAdmin:factory},20),target);
  provider.getStorage=async () => zeroPadValue(ZeroAddress,32);
  await assert.rejects(verifyRuntime(provider,{...entry,proxyAdmin:factory},20),/Unexpected proxy/);
});

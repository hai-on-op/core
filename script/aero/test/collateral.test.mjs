import test from 'node:test';
import assert from 'node:assert/strict';
import {AbiCoder, Interface, encodeBytes32String, ZeroAddress} from 'ethers';
import {validateManifest, encodePhase, CORE, EXISTING_ORACLE, CHILD_EVENTS, verifyChildCreationEvent, validateOracleFreshness, validateOracleCheckpoints} from '../prepare-collateral.mjs';
const RAY = 10n ** 27n, WAD = 10n ** 18n;
const manifest = () => ({schemaVersion: 1, chainId: 10, reviewed: true, cType: 'HAIAERONEW', executionAuthority: '0x1111111111111111111111111111111111111111',
  token: {address: '0x2222222222222222222222222222222222222222'}, oracle: {...EXISTING_ORACLE},
  oraclePolicy: 'reuse-existing-haiaero-pyth', risk: {debtCeiling: '0', debtFloor: (10n ** 45n).toString(), safetyCRatio: (2n * RAY).toString(),
    liquidationCRatio: (15n * RAY / 10n).toString(), liquidationPenalty: WAD.toString(), liquidationQuantity: (10n ** 48n).toString(), stabilityFee: RAY.toString(),
    secondaryTaxPolicy: 'primary-only', auction: {minimumBid: WAD.toString(), minDiscount: WAD.toString(), maxDiscount: (WAD / 2n).toString(), perSecondDiscountUpdateRate: (RAY - 1n).toString()}}});
const iface = new Interface(['function initializeCollateralType(bytes32,bytes)', 'function deployCollateralJoin(bytes32,address)', 'function updateCollateralPrice(bytes32)']);
test('approved existing oracle reuse does not require a new-feed policy approval', () => {
  const result = validateManifest(manifest());
  assert.equal(result.reuseOracle, true); assert.equal(result.oracleMin, 1n);
});
test('manifest rejects unreviewed input, legacy identity, nonzero debt and missing risk values', () => {
  for (const update of [(m) => m.reviewed = false, (m) => m.cType = 'HAIAERO', (m) => m.risk.debtCeiling = '1',
    (m) => m.risk.secondaryTaxPolicy = 'inherited', (m) => m.risk.debtFloor = null, (m) => m.executionAuthority = ZeroAddress,
    (m) => m.token.address = '0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152', (m) => m.risk.auction.maxDiscount = (WAD + 1n).toString()]) {
    const m = manifest(); update(m); assert.throws(() => validateManifest(m));
  }
});
test('factory phase encodes only distinct new collateral joins and auctions', () => {
  const m = manifest(), tx = encodePhase(m, 'factories');
  assert.equal(tx.length, 2); assert.equal(tx[0].to, CORE.joinFactory.address); assert.equal(tx[1].to, CORE.auctionFactory.address);
  const first = iface.parseTransaction(tx[0]); assert.equal(first.name, 'deployCollateralJoin'); assert.equal(first.args[0], encodeBytes32String(m.cType)); assert.equal(first.args[1], m.token.address);
  for (const t of tx) assert.equal(t.value, '0');
});
test('initialization requires actual child addresses and always leaves borrowing disabled', () => {
  const m = manifest(); assert.throws(() => encodePhase(m, 'initialize'), /Actual finalized/);
  const auction = '0x3333333333333333333333333333333333333333';
  const tx = encodePhase(m, 'initialize', {join: m.token.address, auction}); assert.equal(tx.length, 5);
  const safe = iface.parseTransaction(tx[0]); assert.equal(safe.args[0], encodeBytes32String(m.cType));
  const params = AbiCoder.defaultAbiCoder().decode(['uint256', 'uint256'], safe.args[1]); assert.equal(params[0], 0n);
  const oracle = iface.parseTransaction(tx[1]); assert.equal(AbiCoder.defaultAbiCoder().decode(['address','uint256','uint256'], oracle.args[1])[0], m.oracle.address);
  assert.equal(iface.parseTransaction(tx[4]).name, 'updateCollateralPrice');
});

test('reuse policy rejects redefined existing oracle and unrelated factory logs', () => {
  const m=manifest(); m.oracle.address=m.token.address; assert.throws(() => validateManifest(m),/exact selected/);
  const child='0x3333333333333333333333333333333333333333', cType=encodeBytes32String('HAIAERONEW');
  const entry={address:child,factoryDeployment:CHILD_EVENTS.join};
  const event=new Interface([CHILD_EVENTS.join.eventAbi]);
  const log={address:CORE.joinFactory.address,...event.encodeEventLog(event.getEvent('DeployCollateralJoin'),[cType,m.token.address,child])};
  verifyChildCreationEvent('join',entry,{logs:[log]},cType,m.token.address);
  assert.throws(() => verifyChildCreationEvent('join',entry,{logs:[log]},encodeBytes32String('OTHER'),m.token.address),/does not bind/);
  assert.throws(() => verifyChildCreationEvent('join',{...entry,factoryDeployment:{eventAbi:'event AddAuthorization(address _account)',addressArgument:'_account'}},{logs:[log]},cType,m.token.address),/Canonical child/);
});

test('cached delayed validity cannot hide an overdue keeper or stale underlying source', () => {
  validateOracleFreshness(4600,1000n,3600n,1n,true);
  assert.throws(() => validateOracleFreshness(4601,1000n,3600n,1n,true),/overdue/);
  assert.throws(() => validateOracleFreshness(999,1000n,3600n,1n,true),/overdue/);
  assert.throws(() => validateOracleFreshness(4500,1000n,3600n,1n,false),/invalid or stale/);
});

test('one catch-up update after an outage cannot make old delayed current price fresh', () => {
  validateOracleCheckpoints([{timestamp:1000n,value:2n},{timestamp:4602n,value:3n}],4602n,3600n,3n);
  assert.throws(() => validateOracleCheckpoints([{timestamp:1000n,value:2n},{timestamp:20000n,value:3n}],20000n,3600n,3n),/keeper continuity/);
  assert.throws(() => validateOracleCheckpoints([{timestamp:20000n,value:3n}],20000n,3600n,3n),/Two recent/);
  assert.throws(() => validateOracleCheckpoints([{timestamp:1000n,value:2n},{timestamp:4602n,value:3n}],4602n,3600n,9n),/current cache/);
});

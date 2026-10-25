#!/usr/bin/env node
// Read-only governance preparation. No signer, wallet, sendTransaction or broadcast capability.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {AbiCoder, Contract, Interface, JsonRpcProvider, ZeroAddress, encodeBytes32String, getAddress} from 'ethers';
import {same, verifyDeployment, verifyRuntime} from './verification.mjs';

// Canonical HAI OP runtime identities independently read at finalized block 158633580.
export const CORE = {
  safeEngine: {address: '0x9Ff826860689483181C5FAc9628fd2F70275A700', runtimeCodeHash: '0x4b77fda2582e26c98ef5faf4a5003cb1cc3ff3eb81a5245622a2b5a8082b171c'},
  oracleRelayer: {address: '0x6270403b908505F02Da05BE5c1956aBB59FDb3A6', runtimeCodeHash: '0x67d2eb16dfe1a583719cb499232703056a7635869108ef1acabf271e7450ec2a'},
  liquidationEngine: {address: '0x8Be588895BE9B75F9a9dAee185e0c2ad89891b56', runtimeCodeHash: '0x37b5cef3457f37eef53a830fe8f6c2c0eef333ad6a31030b7be79821436ef8e5'},
  taxCollector: {address: '0x62B82ccE08f8F2D808348409E9418c65EB1973C3', runtimeCodeHash: '0xddd1c4ec10d02c7c04a372b1b854fc824391d5f1d1afc43125cff8fb87dc9fcb'},
  joinFactory: {address: '0xfE7987b1Ee45a8d592B15e8E924d50BFC8536143', runtimeCodeHash: '0x29f09f42405d602fdcc79590116f5313dbf13cc8bbb997206d5476277d0abdb1'},
  auctionFactory: {address: '0x81c5C2DA8C1a74c6077B03aD69ca04b74b94B427', runtimeCodeHash: '0x253ff1d6a8183fd1a33367621021763a57bfe2f7fa206539540f06d588dab645'}
};
export const EXISTING_ORACLE = {address:'0x7DA9D12c5b6Fd2548B0E535Ec12F2406D69aBb75',runtimeCodeHash:'0x37adb8e31ee85fd46689284e4a606cad06e4ae3f1d69ea564e60a628a386bc60'};
const EXISTING_SOURCE = {address:'0xaBB1D7583a6c0620be73859DF4DFbcab78696E2e',runtimeCodeHash:'0x6d7059a491a0feccb5a484e6dc3c79ea1c7d8c09021215145dd187d7f9c3fcfc'};
const EXISTING_AGGREGATOR = {address:'0xDAa95C72330a7eF1390874677323B2a13E0d94D7',runtimeCodeHash:'0x835ca6c22834866cfbd1f8714e9d2a36a9d75aae9b0ace1121eea6a7e628a4af'};
export const CHILD_EVENTS = {
  join: {eventAbi:'event DeployCollateralJoin(bytes32 indexed _cType,address indexed _collateral,address indexed _collateralJoin)',addressArgument:'_collateralJoin'},
  auction: {eventAbi:'event DeployCollateralAuctionHouse(bytes32 indexed _cType,address indexed _collateralAuctionHouse)',addressArgument:'_collateralAuctionHouse'}
};
export function verifyChildCreationEvent(kind, entry, receipt, cType, token) {
  const expected=CHILD_EVENTS[kind], evidence=entry.factoryDeployment;
  need(evidence?.eventAbi === expected.eventAbi && evidence.addressArgument === expected.addressArgument, 'Canonical child creation event and field names required');
  const iface=new Interface([expected.eventAbi]), factory=CORE[kind === 'join' ? 'joinFactory' : 'auctionFactory'];
  need(receipt.logs.some((log) => {
    if (!same(log.address,factory.address)) return false;
    try { const event=iface.parseLog(log); return event && event.args._cType === cType && same(event.args[expected.addressArgument],entry.address)
      && (kind !== 'join' || same(event.args._collateral,token)); } catch { return false; }
  }), 'Canonical creation event does not bind expected collateral type, token and child');
}
const AERO = '0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee';
const LEGACY_TYPES = ['HAIVELO', 'HAIVELOV2', 'HAIAERO'];
const LEGACY_TOKENS = ['0x70f3713512089736661F928B291d1443C8b1BB6A', '0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6', '0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152'];
const WAD = 10n ** 18n, RAY = 10n ** 27n, MAX_UINT = 2n ** 256n - 1n, MAX_RAD = MAX_UINT / RAY;
const coder = AbiCoder.defaultAbiCoder();
const methods = new Interface(['function initializeCollateralType(bytes32,bytes)', 'function deployCollateralJoin(bytes32,address)', 'function updateCollateralPrice(bytes32)']);
const common = ['function authorizedAccounts(address) view returns(bool)', 'function contractEnabled() view returns(bool)',
  'function collateralList() view returns(bytes32[])', 'function safeEngine() view returns(address)'];
const ABIS = {
  safeEngine: [...common, 'function cParams(bytes32) view returns(uint256 debtCeiling,uint256 debtFloor)'],
  oracleRelayer: [...common, 'function cParams(bytes32) view returns(address oracle,uint256 safetyCRatio,uint256 liquidationCRatio)'],
  liquidationEngine: [...common, 'function cParams(bytes32) view returns(address collateralAuctionHouse,uint256 liquidationPenalty,uint256 liquidationQuantity)'],
  taxCollector: [...common, 'function cParams(bytes32) view returns(uint256 stabilityFee)', 'function params() view returns(address primaryTaxReceiver,uint256 globalStabilityFee,uint256 maxStabilityFeeRange,uint256 maxSecondaryReceivers)'],
  joinFactory: [...common, 'function collateralTypesList() view returns(bytes32[])', 'function collateralJoins(bytes32) view returns(address)'],
  auctionFactory: [...common, 'function collateralAuctionHouses(bytes32) view returns(address)', 'function liquidationEngine() view returns(address)', 'function oracleRelayer() view returns(address)']
};
// Bounds checkpoint scheduling drift; does not change the deployed oracle's price or update delay.
export const ORACLE_UPDATE_GRACE_SECONDS = 300n;
export function validateOracleCheckpoints(checkpoints, updated, delay, currentPrice) {
  need(checkpoints.length >= 2, 'Two recent delayed-oracle checkpoints required; one catch-up update is insufficient');
  const [previous,latest]=checkpoints.slice(-2);
  need(latest.timestamp === updated && latest.value === currentPrice, 'Latest delayed-oracle event does not prove current cache');
  need(previous.timestamp < latest.timestamp && latest.timestamp - previous.timestamp <= delay + ORACLE_UPDATE_GRACE_SECONDS,
    'Delayed current cache predates keeper continuity; wait for a second update cycle');
}
async function oracleCheckpoints(provider, block, updated, delay, currentPrice) {
  // OP block time is two seconds; a bounded two-day window comfortably contains two healthy hourly checkpoints.
  const iface=new Interface(['event UpdateResult(uint256 _newMedian,uint256 _lastUpdateTime)']);
  const logs=[];
  const start=Math.max(0,block.number-43200);
  for(let from=start;from<=block.number;from+=5000) logs.push(...await provider.getLogs({address:EXISTING_ORACLE.address,
    topics:[iface.getEvent('UpdateResult').topicHash],fromBlock:from,toBlock:Math.min(from+4999,block.number)}));
  logs.sort((a,b) => a.blockNumber-b.blockNumber || a.index-b.index);
  const checkpoints=logs.map((log) => {const event=iface.parseLog(log);return {timestamp:event.args._lastUpdateTime,value:event.args._newMedian};});
  validateOracleCheckpoints(checkpoints,updated,delay,currentPrice);
}
export function validateOracleFreshness(timestamp, updated, delay, sourcePrice, sourceValid) {
  need(delay > 0n && updated <= BigInt(timestamp) && BigInt(timestamp) - updated <= delay, 'Existing delayed oracle update is overdue; update it before preparation');
  need(sourceValid && sourcePrice > 0n, 'Existing Pyth source is invalid or stale');
}
function need(ok, message) { if (!ok) throw new Error(message); }
function uint(value, field, {positive = false, max = MAX_UINT} = {}) {
  need(typeof value === 'string' && /^(0|[1-9][0-9]*)$/.test(value), `${field}: explicit raw-unit integer string required`);
  const result = BigInt(value);
  need(result <= max && (!positive || result > 0n), `${field}: out of range`);
  return result;
}

export function validateManifest(manifest) {
  need(manifest.schemaVersion === 1 && manifest.chainId === 10 && manifest.reviewed === true, 'Reviewed OP manifest required');
  need(typeof manifest.cType === 'string' && /^[A-Z][A-Z0-9-]{1,30}$/.test(manifest.cType), 'Explicit distinct cType required');
  need(!LEGACY_TYPES.includes(manifest.cType), 'Legacy collateral type cannot be reused');
  const cType = encodeBytes32String(manifest.cType);
  const authority = getAddress(manifest.executionAuthority);
  need(!same(authority, ZeroAddress), 'Execution authority required');
  const token = getAddress(manifest.token?.address);
  need(!LEGACY_TOKENS.some((old) => same(old, token)) && !same(token, ZeroAddress), 'New synthetic token identity required');
  const oracle = getAddress(manifest.oracle?.address);
  const reuseOracle = manifest.oraclePolicy === 'reuse-existing-haiaero-pyth';
  need(reuseOracle || manifest.oraclePolicy === 'reviewed-new-oracle', 'Explicit oracle policy required');
  if (reuseOracle) need(same(oracle,EXISTING_ORACLE.address) && same(manifest.oracle.runtimeCodeHash,EXISTING_ORACLE.runtimeCodeHash), 'Existing Pyth reuse must preserve the exact selected oracle address and runtime');
  let oracleMin = 1n, oracleMax = MAX_UINT;
  if (!reuseOracle) {
  const economic = manifest.oracle?.economicIdentity;
  need(economic?.reviewed === true && economic.underlyingChainId === 8453 && same(economic.underlyingToken, AERO)
    && same(economic.collateralToken, token) && economic.denomination === 'USD' && economic.valueDecimals === 18
    && typeof economic.reviewReference === 'string' && economic.reviewReference.trim().length > 0,
  'Explicit new AERO / new haiAERO USD oracle identity review required');
  oracleMin = uint(economic.minimumValue, 'oracle minimumValue', {positive: true});
  oracleMax = uint(economic.maximumValue, 'oracle maximumValue', {positive: true});
  need(oracleMax >= oracleMin, 'Oracle bounds reversed');
  }
  const r = manifest.risk;
  need(r && r.debtCeiling === '0', 'Initial debtCeiling must be explicitly zero');
  need(r.secondaryTaxPolicy === 'primary-only', 'Initial collateral must explicitly use primary-only tax policy');
  const risk = {
    debtFloor: uint(r.debtFloor, 'debtFloor [RAD]', {positive: true, max: MAX_RAD}),
    safetyCRatio: uint(r.safetyCRatio, 'safetyCRatio [RAY]', {positive: true}),
    liquidationCRatio: uint(r.liquidationCRatio, 'liquidationCRatio [RAY]', {positive: true}),
    liquidationPenalty: uint(r.liquidationPenalty, 'liquidationPenalty [WAD]', {positive: true}),
    liquidationQuantity: uint(r.liquidationQuantity, 'liquidationQuantity [RAD]', {positive: true, max: MAX_RAD}),
    stabilityFee: uint(r.stabilityFee, 'stabilityFee [RAY]', {positive: true}),
    minimumBid: uint(r.auction?.minimumBid, 'minimumBid [WAD]', {positive: true}),
    minDiscount: uint(r.auction?.minDiscount, 'minDiscount [WAD]', {positive: true, max: WAD}),
    maxDiscount: uint(r.auction?.maxDiscount, 'maxDiscount [WAD]', {positive: true, max: WAD}),
    perSecondDiscountUpdateRate: uint(r.auction?.perSecondDiscountUpdateRate, 'perSecondDiscountUpdateRate [RAY]', {positive: true, max: RAY})
  };
  need(risk.safetyCRatio >= risk.liquidationCRatio && risk.liquidationCRatio >= RAY, 'Invalid collateralization ratios');
  need(risk.liquidationPenalty >= WAD, 'Liquidation penalty below 100%');
  need(risk.minDiscount >= risk.maxDiscount, 'Auction minDiscount must be at least maxDiscount (remaining-price factors)');
  return {cType, authority, token, oracle, reuseOracle, oracleMin, oracleMax, risk};
}

export function encodePhase(manifest, phase, deployed = {}) {
  const {cType, token, oracle, risk: r} = validateManifest(manifest);
  const tx = (to, method, args, description) => ({to, value: '0', data: methods.encodeFunctionData(method, args), description});
  const init = (core, fields, values, description) => tx(CORE[core].address, 'initializeCollateralType', [cType, coder.encode(fields, values)], description);
  if (phase === 'factories') return [
    tx(CORE.joinFactory.address, 'deployCollateralJoin', [cType, token], 'Deploy new collateral join; factory authorizes the actual child in SAFEEngine'),
    init('auctionFactory', ['tuple(uint256,uint256,uint256,uint256)'], [[r.minimumBid, r.minDiscount, r.maxDiscount, r.perSecondDiscountUpdateRate]], 'Deploy actual collateral auction house via factory')
  ];
  need(phase === 'initialize', 'Phase must be factories or initialize');
  need(deployed.join && deployed.auction && !same(deployed.join, ZeroAddress) && !same(deployed.auction, ZeroAddress), 'Actual finalized factory children required; predictions are not accepted');
  return [
    init('safeEngine', ['tuple(uint256,uint256)'], [[0n, r.debtFloor]], 'Initialize new collateral with borrowing disabled (debtCeiling=0)'),
    init('oracleRelayer', ['tuple(address,uint256,uint256)'], [[oracle, r.safetyCRatio, r.liquidationCRatio]], 'Initialize the selected reviewed oracle and risk ratios'),
    init('liquidationEngine', ['tuple(address,uint256,uint256)'], [[deployed.auction, r.liquidationPenalty, r.liquidationQuantity]], 'Initialize actual new auction house and liquidation parameters'),
    init('taxCollector', ['tuple(uint256)'], [[r.stabilityFee]], 'Initialize stability fee; no secondary tax receivers are added'),
    tx(CORE.oracleRelayer.address, 'updateCollateralPrice', [cType], 'Initialize collateral prices; debt ceiling stays zero')
  ];
}

export async function prepareCollateral(manifest, phase, provider) {
  const validated = validateManifest(manifest);
  need(Number(BigInt(await provider.send('eth_chainId', []))) === 10, 'RPC must be Optimism mainnet');
  const block = await provider.getBlock('finalized');
  need(block?.hash && block.number > 0, 'Finalized block required');
  const snapshot = {blockNumber: block.number, finalizedBlockNumber: block.number, blockHash: block.hash};
  const options = {blockTag: block.number};
  const core = {};
  for (const [name, identity] of Object.entries(CORE)) {
    await verifyRuntime(provider, identity, block.number);
    core[name] = new Contract(identity.address, ABIS[name], provider);
    if (name !== 'taxCollector') need(await core[name].contractEnabled(options), `${name} is disabled`);
    need(await core[name].authorizedAccounts(validated.authority, options), `Execution authority is not authorized for ${name}`);
    if (name !== 'safeEngine') need(same(await core[name].safeEngine(options), CORE.safeEngine.address), `${name} SAFEEngine mismatch`);
  }
  need(await core.safeEngine.authorizedAccounts(CORE.joinFactory.address, options), 'Join factory lacks SAFEEngine authorization');
  need(same(await core.auctionFactory.liquidationEngine(options), CORE.liquidationEngine.address)
    && same(await core.auctionFactory.oracleRelayer(options), CORE.oracleRelayer.address), 'Auction factory dependencies mismatch');
  await verifyDeployment(provider, manifest.token, snapshot);
  if (validated.reuseOracle) {
    const legacyOracle = await core.oracleRelayer.cParams(encodeBytes32String('HAIAERO'), options);
    need(same(legacyOracle.oracle, validated.oracle), 'Reused oracle must match the current legacy HAIAERO oracle binding');
    await verifyRuntime(provider, EXISTING_ORACLE, block.number);
    await verifyRuntime(provider, EXISTING_SOURCE, block.number);
    await verifyRuntime(provider, EXISTING_AGGREGATOR, block.number);
    const delayed = new Contract(validated.oracle,['function priceSource() view returns(address)','function updateDelay() view returns(uint256)','function lastUpdateTime() view returns(uint256)'],provider);
    const source = new Contract(EXISTING_SOURCE.address,['function priceFeed() view returns(address)','function getResultWithValidity() view returns(uint256,bool)'],provider);
    const aggregator = new Contract(EXISTING_AGGREGATOR.address,['function priceId() view returns(bytes32)','function pyth() view returns(address)'],provider);
    need(same(await delayed.priceSource(options),EXISTING_SOURCE.address) && same(await source.priceFeed(options),EXISTING_AGGREGATOR.address)
      && same(await aggregator.pyth(options),'0xff1a0f4744e8582DF1aE09D5611b887B6a12925C')
      && await aggregator.priceId(options) === '0x9db37f4d5654aad3e37e2e14ffd8d53265fb3026d1d8f91146539eebaa2ef45f', 'Existing Pyth oracle dependency binding changed');
    const updated = await delayed.lastUpdateTime(options), delay = await delayed.updateDelay(options);
    const [sourcePrice,sourceValid] = await source.getResultWithValidity(options);
    validateOracleFreshness(block.timestamp,updated,delay,sourcePrice,sourceValid);
    const current = new Contract(validated.oracle,['function getResultWithValidity() view returns(uint256,bool)'],provider);
    const [currentPrice,currentValid] = await current.getResultWithValidity(options);
    need(currentValid,'Existing delayed price is invalid');
    await oracleCheckpoints(provider,block,updated,delay,currentPrice);
  } else await verifyDeployment(provider, manifest.oracle, snapshot);
  const token = new Contract(validated.token, ['function decimals() view returns(uint8)'], provider);
  need(await token.decimals(options) === 18n, 'New synthetic must use 18 decimals');
  const oracle = new Contract(validated.oracle, ['function getResultWithValidity() view returns(uint256,bool)'], provider);
  const [price, valid] = await oracle.getResultWithValidity(options);
  need(valid && price >= validated.oracleMin && price <= validated.oracleMax, 'Oracle is invalid or outside explicitly reviewed bounds');
  const taxParams = await core.taxCollector.params(options);
  need(validated.risk.stabilityFee >= RAY - taxParams.maxStabilityFeeRange
    && validated.risk.stabilityFee <= RAY + taxParams.maxStabilityFeeRange, 'Stability fee outside current HAI tax range');
  for (const name of ['safeEngine', 'oracleRelayer', 'liquidationEngine', 'taxCollector']) {
    need(!(await core[name].collateralList(options)).includes(validated.cType), `${name}: collateral type already initialized`);
  }
  const join = await core.joinFactory.collateralJoins(validated.cType, options);
  const auction = await core.auctionFactory.collateralAuctionHouses(validated.cType, options);
  const auctionTypes = await core.auctionFactory.collateralList(options);
  const joinTypes = await core.joinFactory.collateralTypesList(options);
  if (phase === 'factories') {
    need(same(join, ZeroAddress) && same(auction, ZeroAddress) && !auctionTypes.includes(validated.cType)
      && !joinTypes.includes(validated.cType), 'Factory collateral type already exists; inspect it instead of redeploying');
  } else {
    need(phase === 'initialize', 'Phase must be factories or initialize');
    need(!same(join, ZeroAddress) && !same(auction, ZeroAddress) && same(join, manifest.children?.join?.address)
      && same(auction, manifest.children?.auction?.address), 'Actual factory child addresses and evidence required');
    await verifyDeployment(provider, manifest.children.join, snapshot);
    await verifyDeployment(provider, manifest.children.auction, snapshot);
    // Bind child creation evidence to the canonical factory, not a caller-chosen factory identity.
    for (const [kind, identity] of [['join', CORE.joinFactory], ['auction', CORE.auctionFactory]]) {
      const child = manifest.children[kind];
      const receipt = await provider.getTransactionReceipt(child.deploymentTransactionHash ?? child.transactionHash);
      verifyChildCreationEvent(kind,child,receipt,validated.cType,validated.token);
      const factory = child.factoryDeployment?.factory;
      need(factory && same(factory.address, identity.address) && same(factory.runtimeCodeHash, identity.runtimeCodeHash), 'Child evidence must use its canonical HAI factory');
    }
    const childAbi = ['function safeEngine() view returns(address)', 'function collateralType() view returns(bytes32)', 'function contractEnabled() view returns(bool)'];
    const j = new Contract(join, [...childAbi, 'function collateral() view returns(address)'], provider);
    const a = new Contract(auction, [...childAbi, 'function liquidationEngine() view returns(address)', 'function oracleRelayer() view returns(address)',
      'function params() view returns(uint256 minimumBid,uint256 minDiscount,uint256 maxDiscount,uint256 perSecondDiscountUpdateRate)'], provider);
    need(same(await j.safeEngine(options), CORE.safeEngine.address) && same(await j.collateral(options), validated.token)
      && await j.collateralType(options) === validated.cType && await j.contractEnabled(options), 'Actual join bindings mismatch');
    need(await core.safeEngine.authorizedAccounts(join, options), 'Actual join not authorized in SAFEEngine');
    need(same(await a.safeEngine(options), CORE.safeEngine.address) && await a.collateralType(options) === validated.cType
      && same(await a.liquidationEngine(options), CORE.liquidationEngine.address) && same(await a.oracleRelayer(options), CORE.oracleRelayer.address)
      && await a.contractEnabled(options), 'Actual auction bindings mismatch');
    const auctionParams = await a.params(options);
    for (const field of ['minimumBid', 'minDiscount', 'maxDiscount', 'perSecondDiscountUpdateRate']) {
      need(auctionParams[field] === validated.risk[field], `Actual auction ${field} differs from reviewed risk parameters`);
    }
  }
  const oldCollateralSnapshot = {};
  for (const symbol of LEGACY_TYPES) {
    const key = encodeBytes32String(symbol);
    oldCollateralSnapshot[symbol] = {};
    for (const name of ['safeEngine', 'oracleRelayer', 'liquidationEngine', 'taxCollector']) {
      const result = await core[name].cParams(key, options);
      oldCollateralSnapshot[symbol][name] = typeof result === 'bigint' ? result.toString() : Array.from(result, (item) => item.toString());
    }
  }
  const transactions = encodePhase(manifest, phase, {join, auction});
  return {schemaVersion: 1, unsigned: true, chainId: 10, phase, snapshot, cType: manifest.cType,
    executionAuthority: validated.authority, token: validated.token, oracle: validated.oracle,
    oraclePolicy: manifest.oraclePolicy, oracleObservedValue: price.toString(), initialDebtCeiling: '0', primaryTaxReceiver: taxParams.primaryTaxReceiver,
    secondaryTaxPolicy: 'primary-only', coreIdentities: CORE, oldCollateralSnapshot, transactions,
    governance: {targets: transactions.map((t) => t.to), values: transactions.map((t) => t.value), calldatas: transactions.map((t) => t.data)},
    limitations: ['This is unsigned call preparation, not a submitted proposal or an executed deployment.',
      'Execute factory phase, wait for finality and populate actual child evidence before preparing initialization.',
      'Fork-simulate the exact ordered governance batch and review transport, liquidity, oracle freshness and economics before signing.',
      'A separate reviewed governance action is required to raise the zero debt ceiling. No legacy collateral parameter is modified.']};
}

async function main() {
  const args = process.argv.slice(2);
  const option = (name) => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
  const input = option('--manifest'), output = option('--output'), phase = option('--phase');
  need(input && output && ['factories', 'initialize'].includes(phase), 'Usage: --manifest PATH --phase factories|initialize --output PATH');
  const manifest = JSON.parse(fs.readFileSync(input, 'utf8'));
  validateManifest(manifest); // Fail before contacting any RPC when mandatory reviewed inputs are absent.
  const provider = new JsonRpcProvider(manifest.rpcUrl, undefined, {batchMaxCount: 1});
  try {
    const result = await prepareCollateral(manifest, phase, provider);
    fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
    console.log(JSON.stringify({unsigned: true, phase, cType: result.cType, blockNumber: result.snapshot.blockNumber, calls: result.transactions.length, output}));
  } finally { provider.destroy(); }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => { console.error(error.code ? `Read-only preflight failed: ${error.code}` : error.message); process.exitCode = 1; });
}

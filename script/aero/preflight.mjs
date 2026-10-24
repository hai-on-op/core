#!/usr/bin/env node
// Read-only. No wallet, signer, sendTransaction or broadcast API exists in this program.
import fs from 'node:fs';
import {Contract, JsonRpcProvider, ZeroAddress, keccak256, zeroPadValue} from 'ethers';
import {verifyDeployment} from './verification.mjs';

const args = process.argv.slice(2);
const option = (name) => { const i = args.indexOf(name); return i < 0 ? undefined : args[i + 1]; };
const manifestPath = option('--manifest');
if (!manifestPath) throw new Error('Usage: node script/aero/preflight.mjs --manifest PATH [--output PATH]');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (manifest.schemaVersion !== 1) throw new Error('Unsupported manifest schema');
const UPSTREAM_COMMIT = '8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf';
const AERO = '0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee';
const SAERO = '0xBF7977E1521e9a3032bf7243Ee4712f311f13915';
const VOTER = '0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6';
const DEAD = '0x000000000000000000000000000000000000dEaD';
const OLD_BASE = '0x10398AbC267496E49106B07dd6BE13364D10dC71';
const OLD_BRIDGE = '0xD605046D24CdaD37Ca2Dff3aa8Ebf254CeEe86d5';
const OLD_OP = '0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152';
const ERC20 = ['function totalSupply() view returns(uint256)', 'function balanceOf(address) view returns(uint256)', 'function decimals() view returns(uint8)'];
const MIGRATOR = [
  'function outputToken() view returns(address)', 'function owner() view returns(address)', 'function treasury() view returns(address)',
  'function deploymentChainId() view returns(uint256)', 'function paused() view returns(bool)',
  'function readiness() view returns(uint256 inventory,uint256 requiredOutput,bool capsCoverLiabilities,bool ready)',
  'function sourceTokens() view returns(address[])',
  'function routes(address) view returns(uint256 numerator,uint256 denominator,uint256 cap,uint256 migrated,address excludedCustody)',
  'function outstanding(address) view returns(uint256)'
];
const WRAPPER = [...ERC20, 'function owner() view returns(address)', 'function treasury() view returns(address)',
  'function deploymentChainId() view returns(uint256)', 'function BASE_TOKEN() view returns(address)',
  'function BASE_TOKEN_NFT() view returns(address)', 'function voter() view returns(address)', 'function totalIssuedPrincipal() view returns(uint256)',
  'function backingTokenIds() view returns(uint256[])', 'function principalOf(uint256) view returns(uint256)'];
const ESCROW = ['function balanceOf(address) view returns(uint256)', 'function TOKEN() view returns(address)', 'function VOTER() view returns(address)', 'function ownerOf(uint256) view returns(address)',
  'function staked(uint256) view returns(tuple(uint128 amount,uint48 end,bool isPermanent))', 'function getApproved(uint256) view returns(address)'];
const report = {schemaVersion: 1, checkedAt: new Date().toISOString(), upstreamCommit: UPSTREAM_COMMIT,
  scope: 'Contract identity, original-NFT custody and local legacy reserve checks only; excludes oracle/collateral governance, rewards, liquidity and in-flight-message reconciliation.',
  checks: [], chains: {}, contractsReady: false, contractLiveReady: false};
const check = (name, ok, detail) => { report.checks.push({name, ok: Boolean(ok), ...(detail === undefined ? {} : {detail})}); return Boolean(ok); };
const same = (a, b) => typeof a === 'string' && typeof b === 'string' && a.toLowerCase() === b.toLowerCase();
const ceil = (x, n, d) => (x * n + d - 1n) / d;
const rpc = {};
const blocks = {};
const finalizedBlocks = {};
check('reviewed upstream source commit', manifest.upstreamCommit === UPSTREAM_COMMIT);
check('treasury Safe custody reviewed', manifest.treasuryCustodyReviewed === true);
check('new bridge route reviewed', manifest.bridgeRouteReviewed === true);

async function deployment(chain, name, entry) {
  if (!check(`${chain}.${name} deployment evidence supplied`, Boolean(entry))) return false;
  try {
    await verifyDeployment(rpc[chain], entry, {blockNumber: blocks[chain], finalizedBlockNumber: finalizedBlocks[chain]});
    return check(`${chain}.${name} finalized canonical creation and runtime`, true);
  } catch (error) {
    return check(`${chain}.${name} finalized canonical creation and runtime`, false,
      error.code ? `RPC or contract error: ${error.code}` : error.message);
  }

}

try {
  for (const [chain, expectedId] of [['base', 8453], ['optimism', 10]]) {
    const config = manifest[chain];
    if (!config || config.chainId !== expectedId) throw new Error(`Invalid ${chain} chain configuration`);
    rpc[chain] = new JsonRpcProvider(config.rpcUrl, undefined, {batchMaxCount: 1});
    const actualId = Number(BigInt(await rpc[chain].send('eth_chainId', [])));
    if (!check(`${chain} RPC chain`, actualId === expectedId)) throw new Error('RPC chain mismatch');
    blocks[chain] = await rpc[chain].getBlockNumber();
    finalizedBlocks[chain] = (await rpc[chain].getBlock('finalized')).number;
    report.chains[chain] = {chainId: expectedId, blockNumber: blocks[chain], finalizedBlockNumber: finalizedBlocks[chain], sources: []};
  }
  const upstream = [
    [AERO, 'new AERO', '0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9'],
    [SAERO, 'sAERO', '0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e'],
    [VOTER, 'root voter', '0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b']
  ];
  for (const [address, name, hash] of upstream) {
    const code = await rpc.base.getCode(address, blocks.base);
    check(`upstream ${name} verified runtime`, code !== '0x' && same(keccak256(code), hash));
  }
  const escrow = new Contract(SAERO, ESCROW, rpc.base);
  check('sAERO token and voter bindings', same(await escrow.TOKEN({blockTag: blocks.base}), AERO)
    && same(await escrow.VOTER({blockTag: blocks.base}), VOTER));

  for (const chain of ['base', 'optimism']) {
    const config = manifest[chain], blockTag = blocks[chain];
    const definitions = chain === 'base' ? [[OLD_BASE, 1n, 1n, OLD_BRIDGE]] : [
      ['0x70f3713512089736661F928B291d1443C8b1BB6A', 44n, 1000n, ZeroAddress],
      ['0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6', 44n, 1000n, ZeroAddress],
      [OLD_OP, 1n, 1n, ZeroAddress]
    ];
    const outputEntry = chain === 'base' ? config.wrapper : config.output;
    const validOutput = await deployment(chain, chain === 'base' ? 'wrapper' : 'output', outputEntry);
    const validMigrator = await deployment(chain, 'migrator', config.migrator);
    let required = 0n;
    for (const [address, numerator, denominator, exclusion] of definitions) {
      const token = new Contract(address, ERC20, rpc[chain]);
      const supply = await token.totalSupply({blockTag});
      const dead = await token.balanceOf(DEAD, {blockTag});
      const surrendered = validMigrator ? await token.balanceOf(config.migrator.address, {blockTag}) : 0n;
      const bridged = same(exclusion, ZeroAddress) ? 0n : await token.balanceOf(exclusion, {blockTag});
      const outstanding = supply - dead - surrendered - bridged;
      if (outstanding < 0n) throw new Error('Source exclusions exceed supply');
      required += ceil(outstanding, numerator, denominator);
      report.chains[chain].sources.push({address, supply, dead, surrendered, excludedBridgeCustody: bridged, outstanding, numerator, denominator});
    }
    report.chains[chain].requiredOutput = required;
    if (validMigrator && validOutput) {
      const m = new Contract(config.migrator.address, MIGRATOR, rpc[chain]);
      check(`${chain} output identity`, same(await m.outputToken({blockTag}), outputEntry.address));
      check(`${chain} migration chain binding`, await m.deploymentChainId({blockTag}) === BigInt(config.chainId));
      check(`${chain} migrator owner`, same(await m.owner({blockTag}), config.migrator.owner));
      check(`${chain} immutable treasury`, same(await m.treasury({blockTag}), config.migrator.treasury));
      const sourceTokens = await m.sourceTokens({blockTag});
      check(`${chain} all canonical sources`, sourceTokens.length === definitions.length && sourceTokens.every((a, i) => same(a, definitions[i][0])));
      for (const [source, numerator, denominator, exclusion] of definitions) {
        const route = await m.routes(source, {blockTag});
        check(`${chain} route ${source} immutable terms`, route.numerator === numerator && route.denominator === denominator && same(route.excludedCustody, exclusion));
      }
      const state = await m.readiness({blockTag});
      check(`${chain} independent liability reconciliation`, state.requiredOutput === required);
      check(`${chain} entire local liability funded`, state.inventory >= required);
      check(`${chain} caps cover legacy tail`, state.capsCoverLiabilities);
      report.chains[chain].migration = {inventory: state.inventory, requiredOutput: state.requiredOutput, paused: await m.paused({blockTag}), ready: state.ready};
    }
  }

  if (manifest.base.wrapper && await deployment('base', 'wrapper-custody', manifest.base.wrapper)) {
    const config = manifest.base.wrapper, blockTag = blocks.base;
    const wrapper = new Contract(config.address, WRAPPER, rpc.base);
    check('wrapper canonical underlying and escrow', same(await wrapper.BASE_TOKEN({blockTag}), AERO) && same(await wrapper.BASE_TOKEN_NFT({blockTag}), SAERO));
    check('wrapper root voter', same(await wrapper.voter({blockTag}), VOTER));
    check('wrapper Base chain binding', await wrapper.deploymentChainId({blockTag}) === 8453n);
    check('wrapper owner', same(await wrapper.owner({blockTag}), config.owner));
    check('immutable treasury Safe', same(await wrapper.treasury({blockTag}), config.treasury));
    const safe = new Contract(config.treasury, ['function getOwners() view returns(address[])', 'function getThreshold() view returns(uint256)'], rpc.base);
    const owners = await safe.getOwners({blockTag});
    const threshold = await safe.getThreshold({blockTag});
    check('treasury Safe owners and threshold', Array.isArray(config.treasuryOwners) && config.treasuryOwners.length === owners.length
      && owners.every((owner) => config.treasuryOwners.some((expected) => same(owner, expected)))
      && threshold > 0n && threshold === BigInt(config.treasuryThreshold ?? 0));
    const portfolioIds = config.treasuryTokenIds ?? [];
    const completePortfolio = Array.isArray(portfolioIds) && new Set(portfolioIds.map(String)).size === portfolioIds.length
      && BigInt(portfolioIds.length) === await escrow.balanceOf(config.treasury, {blockTag});
    check('complete current treasury NFT census supplied', completePortfolio);
    let currentTreasuryPrincipal = 0n;
    const currentPortfolio = [];
    if (completePortfolio) for (const id of portfolioIds) {
      const owner = await escrow.ownerOf(id, {blockTag}), stake = await escrow.staked(id, {blockTag});
      check(`current treasury NFT ${id} owned`, same(owner, config.treasury));
      const permanentPrincipal = stake.isPermanent && stake.end === 0n ? stake.amount : 0n;
      currentTreasuryPrincipal += permanentPrincipal;
      currentPortfolio.push({tokenId: id, permanentPrincipal});
    }
    let recorded = 0n, principal = 0n;
    const ids = await wrapper.backingTokenIds({blockTag});
    for (const id of ids) {
      const stake = await escrow.staked(id, {blockTag});
      const issued = await wrapper.principalOf(id, {blockTag});
      check(`backing NFT ${id} permanent owned principal`, same(await escrow.ownerOf(id, {blockTag}), config.treasury)
        && stake.isPermanent && stake.end === 0n && stake.amount >= issued && issued > 0n);
      recorded += issued;
      principal += stake.amount;
    }
    const supply = await wrapper.totalSupply({blockTag});
    check('recorded issuance and original treasury principal reconciliation', recorded === supply && recorded === await wrapper.totalIssuedPrincipal({blockTag}) && principal >= supply);
    report.chains.base.wrapper = {supply, recordedPrincipal: recorded, originalIdsLivePrincipal: principal, backingTokenIds: ids,
      currentTreasuryPrincipal, currentPortfolio, note: 'Initial activation requires every issued original ID to remain in custody. The full current portfolio includes potentially unissued principal and does not authorize replacement-ID reissuance or establish allocation by itself.'};
  }
  if (manifest.base.bridge && manifest.base.wrapper && manifest.optimism.output) {
    const validBridge = await deployment('base', 'bridge', manifest.base.bridge);
    if (validBridge) {
      const bridgeSecurity = ['function owner() view returns(address)', 'function mailbox() view returns(address)', 'function interchainSecurityModule() view returns(address)'];
      const bridgeAbi = [...bridgeSecurity, 'function wrappedToken() view returns(address)', 'function routers(uint32) view returns(bytes32)'];
      const baseBridge = new Contract(manifest.base.bridge.address, bridgeAbi, rpc.base);
      const opBridge = new Contract(manifest.optimism.output.address, [...ERC20, ...bridgeSecurity, 'function routers(uint32) view returns(bytes32)'], rpc.optimism);
      for (const [chain, router, config] of [['base', baseBridge, manifest.base.bridge], ['optimism', opBridge, manifest.optimism.output]]) {
        const options = {blockTag: blocks[chain]};
        check(`${chain} bridge owner`, same(await router.owner(options), config.owner));
        check(`${chain} bridge mailbox`, same(await router.mailbox(options), config.mailbox));
        check(`${chain} bridge security module`, same(await router.interchainSecurityModule(options), config.ism));
      }
      check('new bridge locks only new wrapper', same(await baseBridge.wrappedToken({blockTag: blocks.base}), manifest.base.wrapper.address));
      check('new bridge reciprocal routes', same(await baseBridge.routers(10, {blockTag: blocks.base}), zeroPadValue(manifest.optimism.output.address, 32))
        && same(await opBridge.routers(8453, {blockTag: blocks.optimism}), zeroPadValue(manifest.base.bridge.address, 32)));
      const wrapper = new Contract(manifest.base.wrapper.address, ERC20, rpc.base);
      const locked = await wrapper.balanceOf(manifest.base.bridge.address, {blockTag: blocks.base});
      const synthetic = await opBridge.totalSupply({blockTag: blocks.optimism});
      check('new bridge synthetic covered by Base locked output', locked >= synthetic);
      report.bridge = {locked, synthetic, note: 'Pins are per chain, not an atomic cross-chain snapshot. Reconcile pending messages before activation.'};
    }
  } else check('new bridge deployment evidence supplied', false);
} catch (error) {
  // Do not include provider URLs or request bodies, which can contain API credentials.
  check('preflight completed', false, error.code ? `RPC or contract error: ${error.code}` : 'Invalid configuration or unexpected contract response');
} finally {
  for (const provider of Object.values(rpc)) provider.destroy();
}
report.contractsReady = report.checks.every((entry) => entry.ok);
report.contractLiveReady = report.contractsReady && report.chains.base?.migration?.ready === true && report.chains.optimism?.migration?.ready === true;
const json = JSON.stringify(report, (_, value) => typeof value === 'bigint' ? value.toString() : value, 2);
if (option('--output')) fs.writeFileSync(option('--output'), `${json}\n`);
console.log(json);
process.exitCode = report.contractsReady ? 0 : 2;

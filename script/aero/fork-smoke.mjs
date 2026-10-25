#!/usr/bin/env node
// Starts a disposable local Anvil fork. No signing or mutation is sent to the upstream RPC.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import {spawn} from 'node:child_process';
import {Contract, ContractFactory, JsonRpcProvider, JsonRpcSigner, keccak256, parseEther, solidityPacked, toBeHex, ZeroAddress, id} from 'ethers';

const AERO = '0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee';
const SAERO = '0xBF7977E1521e9a3032bf7243Ee4712f311f13915';
const VOTER = '0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6';
const BLOCK = 53038227;
const TREASURY = '0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3';
const server = net.createServer();
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
await new Promise((resolve) => server.close(resolve));
const child = spawn('anvil', ['--host', '127.0.0.1', '--port', String(port), '--fork-url', process.env.AERO_FORK_RPC || 'https://mainnet.base.org',
  '--fork-block-number', String(BLOCK), '--hardfork', 'prague', '--chain-id', '8453', '--silent'], {stdio: 'ignore'});
const provider = new JsonRpcProvider(`http://127.0.0.1:${port}`, 8453, {batchMaxCount: 1, pollingInterval: 50, staticNetwork: true});
const checks = [];
const record = (name) => checks.push(name);
async function mined(transaction) {
  const tx = await transaction;
  for (let i = 0; i < 300; ++i) {
    const receipt = await provider.send('eth_getTransactionReceipt', [tx.hash]);
    if (receipt) { assert.equal(receipt.status, '0x1', `Local transaction reverted: ${tx.hash}`); return receipt; }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Local transaction receipt timeout');
}
async function reverted(operation, name) { await assert.rejects(operation); record(name); }
try {
  let connected = false;
  for (let i = 0; i < 100; ++i) {
    if (child.exitCode !== null) throw new Error('Local Anvil exited before startup');
    try { await provider.send('eth_chainId', []); connected = true; break; } catch { await new Promise((r) => setTimeout(r, 100)); }
  }
  assert(connected, 'Local Anvil did not start');
  // No remote URL can be supplied for mutation: the provider is constructed above with an allocated loopback port.
  assert.match(await provider.send('web3_clientVersion', []), /anvil/i);
  for (const [address, hash] of [
    [AERO, '0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9'],
    [SAERO, '0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e'],
    [VOTER, '0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b']
  ]) assert.equal(keccak256(await provider.getCode(address)), hash);
  record('canonical runtime hashes at pinned Base block');
  const signer = await provider.getSigner(0);
  const account = await signer.getAddress();
  const artifact = JSON.parse(fs.readFileSync('out/HaiAero.sol/HaiAero.json', 'utf8'));
  const wrapper = await new ContractFactory(artifact.abi, artifact.bytecode.object, signer).deploy(AERO, SAERO, account, TREASURY, 8453);
  await mined(wrapper.deploymentTransaction());
  const address = await wrapper.getAddress();
  const aero = new Contract(AERO, ['function balanceOf(address) view returns(uint256)', 'function totalSupply() view returns(uint256)',
    'function approve(address,uint256) returns(bool)', 'function transfer(address,uint256) returns(bool)', 'function allowance(address,address) view returns(uint256)'], signer);
  const escrow = new Contract(SAERO, ['function createStake(uint128,uint48,bool) returns(uint256)', 'function tokenId() view returns(uint256)',
    'function approve(address,uint256)', 'function transferFrom(address,address,uint256)', 'function ownerOf(uint256) view returns(address)',
    'function getApproved(uint256) view returns(address)', 'function staked(uint256) view returns(tuple(uint128 amount,uint48 end,bool isPermanent))'], signer);
  // Solady ERC20 storage slots verified from the source bundle; analogous to forge deal(), LOCAL FORK ONLY.
  const balanceSlot = keccak256(solidityPacked(['address', 'uint96'], [account, 0x87a211a2]));
  const supplySlot = toBeHex(0x05345cdf77eb68f44cn, 32);
  const oldBalance = await aero.balanceOf(account);
  const oldSupply = await aero.totalSupply();
  assert.equal(BigInt(await provider.getStorage(AERO, balanceSlot)), oldBalance);
  assert.equal(BigInt(await provider.getStorage(AERO, supplySlot)), oldSupply);
  await provider.send('anvil_setStorageAt', [AERO, balanceSlot, toBeHex(oldBalance + parseEther('100'), 32)]);
  await provider.send('anvil_setStorageAt', [AERO, supplySlot, toBeHex(oldSupply + parseEther('100'), 32)]);
  assert.equal(await aero.balanceOf(account), oldBalance + parseEther('100'));
  await mined(wrapper.unpause());
  await mined(aero.approve(address, parseEther('10')));
  await mined(wrapper.deposit(account, parseEther('10'), {gasLimit: 3000000}));
  const ids = await wrapper.backingTokenIds();
  assert.equal(ids.length, 1);
  const stake = await escrow.staked(ids[0]);
  assert.equal(stake.amount, parseEther('10'));
  assert.equal(stake.end, 0n);
  assert(stake.isPermanent);
  assert.equal(await escrow.ownerOf(ids[0]), TREASURY);
  assert.equal(await escrow.getApproved(ids[0]), ZeroAddress);
  assert.equal(await aero.allowance(address, SAERO), 0n);
  record('actual new AERO deposit creates exact permanent sAERO principal with cleared allowance');
  await mined(aero.approve(SAERO, parseEther('5')));
  await mined(escrow.createStake(parseEther('5'), 0, true, {gasLimit: 3000000}));
  const nft = await escrow.tokenId();
  await mined(escrow.approve(address, nft));
  await mined(wrapper.depositNFTs(account, [nft], {gasLimit: 3000000}));
  assert.equal(await escrow.ownerOf(nft), TREASURY);
  assert.equal(await wrapper.totalSupply(), parseEther('15'));
  assert.equal(await wrapper.totalIssuedPrincipal(), parseEther('15'));
  record('actual sAERO NFT intake mints principal and transfers custody to the treasury Safe');
  await reverted(() => wrapper.depositNFTs.staticCall(account, [nft]), 'same NFT cannot mint twice');
  await reverted(() => escrow.transferFrom.staticCall(TREASURY, account, nft), 'unapproved depositor cannot transfer treasury backing NFT');
  const registry = new Contract('0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E',
    ['function gaugeToRewards(address) view returns(address)', 'function rewardsToGauge(address) view returns(address)'], provider);
  const gauge = '0xd424BA8ca9d4E278753DE76651a0095451e65cD1';
  const rewards = '0x09Ad4a8E715a25Aa8aC91f6840005a8AfFcDa139';
  assert.equal(await registry.gaugeToRewards(gauge), rewards);
  assert.equal(await registry.rewardsToGauge(rewards), gauge);
  await provider.send('anvil_impersonateAccount', [TREASURY]);
  await provider.send('anvil_setBalance', [TREASURY, toBeHex(parseEther('10'))]);
  const safeSigner = new JsonRpcSigner(provider, TREASURY);
  const root = new Contract(VOTER, [
    'function allocate(uint256,(uint256,uint128,uint256,uint256)[],(uint256,uint256,uint256,(address,uint128,bytes)[])[],address) payable',
    'function claimRewards(uint256,(uint256,uint256,uint256,address,(address,uint256)[],(address,uint256,uint256)[])[],address) payable'
  ], safeSigner);
  await mined(root.allocate(ids[0], [[8453, parseEther('10'), 0, 0]],
    [[8453, 0, 0, [[gauge, parseEther('10'), '0x']]]], TREASURY, {gasLimit: 3000000}));
  const leaf = new Contract('0x382409fad8503FbCdbB27A4211551fa03e884078',
    ['function allocatedGauges(uint256) view returns(address[])'], provider);
  assert.deepEqual(Array.from(await leaf.allocatedGauges(ids[0])), [gauge]);
  const claim = await mined(root.claimRewards(ids[0], [[8453, 0, 0, TREASURY, [[rewards, 1]], []]], TREASURY, {gasLimit: 3000000}));
  assert(claim.logs.some((log) => log.topics[0] === id('FeeClaimSucceeded(uint256,address,address,uint256)')));
  assert.equal(await wrapper.backingOf(ids[0]), parseEther('10'));
  record('treasury Safe directly allocates to an actual Base gauge and claims via registered fee manager');
  const safeEscrow = escrow.connect(safeSigner);
  await mined(aero.transfer(TREASURY, parseEther('2')));
  await mined(aero.connect(safeSigner).approve(SAERO, parseEther('2')));
  await mined(safeEscrow.createStake(parseEther('2'), 0, true, {gasLimit: 3000000}));
  const treasuryId = await escrow.tokenId();
  // No approval or self-transfer: Safe deliberately recognizes an existing owned migrated position once.
  await mined(wrapper.connect(safeSigner).depositNFTs(account, [treasuryId], {gasLimit: 3000000}));
  assert.equal(await escrow.ownerOf(treasuryId), TREASURY);
  assert.equal(await wrapper.totalSupply(), parseEther('17'));
  await reverted(() => wrapper.connect(safeSigner).depositNFTs.staticCall(account, [treasuryId]), 'treasury intake cannot recognize same NFT twice');
  record('treasury-owned existing permanent NFT is recognized once without NFT approval');
  await mined(safeEscrow.transferFrom(TREASURY, account, nft));
  assert.equal(await wrapper.backingOf(nft), 0n);
  assert.equal(await wrapper.principalOf(nft), parseEther('5'));
  await reverted(() => wrapper.depositNFTs.staticCall(account, [nft]), 'treasury-transferred NFT cannot mint duplicate bearer claims');
  record('treasury retains transfer/migration control, with honest live custody status after transfer');
  const report = {localForkOnly: true, chainId: 8453, pinnedBlock: BLOCK, pinnedBlockHash: (await provider.getBlock(BLOCK)).hash, runtime: 'prague', artifact: 'out/HaiAero.sol/HaiAero.json', creationBytecodeHash: keccak256(artifact.bytecode.object), deployedRuntimeHash: keccak256(await provider.getCode(address)), checks,
    limits: ['Safe authorization is impersonated only on the local fork; production requires its real signatures. The new NFT has no accrued rewards; positive reward payout and remote-chain delivery require separate rehearsal.']};
  if (process.env.AERO_FORK_REPORT) fs.writeFileSync(process.env.AERO_FORK_REPORT, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally {
  provider.destroy();
  child.kill('SIGTERM');
}

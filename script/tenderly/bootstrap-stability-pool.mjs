import {spawnSync} from 'child_process';
import { mkdir, readFile, writeFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

import { ethers } from 'ethers';

import {
  DEFAULT_STEP_SLIPPAGE_BPS,
  DEFAULT_TARGET_DEBT_WAD,
  MAINNET_DEPLOYMENT,
  PROFITABILITY_PRICE_DIVISORS,
  RAY,
  STRATEGY_STEP_ARTIFACTS,
  WAD,
  buildPipelineConfigs,
  bytes32FromCType,
  stringFromBytes32,
} from './stability-pool-config.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '../..');

const PARAM_ORACLE = ethers.encodeBytes32String('oracle');
const ETH_TOP_UP = ethers.parseEther('250');
const DEFAULT_DEVIATION_LIMIT = ethers.parseUnits('0.1', 18);
const DEFAULT_AUCTION_AGE_SECONDS = 24 * 60 * 60;
const DEFAULT_POOL_HAI_DEPOSIT = ethers.parseUnits('250000', 18);
const DEFAULT_EMISSIONS_TOTAL_KITE = ethers.parseUnits('1000000', 18);
const DEFAULT_EMISSIONS_DURATION_SECONDS = 365 * 24 * 60 * 60;
const DEFAULT_MAX_QUOTE_STEPS = 4096;
const DEFAULT_AUCTIONS_PER_COLLATERAL = 3;
const DEFAULT_MANIFEST_PATH = path.join(ROOT_DIR, 'script', 'tenderly', 'bootstrap-stability-pool.manifest.json');
const VERIFY_MANIFEST_SCRIPT_PATH = path.join(ROOT_DIR, 'script', 'tenderly', 'verify-stability-pool-manifest.mjs');
const BID_MULTIPLIERS = [1n, 2n, 3n, 4n, 5n, 6n, 8n, 10n, 12n, 15n, 20n, 25n, 30n, 40n, 60n, 80n];
const MAX_EVM_RUNTIME_BYTECODE_BYTES = 24_576;
const MAX_EVM_INITCODE_BYTES = 49_152;
const DYNAMIC_BALANCE_FALLBACK_CTYPE_NAMES = new Set([
  'WSTETH',
  'RETH',
  'HAIVELOV2',
  'MSETH',
  'MOO-VELO-BOLD-LUSD',
  'YV-VELO-ALETH-WETH',
  'YV-VELO-MSETH-WETH',
]);

class UnlockedSigner extends ethers.AbstractSigner {
  constructor(provider, address) {
    super(provider);
    this.address = ethers.getAddress(address);
  }

  connect(provider) {
    return new UnlockedSigner(provider, this.address);
  }

  async getAddress() {
    return this.address;
  }

  async sendTransaction(tx) {
    const resolved = await ethers.resolveProperties(tx);
    const rpcTx = { from: this.address };

    if (resolved.to) rpcTx.to = resolved.to;
    if (resolved.data) rpcTx.data = resolved.data;
    if (resolved.value && resolved.value !== 0n) rpcTx.value = ethers.toQuantity(resolved.value);
    if (resolved.gasLimit) rpcTx.gas = ethers.toQuantity(resolved.gasLimit);
    if (resolved.maxFeePerGas) rpcTx.maxFeePerGas = ethers.toQuantity(resolved.maxFeePerGas);
    if (resolved.maxPriorityFeePerGas) rpcTx.maxPriorityFeePerGas = ethers.toQuantity(resolved.maxPriorityFeePerGas);
    if (resolved.gasPrice) rpcTx.gasPrice = ethers.toQuantity(resolved.gasPrice);
    if (resolved.nonce !== undefined && resolved.nonce !== null) rpcTx.nonce = ethers.toQuantity(resolved.nonce);
    if (resolved.type !== undefined && resolved.type !== null) rpcTx.type = ethers.toQuantity(resolved.type);
    if (resolved.chainId !== undefined && resolved.chainId !== null) {
      rpcTx.chainId = ethers.toQuantity(resolved.chainId);
    }

    const hash = await this.provider.send('eth_sendTransaction', [rpcTx]);
    await this.provider.waitForTransaction(hash);

    const response = await this.provider.getTransaction(hash);
    if (!response) {
      throw new Error(`Unable to fetch transaction response for ${hash}`);
    }

    return response;
  }

  async signTransaction() {
    throw new Error('UnlockedSigner does not sign raw transactions');
  }

  async signMessage() {
    throw new Error('UnlockedSigner does not sign messages');
  }

  async signTypedData() {
    throw new Error('UnlockedSigner does not sign typed data');
  }
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function parseBooleanEnv(name, fallback = false) {
  const value = process.env[name];
  if (value === undefined) return fallback;
  return value === '1' || value.toLowerCase() === 'true' || value.toLowerCase() === 'yes';
}

function parseIntegerEnv(name, fallback) {
  const value = process.env[name];
  if (value === undefined) return fallback;
  return Number.parseInt(value, 10);
}

function parseAmountEnv(name, fallback) {
  const value = process.env[name];
  if (value === undefined) return fallback;
  return ethers.parseUnits(value, 18);
}

function parseAllowlistEnv(name) {
  const raw = process.env[name];
  if (!raw) return null;

  const values = raw
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);

  return values.length > 0 ? new Set(values) : null;
}

function serialize(value) {
  return JSON.stringify(
    value,
    (_, current) => {
      if (typeof current === 'bigint') return current.toString();
      return current;
    },
    2
  );
}

function deterministicAddress(seed) {
  const base = BigInt('0x1000000000000000000000000000000000000000');
  return ethers.getAddress(ethers.zeroPadValue(ethers.toBeHex(base + BigInt(seed)), 20));
}

function ceilDiv(a, b) {
  return (a + b - 1n) / b;
}

function toTokenWeiFromWad(collateralWad, multiplier) {
  if (multiplier === 0n) return collateralWad;
  return ceilDiv(collateralWad, 10n ** multiplier);
}

function toCollateralWadFromWei(collateralWei, multiplier) {
  if (multiplier === 0n) return collateralWei;
  return collateralWei * 10n ** multiplier;
}

function minProfitSatisfied(expectedHai, adjustedBid, minProfitBps) {
  if (expectedHai < adjustedBid) return false;
  if (adjustedBid === 0n) return true;

  const requiredHai = ceilDiv(adjustedBid * (10_000n + minProfitBps), 10_000n);
  return expectedHai >= requiredHai;
}

function hexByteLength(value) {
  if (!value) return 0;
  const normalized = value.startsWith('0x') ? value.slice(2) : value;
  return normalized.length / 2;
}

function assertDeployableArtifact(name, artifact) {
  const initcodeBytes = hexByteLength(artifact.bytecode?.object);
  if (initcodeBytes > MAX_EVM_INITCODE_BYTES) {
    throw new Error(
      `${name} artifact at ${artifact.__artifactPath} has ${initcodeBytes} initcode bytes, above the EVM limit of ` +
        `${MAX_EVM_INITCODE_BYTES}.`
    );
  }

  const runtimeBytes = hexByteLength(artifact.deployedBytecode?.object);
  if (runtimeBytes > MAX_EVM_RUNTIME_BYTECODE_BYTES) {
    const fixHint =
      name === 'StabilityPool'
        ? " Build the via-IR artifact with 'FOUNDRY_PROFILE=optimized forge build src/contracts/stability-pool/StabilityPool.sol' and rerun."
        : '';
    throw new Error(
      `${name} artifact at ${artifact.__artifactPath} has ${runtimeBytes} runtime bytecode bytes, above the EVM ` +
        `limit of ${MAX_EVM_RUNTIME_BYTECODE_BYTES}.${fixHint}`
    );
  }
}

async function loadArtifact(relativePathOrPaths) {
  const relativePaths = Array.isArray(relativePathOrPaths) ? relativePathOrPaths : [relativePathOrPaths];
  let lastError = null;

  for (const relativePath of relativePaths) {
    const absolutePath = path.join(ROOT_DIR, relativePath);

    try {
      const file = await readFile(absolutePath, 'utf8');
      const artifact = JSON.parse(file);
      artifact.__artifactPath = relativePath;
      return artifact;
    } catch (error) {
      if (error.code !== 'ENOENT') {
        throw error;
      }
      lastError = error;
    }
  }

  if (lastError) {
    throw lastError;
  }

  throw new Error(`Unable to locate artifact from candidates: ${relativePaths.join(', ')}`);
}

function contractAt(address, artifact, runner) {
  return new ethers.Contract(address, artifact.abi, runner);
}

async function deployContract(name, artifact, signer, args = []) {
  assertDeployableArtifact(name, artifact);
  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode.object, signer);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`deployed ${name}: ${address}`);
  return contract;
}

async function sendAndWait(label, txPromise) {
  console.log(label);
  const tx = await txPromise;
  const receipt = await tx.wait();
  if (!receipt || Number(receipt.status) !== 1) {
    throw new Error(`Transaction failed: ${label}`);
  }
  return receipt;
}

async function topUpEth(provider, addresses, value) {
  const list = Array.isArray(addresses) ? addresses : [addresses];
  const quantity = ethers.toQuantity(value);

  try {
    await provider.send('tenderly_setBalance', [list, quantity]);
    return;
  } catch (error) {
    if (list.length > 1) {
      for (const address of list) {
        await topUpEth(provider, address, value);
      }
      return;
    }
  }

  await provider.send('tenderly_setBalance', [list[0], quantity]);
}

async function setTokenBalance(provider, token, holder, amount, allowMaxFallback) {
  try {
    await provider.send('tenderly_setErc20Balance', [token, holder, ethers.toQuantity(amount)]);
    return { method: 'tenderly_setErc20Balance', amount: amount.toString() };
  } catch (error) {
    if (!allowMaxFallback) throw error;
  }

  try {
    await provider.send('tenderly_setMaxErc20Balance', [token, holder]);
    return { method: 'tenderly_setMaxErc20Balance', amount: 'max' };
  } catch (error) {
    await provider.send('tenderly_setErc20MaxBalance', [token, holder]);
    return { method: 'tenderly_setErc20MaxBalance', amount: 'max' };
  }
}

async function warpTime(provider, seconds) {
  if (seconds <= 0) return;

  try {
    await provider.send('evm_increaseTime', [seconds]);
  } catch (error) {
    const latestBlock = await provider.getBlock('latest');
    await provider.send('evm_setNextBlockTimestamp', [Number(latestBlock.timestamp) + seconds]);
  }

  await provider.send('evm_mine', []);
}

async function getOraclePrice(provider, artifacts, oracleAddress) {
  const oracle = contractAt(oracleAddress, artifacts.IBaseOracle, provider);

  try {
    const [result, valid] = await oracle.getResultWithValidity();
    if (valid && result > 0n) {
      return result;
    }
  } catch {}

  try {
    const value = await oracle.read();
    if (value > 0n) {
      return value;
    }
  } catch {}

  return 0n;
}

function computeSafePlan({ cData, cParams, multiplier, targetDebtWad }) {
  const safetyPrice = cData.safetyPrice;
  const accumulatedRate = cData.accumulatedRate;
  const debtFloorWad = cParams.debtFloor / RAY;
  const minimumTargetDebt = targetDebtWad > debtFloorWad ? targetDebtWad : debtFloorWad;

  if (safetyPrice === 0n || accumulatedRate === 0n) {
    throw new Error('Collateral safety price or accumulated rate is zero');
  }

  let collateralWad = ceilDiv(minimumTargetDebt * accumulatedRate * 12_000n, safetyPrice * 10_000n);
  let collateralWei = toTokenWeiFromWad(collateralWad, multiplier);
  collateralWad = toCollateralWadFromWei(collateralWei, multiplier);

  let maxDebtWad = (collateralWad * safetyPrice) / accumulatedRate;
  while (maxDebtWad <= debtFloorWad) {
    collateralWei *= 2n;
    collateralWad = toCollateralWadFromWei(collateralWei, multiplier);
    maxDebtWad = (collateralWad * safetyPrice) / accumulatedRate;
  }

  let debtWad = minimumTargetDebt;
  const safeDebtWad = (maxDebtWad * 95n) / 100n;
  if (debtWad > safeDebtWad) debtWad = safeDebtWad;
  if (debtWad < debtFloorWad) debtWad = debtFloorWad;

  if (debtWad === 0n || debtWad > maxDebtWad) {
    throw new Error('Unable to compute a safe debt position');
  }

  return {
    collateralWei,
    collateralWad,
    debtWad,
    debtFloorWad,
    maxDebtWad,
    safeDebtWad,
  };
}

async function findProfitableBid({
  artifacts,
  auction,
  auctionId,
  cTypeBytes32,
  multiplier,
  minProfitBps,
  stabilityPool,
  systemCoin,
  stabilityPoolAddress,
}) {
  const auctionParams = await auction.params();
  let minimumBid = auctionParams.minimumBid;
  if (minimumBid === 0n) {
    minimumBid = WAD;
  }

  const maxPoolBid = await systemCoin.balanceOf(stabilityPoolAddress);
  const candidates = [];

  for (const multiplierStep of BID_MULTIPLIERS) {
    const candidateBid = minimumBid * multiplierStep;
    if (candidateBid > maxPoolBid) continue;
    candidates.push(candidateBid);
  }

  const auctionData = await auction.auctions(auctionId);
  const amountToRaiseWad = ceilDiv(auctionData.amountToRaise, RAY);
  if (amountToRaiseWad > 0n && amountToRaiseWad <= maxPoolBid) {
    candidates.push(amountToRaiseWad);
  }

  for (const candidateBid of candidates) {
    const [estimatedCollateralBought, adjustedBid] = await auction.getCollateralBought(auctionId, candidateBid);
    if (estimatedCollateralBought === 0n || adjustedBid === 0n) continue;

    const estimatedCollateralWei = toTokenWeiFromWad(estimatedCollateralBought, multiplier);
    const expectedHai = await stabilityPool.previewSwapToHai(cTypeBytes32, estimatedCollateralWei);
    if (!minProfitSatisfied(expectedHai, adjustedBid, minProfitBps)) continue;

    return {
      bidAmount: candidateBid,
      adjustedBid,
      expectedHai,
      estimatedCollateralBought,
      estimatedCollateralWei,
    };
  }

  return null;
}

async function stageSafe({
  artifacts,
  allowDynamicBalanceFallback,
  cTypeBytes32,
  cTypeName,
  coinJoin,
  collateralJoin,
  collateralJoinAddress,
  ownerAddress,
  ownerSigner,
  provider,
  safeEngine,
  targetDebtWad,
}) {
  const collateralToken = await collateralJoin.collateral();
  const multiplier = BigInt(await collateralJoin.multiplier());
  const cData = await safeEngine.cData(cTypeBytes32);
  const cParams = await safeEngine.cParams(cTypeBytes32);
  const plan = computeSafePlan({ cData, cParams, multiplier, targetDebtWad });

  await setTokenBalance(provider, collateralToken, ownerAddress, plan.collateralWei, allowDynamicBalanceFallback);

  const erc20 = contractAt(
    collateralToken,
    {
      abi: [
        'function approve(address spender, uint256 value) external returns (bool)',
        'function balanceOf(address owner) external view returns (uint256)',
      ],
    },
    ownerSigner
  );

  await sendAndWait(
    `approve ${cTypeName} collateral for ${ownerAddress}`,
    erc20.approve(collateralJoinAddress, ethers.MaxUint256)
  );
  await sendAndWait(
    `join ${cTypeName} collateral for ${ownerAddress}`,
    collateralJoin.connect(ownerSigner).join(ownerAddress, plan.collateralWei)
  );
  await sendAndWait(
    `allow ${cTypeName} collateral join to modify SAFE for ${ownerAddress}`,
    safeEngine.connect(ownerSigner).approveSAFEModification(collateralJoinAddress)
  );
  await sendAndWait(
    `open ${cTypeName} SAFE for ${ownerAddress}`,
    safeEngine.connect(ownerSigner).modifySAFECollateralization(
      cTypeBytes32,
      ownerAddress,
      ownerAddress,
      ownerAddress,
      plan.collateralWad,
      plan.debtWad
    )
  );
  await sendAndWait(
    `allow CoinJoin to exit HAI for ${ownerAddress}`,
    safeEngine.connect(ownerSigner).approveSAFEModification(await coinJoin.getAddress())
  );
  await sendAndWait(`exit HAI for ${ownerAddress}`, coinJoin.connect(ownerSigner).exit(ownerAddress, plan.debtWad));

  return {
    owner: ownerAddress,
    collateralToken,
    multiplier: multiplier.toString(),
    collateralWei: plan.collateralWei,
    collateralWad: plan.collateralWad,
    debtWad: plan.debtWad,
    maxDebtWad: plan.maxDebtWad,
  };
}

async function main() {
  const rpcUrl = process.env.TENDERLY_ADMIN_RPC_URL || requiredEnv('TENDERLY_RPC_URL');
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();

  const poolHaiDeposit = parseAmountEnv('POOL_HAI_DEPOSIT', DEFAULT_POOL_HAI_DEPOSIT);
  const emissionsTotalKite = parseAmountEnv('EMISSIONS_TOTAL_KITE', DEFAULT_EMISSIONS_TOTAL_KITE);
  const emissionDurationSeconds = parseIntegerEnv('EMISSIONS_DURATION_SECONDS', DEFAULT_EMISSIONS_DURATION_SECONDS);
  const auctionsPerCollateral = parseIntegerEnv('AUCTIONS_PER_COLLATERAL', DEFAULT_AUCTIONS_PER_COLLATERAL);
  const maxQuoteSteps = parseIntegerEnv('VELO_CL_MAX_QUOTE_STEPS', DEFAULT_MAX_QUOTE_STEPS);
  const auctionAgeSeconds = parseIntegerEnv('AUCTION_AGE_SECONDS', DEFAULT_AUCTION_AGE_SECONDS);
  const stepSlippageBps = parseIntegerEnv('STEP_SLIPPAGE_BPS', DEFAULT_STEP_SLIPPAGE_BPS);
  const restoreOraclesAfter = parseBooleanEnv('RESTORE_ORACLES_AFTER', false);
  const verifyDeployedContracts = parseBooleanEnv('VERIFY_DEPLOYED_CONTRACTS', true);
  const cTypeAllowlist = parseAllowlistEnv('COLLATERAL_ALLOWLIST');
  const manifestPath = process.env.MANIFEST_PATH || DEFAULT_MANIFEST_PATH;

  const artifacts = {
    ProtocolToken: await loadArtifact('out/ProtocolToken.sol/ProtocolToken.json'),
    SystemCoin: await loadArtifact('out/SystemCoin.sol/SystemCoin.json'),
    SAFEEngine: await loadArtifact('out/SAFEEngine.sol/SAFEEngine.json'),
    CoinJoin: await loadArtifact('out/CoinJoin.sol/CoinJoin.json'),
    OracleRelayer: await loadArtifact('out/OracleRelayer.sol/OracleRelayer.json'),
    LiquidationEngine: await loadArtifact('out/LiquidationEngine.sol/LiquidationEngine.json'),
    CollateralJoinFactory: await loadArtifact('out/CollateralJoinFactory.sol/CollateralJoinFactory.json'),
    CollateralJoin: await loadArtifact('out/CollateralJoin.sol/CollateralJoin.json'),
    CollateralAuctionHouseFactory: await loadArtifact(
      'out/CollateralAuctionHouseFactory.sol/CollateralAuctionHouseFactory.json'
    ),
    ICollateralAuctionHouse: await loadArtifact('out/ICollateralAuctionHouse.sol/ICollateralAuctionHouse.json'),
    IBaseOracle: await loadArtifact('out/IBaseOracle.sol/IBaseOracle.json'),
    EmissionsController: await loadArtifact('out/EmissionsController.sol/EmissionsController.json'),
    StabilityPool: await loadArtifact([
      'out-via-ir/StabilityPool.sol/StabilityPool.json',
      'out/StabilityPool.sol/StabilityPool.json',
    ]),
    HardcodedOracle: await loadArtifact('out/HardcodedOracle.sol/HardcodedOracle.json'),
  };

  console.log(`connected to chain ${network.chainId.toString()}`);

  const roles = {
    deployer: deterministicAddress(1),
    staker: deterministicAddress(2),
    safeOwners: [],
  };

  const deployerSigner = new UnlockedSigner(provider, roles.deployer);
  const stakerSigner = new UnlockedSigner(provider, roles.staker);
  const timelockSigner = new UnlockedSigner(provider, MAINNET_DEPLOYMENT.timelock);

  const systemCoin = contractAt(MAINNET_DEPLOYMENT.systemCoin, artifacts.SystemCoin, provider);
  const protocolToken = contractAt(MAINNET_DEPLOYMENT.protocolToken, artifacts.ProtocolToken, provider);
  const safeEngine = contractAt(MAINNET_DEPLOYMENT.safeEngine, artifacts.SAFEEngine, provider);
  const coinJoin = contractAt(MAINNET_DEPLOYMENT.coinJoin, artifacts.CoinJoin, provider);
  const oracleRelayer = contractAt(MAINNET_DEPLOYMENT.oracleRelayer, artifacts.OracleRelayer, provider);
  const liquidationEngine = contractAt(MAINNET_DEPLOYMENT.liquidationEngine, artifacts.LiquidationEngine, provider);
  const collateralJoinFactory = contractAt(
    MAINNET_DEPLOYMENT.collateralJoinFactory,
    artifacts.CollateralJoinFactory,
    provider
  );
  const collateralAuctionHouseFactory = contractAt(
    MAINNET_DEPLOYMENT.collateralAuctionHouseFactory,
    artifacts.CollateralAuctionHouseFactory,
    provider
  );

  const discoveredCTypeBytes32 = await collateralJoinFactory.collateralTypesList();
  const discoveredCTypeNames = discoveredCTypeBytes32.map(stringFromBytes32);
  const pipelineTemplateNames = Object.keys(DEFAULT_TARGET_DEBT_WAD);
  const unsupportedCTypeNames = discoveredCTypeNames.filter(name => !pipelineTemplateNames.includes(name));
  if (!cTypeAllowlist && unsupportedCTypeNames.length > 0) {
    throw new Error(`Unsupported collateral types discovered: ${unsupportedCTypeNames.join(', ')}`);
  }

  let targetCTypeNames = discoveredCTypeNames;
  if (cTypeAllowlist) {
    targetCTypeNames = discoveredCTypeNames.filter(name => cTypeAllowlist.has(name));
  }

  const targetCTypeBytes32 = targetCTypeNames.map(bytes32FromCType);
  if (targetCTypeNames.length === 0) {
    throw new Error('No collateral types selected for bootstrap');
  }

  const balanceRecipients = [roles.deployer, roles.staker, MAINNET_DEPLOYMENT.timelock];
  await topUpEth(provider, balanceRecipients, ETH_TOP_UP);

  if (await protocolToken.paused()) {
    await sendAndWait('unpause KITE on fork', protocolToken.connect(timelockSigner).unpause());
  }

  const timelockAuthorized = await oracleRelayer
    .getFunction('authorizedAccounts(address)')
    .staticCall(MAINNET_DEPLOYMENT.timelock);
  if (!timelockAuthorized) {
    throw new Error('Timelock is not authorized on OracleRelayer');
  }

  const deployedStepContracts = {};
  for (const stepArtifact of STRATEGY_STEP_ARTIFACTS) {
    const artifact = await loadArtifact(stepArtifact.artifactPath);
    const constructorArgs = stepArtifact.constructorArgs.map(value =>
      value === '__VELO_CL_MAX_QUOTE_STEPS__' ? maxQuoteSteps : value
    );
    const contract = await deployContract(stepArtifact.contractName, artifact, deployerSigner, constructorArgs);
    deployedStepContracts[stepArtifact.key] = await contract.getAddress();
  }

  const emissionsController = await deployContract(
    'EmissionsController',
    artifacts.EmissionsController,
    deployerSigner,
    [
      MAINNET_DEPLOYMENT.protocolToken,
      MAINNET_DEPLOYMENT.oracleRelayer,
      roles.deployer,
      emissionsTotalKite,
      emissionDurationSeconds,
      DEFAULT_DEVIATION_LIMIT,
    ]
  );

  const stabilityPool = await deployContract('StabilityPool', artifacts.StabilityPool, deployerSigner, [
    MAINNET_DEPLOYMENT.systemCoin,
    MAINNET_DEPLOYMENT.protocolToken,
    MAINNET_DEPLOYMENT.oracleRelayer,
    await emissionsController.getAddress(),
    MAINNET_DEPLOYMENT.coinJoin,
    MAINNET_DEPLOYMENT.collateralJoinFactory,
    MAINNET_DEPLOYMENT.collateralAuctionHouseFactory,
  ]);

  const stabilityPoolAddress = await stabilityPool.getAddress();
  const emissionsControllerAddress = await emissionsController.getAddress();

  await sendAndWait(
    'set StabilityPool as emissions receiver',
    emissionsController.connect(deployerSigner).setStabilityRewardsReceiver(stabilityPoolAddress)
  );

  for (const stepAddress of Object.values(deployedStepContracts)) {
    await sendAndWait(
      `whitelist strategy step ${stepAddress}`,
      stabilityPool.connect(deployerSigner).setStepWhitelist(stepAddress, true)
    );
  }

  const pipelineConfigs = buildPipelineConfigs(deployedStepContracts, stepSlippageBps);
  for (const cTypeName of targetCTypeNames) {
    const configs = pipelineConfigs[cTypeName];
    if (!configs) {
      throw new Error(`Missing pipeline configuration for ${cTypeName}`);
    }

    await sendAndWait(
      `configure strategy steps for ${cTypeName}`,
      stabilityPool.connect(deployerSigner).setStrategySteps(bytes32FromCType(cTypeName), configs)
    );
  }

  await setTokenBalance(
    provider,
    MAINNET_DEPLOYMENT.protocolToken,
    emissionsControllerAddress,
    emissionsTotalKite,
    false
  );
  await setTokenBalance(provider, MAINNET_DEPLOYMENT.systemCoin, roles.staker, poolHaiDeposit, false);

  const stakerCoin = contractAt(
    MAINNET_DEPLOYMENT.systemCoin,
    { abi: ['function approve(address spender, uint256 value) external returns (bool)'] },
    stakerSigner
  );

  await sendAndWait(
    'approve HAI for StabilityPool seed deposit',
    stakerCoin.approve(stabilityPoolAddress, ethers.MaxUint256)
  );
  await sendAndWait(
    'seed StabilityPool with HAI',
    stabilityPool.connect(stakerSigner).deposit(poolHaiDeposit, roles.staker)
  );

  const originalOracleState = new Map();
  const stagedCollateralData = [];

  let safeOwnerSeed = 1000;
  for (let index = 0; index < targetCTypeNames.length; index += 1) {
    const cTypeName = targetCTypeNames[index];
    const cTypeBytes32 = targetCTypeBytes32[index];
    const collateralJoinAddress = await collateralJoinFactory.collateralJoins(cTypeBytes32);
    const collateralAuctionHouseAddress = await collateralAuctionHouseFactory.collateralAuctionHouses(cTypeBytes32);

    if (collateralJoinAddress === ethers.ZeroAddress || collateralAuctionHouseAddress === ethers.ZeroAddress) {
      throw new Error(`Missing join or auction house for ${cTypeName}`);
    }

    const collateralJoin = contractAt(collateralJoinAddress, artifacts.CollateralJoin, provider);
    const collateralAuctionHouse = contractAt(
      collateralAuctionHouseAddress,
      artifacts.ICollateralAuctionHouse,
      provider
    );
    const oracleParams = await oracleRelayer.cParams(cTypeBytes32);
    const originalOracleAddress = oracleParams.oracle;
    const originalOraclePrice = await getOraclePrice(provider, artifacts, originalOracleAddress);

    originalOracleState.set(cTypeName, { address: originalOracleAddress, price: originalOraclePrice });

    const targetDebtWad = DEFAULT_TARGET_DEBT_WAD[cTypeName];
    const allowDynamicBalanceFallback = DYNAMIC_BALANCE_FALLBACK_CTYPE_NAMES.has(cTypeName);

    const stagedSafes = [];
    for (let auctionIndex = 0; auctionIndex < auctionsPerCollateral; auctionIndex += 1) {
      const ownerAddress = deterministicAddress(safeOwnerSeed++);
      const ownerSigner = new UnlockedSigner(provider, ownerAddress);
      roles.safeOwners.push(ownerAddress);
      await topUpEth(provider, ownerAddress, ETH_TOP_UP);

      const stagedSafe = await stageSafe({
        artifacts,
        allowDynamicBalanceFallback,
        cTypeBytes32,
        cTypeName,
        coinJoin,
        collateralJoin,
        collateralJoinAddress,
        ownerAddress,
        ownerSigner,
        provider,
        safeEngine,
        targetDebtWad,
      });
      stagedSafes.push(stagedSafe);
    }

    const divisor = PROFITABILITY_PRICE_DIVISORS[PROFITABILITY_PRICE_DIVISORS.length - 1];
    const initialOraclePrice = originalOraclePrice > 0n ? originalOraclePrice / divisor : 1n;
    const hardcodedOracle = await deployContract(
      `HardcodedOracle_${cTypeName}`,
      artifacts.HardcodedOracle,
      deployerSigner,
      [`${cTypeName} / USD`, initialOraclePrice > 0n ? initialOraclePrice : 1n]
    );
    const hardcodedOracleAddress = await hardcodedOracle.getAddress();

    await sendAndWait(
      `replace oracle for ${cTypeName}`,
      oracleRelayer
        .connect(timelockSigner)
        .getFunction('modifyParameters(bytes32,bytes32,bytes)')
        .send(
          cTypeBytes32,
          PARAM_ORACLE,
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [hardcodedOracleAddress])
        )
    );
    await sendAndWait(
      `update collateral price for ${cTypeName}`,
      oracleRelayer.connect(deployerSigner).updateCollateralPrice(cTypeBytes32)
    );

    const auctions = [];
    for (const stagedSafe of stagedSafes) {
      const tx = await liquidationEngine.connect(deployerSigner).liquidateSAFE(cTypeBytes32, stagedSafe.owner);
      const receipt = await tx.wait();
      if (!receipt || Number(receipt.status) !== 1) {
        throw new Error(`Failed to liquidate ${cTypeName} SAFE for ${stagedSafe.owner}`);
      }

      const latestAuctionId = await collateralAuctionHouse.auctionsStarted();
      auctions.push({
        owner: stagedSafe.owner,
        auctionId: latestAuctionId,
      });
    }

    stagedCollateralData.push({
      cTypeName,
      cTypeBytes32,
      collateralJoinAddress,
      collateralAuctionHouseAddress,
      stagedSafes,
      auctions,
      oracle: {
        original: originalOracleAddress,
        staged: hardcodedOracleAddress,
        originalPrice: originalOraclePrice,
        stagedPrice: initialOraclePrice > 0n ? initialOraclePrice : 1n,
        divisor,
      },
    });
  }

  await warpTime(provider, auctionAgeSeconds);

  const minProfitBps = await stabilityPool.minProfitBps();
  for (const collateralData of stagedCollateralData) {
    const collateralJoin = contractAt(collateralData.collateralJoinAddress, artifacts.CollateralJoin, provider);
    const auctionHouse = contractAt(
      collateralData.collateralAuctionHouseAddress,
      artifacts.ICollateralAuctionHouse,
      provider
    );
    const multiplier = BigInt(await collateralJoin.multiplier());
    const originalOracle = originalOracleState.get(collateralData.cTypeName);
    let suggestedBids = [];
    let activeOracleAddress = collateralData.oracle.staged;
    let activeOraclePrice = collateralData.oracle.stagedPrice;

    const startDivisorIndex = PROFITABILITY_PRICE_DIVISORS.findIndex(
      value => value === collateralData.oracle.divisor
    );
    const divisorsToTry = PROFITABILITY_PRICE_DIVISORS.slice(startDivisorIndex === -1 ? 0 : startDivisorIndex);

    for (const divisor of divisorsToTry) {
      const targetPrice = originalOracle.price > 0n ? originalOracle.price / divisor : 1n;
      const candidatePrice = targetPrice > 0n ? targetPrice : 1n;

      if (candidatePrice !== activeOraclePrice) {
        const oracle = await deployContract(
          `HardcodedOracle_${collateralData.cTypeName}_${divisor.toString()}`,
          artifacts.HardcodedOracle,
          deployerSigner,
          [`${collateralData.cTypeName} / USD`, candidatePrice]
        );
        activeOracleAddress = await oracle.getAddress();
        activeOraclePrice = candidatePrice;

        await sendAndWait(
          `ratchet oracle for ${collateralData.cTypeName}`,
          oracleRelayer
            .connect(timelockSigner)
            .getFunction('modifyParameters(bytes32,bytes32,bytes)')
            .send(
              collateralData.cTypeBytes32,
              PARAM_ORACLE,
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [activeOracleAddress])
            )
        );
        await sendAndWait(
          `refresh collateral price for ${collateralData.cTypeName}`,
          oracleRelayer.connect(deployerSigner).updateCollateralPrice(collateralData.cTypeBytes32)
        );
      }

      const maybeBids = [];
      let allAuctionsProfitable = true;
      for (const auctionData of collateralData.auctions) {
        const suggestion = await findProfitableBid({
          artifacts,
          auction: auctionHouse,
          auctionId: auctionData.auctionId,
          cTypeBytes32: collateralData.cTypeBytes32,
          multiplier,
          minProfitBps,
          stabilityPool,
          systemCoin,
          stabilityPoolAddress,
        });

        if (!suggestion) {
          allAuctionsProfitable = false;
          break;
        }

        maybeBids.push({
          auctionId: auctionData.auctionId.toString(),
          owner: auctionData.owner,
          bidAmount: suggestion.bidAmount,
          adjustedBid: suggestion.adjustedBid,
          expectedHai: suggestion.expectedHai,
          estimatedCollateralBought: suggestion.estimatedCollateralBought,
          estimatedCollateralWei: suggestion.estimatedCollateralWei,
        });
      }

      if (allAuctionsProfitable) {
        suggestedBids = maybeBids;
        collateralData.oracle.staged = activeOracleAddress;
        collateralData.oracle.stagedPrice = activeOraclePrice;
        collateralData.oracle.divisor = divisor;
        break;
      }
    }

    if (suggestedBids.length !== collateralData.auctions.length) {
      throw new Error(`Unable to stage profitable auctions for ${collateralData.cTypeName}`);
    }

    collateralData.suggestedBids = suggestedBids;
  }

  if (restoreOraclesAfter) {
    for (const collateralData of stagedCollateralData) {
      const originalOracle = originalOracleState.get(collateralData.cTypeName);
      await sendAndWait(
        `restore oracle for ${collateralData.cTypeName}`,
        oracleRelayer
          .connect(timelockSigner)
          .getFunction('modifyParameters(bytes32,bytes32,bytes)')
          .send(
            collateralData.cTypeBytes32,
            PARAM_ORACLE,
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [originalOracle.address])
          )
      );
      await sendAndWait(
        `restore collateral price for ${collateralData.cTypeName}`,
        oracleRelayer.connect(deployerSigner).updateCollateralPrice(collateralData.cTypeBytes32)
      );
    }
  }

  await mkdir(path.dirname(manifestPath), { recursive: true });

  const manifest = {
    chainId: network.chainId,
    rpcUrl,
    generatedAt: new Date().toISOString(),
    restoreOraclesAfter,
    config: {
      poolHaiDeposit,
      emissionsTotalKite,
      emissionDurationSeconds,
      defaultDeviationLimit: DEFAULT_DEVIATION_LIMIT,
      auctionsPerCollateral,
      auctionAgeSeconds,
      stepSlippageBps,
      maxQuoteSteps,
      cTypeAllowlist: cTypeAllowlist ? Array.from(cTypeAllowlist.values()) : null,
    },
    roles,
    mainnetDeployment: MAINNET_DEPLOYMENT,
    deployedContracts: {
      emissionsController: emissionsControllerAddress,
      stabilityPool: stabilityPoolAddress,
      strategySteps: deployedStepContracts,
    },
    collaterals: stagedCollateralData,
  };

  await writeFile(manifestPath, serialize(manifest));

  console.log(`wrote manifest to ${manifestPath}`);

  if (verifyDeployedContracts) {
    console.log(`verify deployed contracts from ${manifestPath}`);

    const verification = spawnSync(process.execPath, [VERIFY_MANIFEST_SCRIPT_PATH], {
      cwd: ROOT_DIR,
      env: {
        ...process.env,
        MANIFEST_PATH: manifestPath,
        TENDERLY_RPC_URL: rpcUrl,
      },
      stdio: 'inherit',
    });

    if (verification.status !== 0) {
      throw new Error(`Tenderly verification failed for manifest ${manifestPath}`);
    }
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});

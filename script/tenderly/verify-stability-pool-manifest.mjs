import {spawnSync} from 'child_process';
import {readFile} from 'fs/promises';
import path from 'path';
import {fileURLToPath} from 'url';

import {ethers} from 'ethers';

import {ORACLE_ADDRESSES, POOL_ADDRESSES, TOKEN_ADDRESSES} from './stability-pool-config.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '../..');

const DEFAULT_DEVIATION_LIMIT = ethers.parseUnits('0.1', 18);
const DEFAULT_MANIFEST_PATH = path.join(ROOT_DIR, 'script', 'tenderly', 'bootstrap-stability-pool.manifest.json');
const TENDERLY_VERIFY_SUFFIX = '/verify';

function required(value, label) {
  if (!value) {
    throw new Error(`Missing required ${label}`);
  }
  return value;
}

function buildVerificationJobs(manifest) {
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  const deviationLimit = manifest.config.defaultDeviationLimit ?? DEFAULT_DEVIATION_LIMIT.toString();

  return [
    {
      name: 'EmissionsController',
      address: manifest.deployedContracts.emissionsController,
      contract: 'src/contracts/stability-pool/EmissionsController.sol:EmissionsController',
      constructorArgs: abiCoder.encode(
        ['address', 'address', 'address', 'uint256', 'uint256', 'uint256'],
        [
          manifest.mainnetDeployment.protocolToken,
          manifest.mainnetDeployment.oracleRelayer,
          manifest.roles.deployer,
          manifest.config.emissionsTotalKite,
          manifest.config.emissionDurationSeconds,
          deviationLimit,
        ]
      ),
    },
    {
      name: 'StabilityPool',
      address: manifest.deployedContracts.stabilityPool,
      contract: 'src/contracts/stability-pool/StabilityPool.sol:StabilityPool',
      constructorArgs: abiCoder.encode(
        ['address', 'address', 'address', 'address', 'address', 'address', 'address'],
        [
          manifest.mainnetDeployment.systemCoin,
          manifest.mainnetDeployment.protocolToken,
          manifest.mainnetDeployment.oracleRelayer,
          manifest.deployedContracts.emissionsController,
          manifest.mainnetDeployment.coinJoin,
          manifest.mainnetDeployment.collateralJoinFactory,
          manifest.mainnetDeployment.collateralAuctionHouseFactory,
        ]
      ),
      foundryProfile: 'optimized',
    },
    {
      name: 'BalancerV3StablePoolMathSwapStep',
      address: manifest.deployedContracts.strategySteps.balancerV3Step,
      contract:
        'src/contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol:' +
        'BalancerV3StablePoolMathSwapStep',
    },
    {
      name: 'ERC4626WithdrawalStep',
      address: manifest.deployedContracts.strategySteps.erc4626Step,
      contract: 'src/contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol:ERC4626WithdrawalStep',
    },
    {
      name: 'CurveSwapStep',
      address: manifest.deployedContracts.strategySteps.curveStep,
      contract: 'src/contracts/stability-pool/strategy-steps/CurveSwapStep.sol:CurveSwapStep',
    },
    {
      name: 'VeloSwapStep',
      address: manifest.deployedContracts.strategySteps.veloSwapStep,
      contract: 'src/contracts/stability-pool/strategy-steps/VeloSwapStep.sol:VeloSwapStep',
    },
    {
      name: 'VeloCLSwapStepViewQuoter',
      address: manifest.deployedContracts.strategySteps.veloCLStep,
      contract: 'src/contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol:VeloCLSwapStepViewQuoter',
      constructorArgs: abiCoder.encode(['uint256'], [manifest.config.maxQuoteSteps]),
    },
    {
      name: 'VeloLPRemovalStep',
      address: manifest.deployedContracts.strategySteps.veloLPRemovalStep,
      contract: 'src/contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol:VeloLPRemovalStep',
    },
    {
      name: 'VeloLPRemoveAndSwapStep',
      address: manifest.deployedContracts.strategySteps.veloLPRemoveAndSwapStep,
      contract:
        'src/contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol:VeloLPRemoveAndSwapStep',
    },
    {
      name: 'BeefyVaultWithdrawalStep',
      address: manifest.deployedContracts.strategySteps.beefyStep,
      contract: 'src/contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol:BeefyVaultWithdrawalStep',
    },
    {
      name: 'YearnVaultWithdrawalStep',
      address: manifest.deployedContracts.strategySteps.yearnStep,
      contract: 'src/contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol:YearnVaultWithdrawalStep',
    },
    {
      name: 'CurveStableSwapNGRelayer_BOLD_HAI',
      address: manifest.deployedContracts.oracles.boldHaiOracle,
      contract: 'src/contracts/oracles/CurveStableSwapNGRelayer.sol:CurveStableSwapNGRelayer',
      constructorArgs: abiCoder.encode(['address', 'uint256', 'uint256'], [POOL_ADDRESSES.CURVE_BOLD_HAI, 0, 1]),
    },
    {
      name: 'DenominatedOracle_BOLD_USD',
      address: manifest.deployedContracts.oracles.boldUsdOracle,
      contract: 'src/contracts/oracles/DenominatedOracle.sol:DenominatedOracle',
      constructorArgs: abiCoder.encode(
        ['address', 'address', 'bool'],
        [manifest.deployedContracts.oracles.boldHaiOracle, ORACLE_ADDRESSES.HAI_USD, true]
      ),
    },
    {
      name: 'ERC4626ShareOracle_waOptWETH',
      address: manifest.deployedContracts.oracles.waOptWethUsdOracle,
      contract: 'src/contracts/oracles/ERC4626ShareOracle.sol:ERC4626ShareOracle',
      constructorArgs: abiCoder.encode(
        ['address', 'address', 'string'],
        [TOKEN_ADDRESSES.WA_OPT_WETH, ORACLE_ADDRESSES.WETH_USD, 'waOptWETH / USD']
      ),
    },
    ...manifest.collaterals.map(collateral => ({
      name: `HardcodedOracle_${collateral.cTypeName}`,
      address: collateral.oracle.staged,
      contract: 'src/contracts/for-test/HardcodedOracle.sol:HardcodedOracle',
      constructorArgs: abiCoder.encode(['string', 'uint256'], [`${collateral.cTypeName} / USD`, collateral.oracle.stagedPrice]),
    })),
  ];
}

function verifyContract(job, rpcUrl, chainId) {
  const args = [
    'verify-contract',
    job.address,
    job.contract,
    '--verifier',
    'custom',
    '--verifier-url',
    `${rpcUrl}${TENDERLY_VERIFY_SUFFIX}`,
    '--chain',
    chainId,
    '--rpc-url',
    rpcUrl,
    '--watch',
    '-q',
  ];

  if (job.constructorArgs) {
    args.push('--constructor-args', job.constructorArgs);
  }

  const env = {...process.env};
  if (job.foundryProfile) {
    env.FOUNDRY_PROFILE = job.foundryProfile;
  }

  const result = spawnSync('forge', args, {
    cwd: ROOT_DIR,
    env,
    stdio: 'inherit',
  });

  if (result.status !== 0) {
    throw new Error(`Verification failed for ${job.name} at ${job.address}`);
  }
}

async function main() {
  const manifestPath = path.resolve(process.env.MANIFEST_PATH || DEFAULT_MANIFEST_PATH);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const rpcUrl = required(process.env.TENDERLY_RPC_URL || manifest.rpcUrl, 'Tenderly RPC URL');
  const chainId = required(String(manifest.chainId), 'manifest chain ID');

  const jobs = buildVerificationJobs(manifest);
  console.log(`verifying ${jobs.length} Tenderly contracts from ${manifestPath}`);

  for (const [index, job] of jobs.entries()) {
    console.log(`[${index + 1}/${jobs.length}] verify ${job.name} ${job.address}`);
    verifyContract(job, rpcUrl, chainId);
  }

  console.log(`verified ${jobs.length} contracts from ${manifestPath}`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});

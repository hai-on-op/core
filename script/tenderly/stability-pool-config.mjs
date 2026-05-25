import { ethers } from 'ethers';

export const WAD = 10n ** 18n;
export const RAY = 10n ** 27n;

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

export const MAINNET_DEPLOYMENT = {
  timelock: '0xd68e7D20008a223dD48A6076AAf5EDd4fe80a899',
  systemCoin: '0x10398AbC267496E49106B07dd6BE13364D10dC71',
  protocolToken: '0xf467C7d5a4A9C4687fFc7986aC6aD5A4c81E1404',
  safeEngine: '0x9Ff826860689483181C5FAc9628fd2F70275A700',
  oracleRelayer: '0x6270403b908505F02Da05BE5c1956aBB59FDb3A6',
  liquidationEngine: '0x8Be588895BE9B75F9a9dAee185e0c2ad89891b56',
  coinJoin: '0x30Ce72230A47A0967B7e52A1bAE0178DbD7c6eA3',
  collateralJoinFactory: '0xfE7987b1Ee45a8d592B15e8E924d50BFC8536143',
  collateralAuctionHouseFactory: '0x81c5C2DA8C1a74c6077B03aD69ca04b74b94B427',
};

export const STRATEGY_STEP_ARTIFACTS = [
  {
    key: 'balancerV3Step',
    contractName: 'BalancerV3StablePoolMathSwapStep',
    artifactPath: 'out/BalancerV3StablePoolMathSwapStep.sol/BalancerV3StablePoolMathSwapStep.json',
    constructorArgs: [],
  },
  {
    key: 'erc4626Step',
    contractName: 'ERC4626WithdrawalStep',
    artifactPath: 'out/ERC4626WithdrawalStep.sol/ERC4626WithdrawalStep.json',
    constructorArgs: [],
  },
  {
    key: 'curveStep',
    contractName: 'CurveSwapStep',
    artifactPath: 'out/CurveSwapStep.sol/CurveSwapStep.json',
    constructorArgs: [],
  },
  {
    key: 'veloSwapStep',
    contractName: 'VeloSwapStep',
    artifactPath: 'out/VeloSwapStep.sol/VeloSwapStep.json',
    constructorArgs: [],
  },
  {
    key: 'veloCLStep',
    contractName: 'VeloCLSwapStepViewQuoter',
    artifactPath: 'out/VeloCLSwapStepViewQuoter.sol/VeloCLSwapStepViewQuoter.json',
    constructorArgs: ['__VELO_CL_MAX_QUOTE_STEPS__'],
  },
  {
    key: 'veloLPRemovalStep',
    contractName: 'VeloLPRemovalStep',
    artifactPath: 'out/VeloLPRemovalStep.sol/VeloLPRemovalStep.json',
    constructorArgs: [],
  },
  {
    key: 'veloLPRemoveAndSwapStep',
    contractName: 'VeloLPRemoveAndSwapStep',
    artifactPath: 'out/VeloLPRemoveAndSwapStep.sol/VeloLPRemoveAndSwapStep.json',
    constructorArgs: [],
  },
  {
    key: 'beefyStep',
    contractName: 'BeefyVaultWithdrawalStep',
    artifactPath: 'out/BeefyVaultWithdrawalStep.sol/BeefyVaultWithdrawalStep.json',
    constructorArgs: [],
  },
  {
    key: 'yearnStep',
    contractName: 'YearnVaultWithdrawalStep',
    artifactPath: 'out/YearnVaultWithdrawalStep.sol/YearnVaultWithdrawalStep.json',
    constructorArgs: [],
  },
];

export const ORACLE_ARTIFACTS = [
  {
    key: 'boldHaiOracle',
    contractName: 'CurveStableSwapNGRelayer',
    artifactPath: 'out/CurveStableSwapNGRelayer.sol/CurveStableSwapNGRelayer.json',
    constructorArgs: ['__CURVE_BOLD_HAI_POOL__', 0, 1],
  },
  {
    key: 'boldUsdOracle',
    contractName: 'DenominatedOracle',
    artifactPath: 'out/DenominatedOracle.sol/DenominatedOracle.json',
    constructorArgs: ['__BOLD_HAI_ORACLE__', '__HAI_USD_ORACLE__', true],
  },
  {
    key: 'waOptWethUsdOracle',
    contractName: 'ERC4626ShareOracle',
    artifactPath: 'out/ERC4626ShareOracle.sol/ERC4626ShareOracle.json',
    constructorArgs: ['__WA_OPT_WETH__', '__WETH_USD_ORACLE__', 'waOptWETH / USD'],
  },
];

export const TOKEN_ADDRESSES = {
  WETH: '0x4200000000000000000000000000000000000006',
  WSTETH: '0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb',
  USDC: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85',
  BOLD: '0x03569CC076654F82679C4BA2124D64774781B01D',
  HAI: '0x10398AbC267496E49106B07dd6BE13364D10dC71',
  ALETH: '0x3E29D3A9316dAB217754d13b28646B76607c5f04',
  RETH: '0x9Bcef72be871e61ED4fBbc7630889beE758eb81D',
  WA_OPT_WETH: '0x464b808c2C7E04b07e860fDF7a91870620246148',
  HAIVELO: '0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6',
  VELO: '0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db',
  TBTC: '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40',
  WBTC: '0x68f180fcCe6836688e9084f035309E29Bf0A2095',
  MSETH: '0x1610e3c85dd44Af31eD7f33a63642012Dca0C5A5',
  OP: '0x4200000000000000000000000000000000000042',
  LUSD: '0xc40F949F8a4e094D1b49a23ea9241D289B7b2819',
};

export const POOL_ADDRESSES = {
  CURVE_BOLD_HAI: '0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5',
  BALANCER_V3_RETH_WA_OPT_WETH: '0x870c0Af8A1af0B58b4b0bD31CE4fe72864ae45BE',
  VELO_HAIVELO_VELO: '0x5535Cdc333FC8f08f6183e7064202C3917E9346C',
  VELO_USDC_VELO: '0xa0A215dE234276CAc1b844fD58901351a50fec8A',
  WETH_USDC_VELO_CL: '0x478946BcD4a5a22b316470F5486fAfb928C0bA25',
  WSTETH_WETH_VELO_CL: '0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4',
  TBTC_WBTC_VELO_CL: '0x8949A8E02998d76D7a703cAC9eE7e0f529828011',
  WBTC_USDC_VELO_CL: '0xCF50DEA65EE80eBDDAA61005a960ef5A5c995A99',
  MSETH_WETH_VELO: '0x917AA69D539D6518440dd0BEA2eaAc142a8d5610',
  OP_WETH_VELO_CL: '0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60',
  BOLD_LUSD_VELO: '0xf2034BF7922620b721183a894a3449bad7Ee97b3',
  ALETH_WETH_VELO: '0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a',
};

export const EXTERNAL_ADDRESSES = {
  veloClRouter: '0x0792a633F0c19c351081CF4B211F68F79bCc9676',
  veloRouter: '0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858',
  veloFactory: '0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a',
  balancerV3Router: '0x84813aA3e079A665C0B80F944427eE83cBA63617',
  beefyBoldLusdVault: '0xC06C0A19d0A3eD7B3BA9D7c3101B6BC9634b84a9',
  yearnAlethWethVault: '0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3',
  yearnMsethWethVault: '0xd0d2Ac44Cc842079e978bB11b094764f7D0dec6A',
};

export const ORACLE_ADDRESSES = {
  HAI_USD: '0x8c212bCaE328669c8b045D467CB78b88e0BE0D39',
  RETH_USD: '0xB43314DBdb9b8036E7012A3cDc267E2105Ee8740',
  WETH_USD: '0x2fC0cb2c5065a79bC2db79e4fbD537b7CaCF6f36',
};

export const DEFAULT_STEP_SLIPPAGE_BPS = 200;
export const BALANCER_ORACLE_TOLERANCE_BPS = 200;
export const CURVE_ORACLE_TOLERANCE_BPS = 200;

export const DEFAULT_TARGET_DEBT_WAD = {
  WETH: 500n * WAD,
  WSTETH: 500n * WAD,
  ALETH: 500n * WAD,
  RETH: 500n * WAD,
  HAIVELOV2: 250n * WAD,
  TBTC: 500n * WAD,
  MSETH: 500n * WAD,
  OP: 500n * WAD,
  'MOO-VELO-BOLD-LUSD': 200n * WAD,
  'YV-VELO-ALETH-WETH': 200n * WAD,
  'YV-VELO-MSETH-WETH': 200n * WAD,
};

export const PROFITABILITY_PRICE_DIVISORS = [20n, 50n, 100n, 200n, 500n, 1_000n, 5_000n];

function encodeTuple(type, value) {
  return abiCoder.encode([type], [value]);
}

function cfg(step, data, slippageBps) {
  return { step, data, slippageBps };
}

function encodeVeloClSwap(data) {
  return encodeTuple(
    'tuple(address router,address pool,address tokenIn,address tokenOut,' +
      'int24 tickSpacing,uint160 sqrtPriceLimitX96,uint256 deadlineBuffer)',
    data
  );
}

function encodeVeloSwap(data) {
  return encodeTuple(
    'tuple(address router,address factory,address tokenIn,address tokenOut,bool stable,uint256 deadlineBuffer)',
    data
  );
}

function encodeCurveSwap(data) {
  return encodeTuple(
    'tuple(address pool,int128 i,int128 j,address tokenIn,address tokenOut,' +
      'bool useOracleFloor,address tokenInOracle,address tokenOutOracle,uint16 oracleToleranceBps)',
    data
  );
}

function encodeBalancerV3Swap(data) {
  return encodeTuple(
    'tuple(address router,address pool,address tokenIn,address tokenOut,uint256 deadlineBuffer,bytes userData,' +
      'bool useOracleFloor,address tokenInOracle,address tokenOutOracle,uint16 oracleToleranceBps)',
    data
  );
}

function encodeERC4626Withdrawal(data) {
  return encodeTuple('tuple(address vault,address vaultToken,address assetToken)', data);
}

function encodeBeefyWithdrawal(data) {
  return encodeTuple('tuple(address vault,address vaultToken,address lpToken,uint256 shareScale)', data);
}

function encodeYearnWithdrawal(data) {
  return encodeTuple('tuple(address vault,address vaultToken,address lpToken,uint256 shareScale)', data);
}

function encodeVeloLpRemoveAndSwap(data) {
  return encodeTuple(
    'tuple(address router,address factory,address lpToken,address tokenA,address tokenB,' +
      'bool stableLp,bool stableSwap,uint256 deadlineBuffer)',
    data
  );
}

function buildShared(steps, slippageBps, oracleAddresses) {
  return {
    wethToUsdc: cfg(
      steps.veloCLStep,
      encodeVeloClSwap({
        router: EXTERNAL_ADDRESSES.veloClRouter,
        pool: POOL_ADDRESSES.WETH_USDC_VELO_CL,
        tokenIn: TOKEN_ADDRESSES.WETH,
        tokenOut: TOKEN_ADDRESSES.USDC,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 3600,
      }),
      slippageBps
    ),
    usdcToBold: cfg(
      steps.veloSwapStep,
      encodeVeloSwap({
        router: EXTERNAL_ADDRESSES.veloRouter,
        factory: EXTERNAL_ADDRESSES.veloFactory,
        tokenIn: TOKEN_ADDRESSES.USDC,
        tokenOut: TOKEN_ADDRESSES.BOLD,
        stable: true,
        deadlineBuffer: 3600,
      }),
      slippageBps
    ),
    boldToHai: cfg(
      steps.curveStep,
      encodeCurveSwap({
        pool: POOL_ADDRESSES.CURVE_BOLD_HAI,
        i: 1,
        j: 0,
        tokenIn: TOKEN_ADDRESSES.BOLD,
        tokenOut: TOKEN_ADDRESSES.HAI,
        useOracleFloor: true,
        tokenInOracle: oracleAddresses.BOLD_USD,
        tokenOutOracle: oracleAddresses.HAI_USD,
        oracleToleranceBps: CURVE_ORACLE_TOLERANCE_BPS,
      }),
      slippageBps
    ),
  };
}

export function bytes32FromCType(name) {
  return ethers.encodeBytes32String(name);
}

export function stringFromBytes32(value) {
  try {
    return ethers.decodeBytes32String(value);
  } catch {
    return value;
  }
}

export function buildPipelineConfigs(stepAddresses, slippageBps = DEFAULT_STEP_SLIPPAGE_BPS, oracleAddresses = {}) {
  const mergedOracleAddresses = { ...ORACLE_ADDRESSES, ...oracleAddresses };
  const shared = buildShared(stepAddresses, slippageBps, mergedOracleAddresses);

  const wethToUsdc = shared.wethToUsdc;
  const usdcToBold = shared.usdcToBold;
  const boldToHai = shared.boldToHai;

  return {
    WETH: [wethToUsdc, usdcToBold, boldToHai],
    WSTETH: [
      cfg(
        stepAddresses.veloCLStep,
        encodeVeloClSwap({
          router: EXTERNAL_ADDRESSES.veloClRouter,
          pool: POOL_ADDRESSES.WSTETH_WETH_VELO_CL,
          tokenIn: TOKEN_ADDRESSES.WSTETH,
          tokenOut: TOKEN_ADDRESSES.WETH,
          tickSpacing: 1,
          sqrtPriceLimitX96: 0,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    ALETH: [
      cfg(
        stepAddresses.veloSwapStep,
        encodeVeloSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          tokenIn: TOKEN_ADDRESSES.ALETH,
          tokenOut: TOKEN_ADDRESSES.WETH,
          stable: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    RETH: [
      cfg(
        stepAddresses.balancerV3Step,
        encodeBalancerV3Swap({
          router: EXTERNAL_ADDRESSES.balancerV3Router,
          pool: POOL_ADDRESSES.BALANCER_V3_RETH_WA_OPT_WETH,
          tokenIn: TOKEN_ADDRESSES.RETH,
          tokenOut: TOKEN_ADDRESSES.WA_OPT_WETH,
          deadlineBuffer: 3600,
          userData: '0x',
          useOracleFloor: true,
          tokenInOracle: mergedOracleAddresses.RETH_USD,
          tokenOutOracle: mergedOracleAddresses.WA_OPT_WETH_USD,
          oracleToleranceBps: BALANCER_ORACLE_TOLERANCE_BPS,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.erc4626Step,
        encodeERC4626Withdrawal({
          vault: TOKEN_ADDRESSES.WA_OPT_WETH,
          vaultToken: TOKEN_ADDRESSES.WA_OPT_WETH,
          assetToken: TOKEN_ADDRESSES.WETH,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    HAIVELOV2: [
      cfg(
        stepAddresses.veloSwapStep,
        encodeVeloSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          tokenIn: TOKEN_ADDRESSES.HAIVELO,
          tokenOut: TOKEN_ADDRESSES.VELO,
          stable: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.veloSwapStep,
        encodeVeloSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          tokenIn: TOKEN_ADDRESSES.VELO,
          tokenOut: TOKEN_ADDRESSES.USDC,
          stable: false,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      usdcToBold,
      boldToHai,
    ],
    TBTC: [
      cfg(
        stepAddresses.veloCLStep,
        encodeVeloClSwap({
          router: EXTERNAL_ADDRESSES.veloClRouter,
          pool: POOL_ADDRESSES.TBTC_WBTC_VELO_CL,
          tokenIn: TOKEN_ADDRESSES.TBTC,
          tokenOut: TOKEN_ADDRESSES.WBTC,
          tickSpacing: 1,
          sqrtPriceLimitX96: 0,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.veloCLStep,
        encodeVeloClSwap({
          router: EXTERNAL_ADDRESSES.veloClRouter,
          pool: POOL_ADDRESSES.WBTC_USDC_VELO_CL,
          tokenIn: TOKEN_ADDRESSES.WBTC,
          tokenOut: TOKEN_ADDRESSES.USDC,
          tickSpacing: 100,
          sqrtPriceLimitX96: 0,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      usdcToBold,
      boldToHai,
    ],
    MSETH: [
      cfg(
        stepAddresses.veloSwapStep,
        encodeVeloSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          tokenIn: TOKEN_ADDRESSES.MSETH,
          tokenOut: TOKEN_ADDRESSES.WETH,
          stable: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    OP: [
      cfg(
        stepAddresses.veloCLStep,
        encodeVeloClSwap({
          router: EXTERNAL_ADDRESSES.veloClRouter,
          pool: POOL_ADDRESSES.OP_WETH_VELO_CL,
          tokenIn: TOKEN_ADDRESSES.OP,
          tokenOut: TOKEN_ADDRESSES.WETH,
          tickSpacing: 200,
          sqrtPriceLimitX96: 0,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    'MOO-VELO-BOLD-LUSD': [
      cfg(
        stepAddresses.beefyStep,
        encodeBeefyWithdrawal({
          vault: EXTERNAL_ADDRESSES.beefyBoldLusdVault,
          vaultToken: EXTERNAL_ADDRESSES.beefyBoldLusdVault,
          lpToken: POOL_ADDRESSES.BOLD_LUSD_VELO,
          shareScale: WAD,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.veloLPRemoveAndSwapStep,
        encodeVeloLpRemoveAndSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          lpToken: POOL_ADDRESSES.BOLD_LUSD_VELO,
          tokenA: TOKEN_ADDRESSES.BOLD,
          tokenB: TOKEN_ADDRESSES.LUSD,
          stableLp: true,
          stableSwap: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      boldToHai,
    ],
    'YV-VELO-ALETH-WETH': [
      cfg(
        stepAddresses.yearnStep,
        encodeYearnWithdrawal({
          vault: EXTERNAL_ADDRESSES.yearnAlethWethVault,
          vaultToken: EXTERNAL_ADDRESSES.yearnAlethWethVault,
          lpToken: POOL_ADDRESSES.ALETH_WETH_VELO,
          shareScale: WAD,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.veloLPRemoveAndSwapStep,
        encodeVeloLpRemoveAndSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          lpToken: POOL_ADDRESSES.ALETH_WETH_VELO,
          tokenA: TOKEN_ADDRESSES.WETH,
          tokenB: TOKEN_ADDRESSES.ALETH,
          stableLp: true,
          stableSwap: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
    'YV-VELO-MSETH-WETH': [
      cfg(
        stepAddresses.yearnStep,
        encodeYearnWithdrawal({
          vault: EXTERNAL_ADDRESSES.yearnMsethWethVault,
          vaultToken: EXTERNAL_ADDRESSES.yearnMsethWethVault,
          lpToken: POOL_ADDRESSES.MSETH_WETH_VELO,
          shareScale: WAD,
        }),
        slippageBps
      ),
      cfg(
        stepAddresses.veloLPRemoveAndSwapStep,
        encodeVeloLpRemoveAndSwap({
          router: EXTERNAL_ADDRESSES.veloRouter,
          factory: EXTERNAL_ADDRESSES.veloFactory,
          lpToken: POOL_ADDRESSES.MSETH_WETH_VELO,
          tokenA: TOKEN_ADDRESSES.WETH,
          tokenB: TOKEN_ADDRESSES.MSETH,
          stableLp: true,
          stableSwap: true,
          deadlineBuffer: 3600,
        }),
        slippageBps
      ),
      wethToUsdc,
      usdcToBold,
      boldToHai,
    ],
  };
}

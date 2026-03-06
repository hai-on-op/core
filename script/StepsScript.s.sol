// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {Script, console} from 'forge-std/Script.sol';
import {Params, ParamChecker, WETH, OP, WSTETH} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import '@script/Registry.s.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {VeloLPRemovalStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';

/**
 * @title  MainnetScript
 * @notice This contract is used to deploy the system on Mainnet
 * @dev    This contract imports deployed addresses from `MainnetDeployment.s.sol`
 */
contract MainnetScript is MainnetDeployment, Common, Script {
  // --- STEP CONTRACT ADDRESSES ---

  address internal constant BALANCER_V3_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant ERC4626_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant CURVE_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant VELO_SWAP_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant VELO_CL_SWAP_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant VELO_LP_REMOVAL_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant VELO_LP_REMOVE_AND_SWAP_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant BEEFY_STEP = 0x0000000000000000000000000000000000000000;
  address internal constant YEARN_STEP = 0x0000000000000000000000000000000000000000;

  // --- CONTRACT ADDRESSES ---
  address internal constant VELO_CL_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
  address internal constant VELO_CL_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

  address internal constant BALANCER_V3_ROUTER = 0x84813aA3e079A665C0B80F944427eE83cBA63617;

  // --- TOKEN ADDRESSES ---
  address internal constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
  address internal constant WSTETH_ADDR = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
  address internal constant USDC_ADDR = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address internal constant BOLD_ADDR = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant HAI_ADDR = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant ALETH_ADDR = 0x3E29D3A9316dAB217754d13b28646B76607c5f04;
  address internal constant RETH_ADDR = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D;
  address internal constant WA_OPT_WETH_ADDR = 0x464b808c2C7E04b07e860fDF7a91870620246148;
  address internal constant HAIVELO_ADDR = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;
  address internal constant VELO_ADDR = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
  address internal constant TBTC_ADDR = 0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40;
  address internal constant WBTC_ADDR = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
  address internal constant MSETH_ADDR = 0x1610e3c85dd44Af31eD7f33a63642012Dca0C5A5;
  address internal constant OP_ADDR = 0x4200000000000000000000000000000000000042;
  address internal constant LUSD_ADDR = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;

  // --- POOL ADDRESSES ---
  address internal constant CURVE_BOLD_HAI_POOL = 0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5;
  address internal constant BALANCER_V3_RETH_WA_OPT_WETH_POOL = 0x870c0Af8A1af0B58b4b0bD31CE4fe72864ae45BE;
  address internal constant VELO_HAIVELO_VELO_POOL = 0x5535Cdc333FC8f08f6183e7064202C3917E9346C;
  address internal constant VELO_USDC_VELO_POOL = 0xa0A215dE234276CAc1b844fD58901351a50fec8A;
  address internal constant WETH_USDC_VELO_CL_POOL = 0x478946BcD4a5a22b316470F5486fAfb928C0bA25;
  address internal constant WSTETH_WETH_VELO_CL_POOL = 0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4;
  address internal constant TBTC_WBTC_VELO_POOL = 0x8949A8E02998d76D7a703cAC9eE7e0f529828011;
  address internal constant WBTC_USDC_VELO_POOL = 0xCF50DEA65EE80eBDDAA61005a960ef5A5c995A99;
  address internal constant MSETH_WETH_VELO_POOL = 0x917AA69D539D6518440dd0BEA2eaAc142a8d5610;
  address internal constant OP_WETH_VELO_POOL = 0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60;
  address internal constant BOLD_LUSD_VELO_POOL = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;
  address internal constant ALETH_WETH_VELO_POOL = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;

  // --- BEEFY VAULT ADDRESSES ---
  address internal constant BOLD_LUSD_VELO_BEEFY_VAULT = 0xC06C0A19d0A3eD7B3BA9D7c3101B6BC9634b84a9;

  // --- YEARN VAULT ADDRESSES ---
  address internal constant ALETH_WETH_YEARN_VAULT = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;

  address internal constant MSETH_WETH_YEARN_VAULT = 0xd0d2Ac44Cc842079e978bB11b094764f7D0dec6A;

  // ============================================================
  //                      VELO CL SWAP STEPS
  // ============================================================

  IStabilityPool.StepConfig internal WETH_USDC_VELO_CL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_CL_SWAP_STEP,
    data: abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: WETH_USDC_VELO_CL_POOL,
        tokenIn: WETH_ADDR,
        tokenOut: USDC_ADDR,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal WSTETH_WETH_VELO_CL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_CL_SWAP_STEP,
    data: abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: WSTETH_WETH_VELO_CL_POOL,
        tokenIn: WSTETH_ADDR,
        tokenOut: WETH_ADDR,
        tickSpacing: 1,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal TBTC_WBTC_VELO_CL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_CL_SWAP_STEP,
    data: abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: TBTC_WBTC_VELO_POOL,
        tokenIn: TBTC_ADDR,
        tokenOut: WBTC_ADDR,
        tickSpacing: 1,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal WBTC_USDC_VELO_CL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_CL_SWAP_STEP,
    data: abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: WBTC_USDC_VELO_POOL,
        tokenIn: WBTC_ADDR,
        tokenOut: USDC_ADDR,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal OP_WETH_VELO_CL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_CL_SWAP_STEP,
    data: abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: OP_WETH_VELO_POOL,
        tokenIn: OP_ADDR,
        tokenOut: WETH_ADDR,
        tickSpacing: 200,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      VELO SWAP STEPS
  // ============================================================

  IStabilityPool.StepConfig internal USDC_BOLD_VELO_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_SWAP_STEP,
    data: abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: USDC_ADDR,
        tokenOut: BOLD_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal ALETH_WETH_VELO_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_SWAP_STEP,
    data: abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: ALETH_ADDR,
        tokenOut: WETH_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal HAIVELO_VELO_VELO_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_SWAP_STEP,
    data: abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: HAIVELO_ADDR,
        tokenOut: VELO_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal VELO_USDC_VELO_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_SWAP_STEP,
    data: abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: VELO_ADDR,
        tokenOut: USDC_ADDR,
        stable: false,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal MSETH_WETH_VELO_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_SWAP_STEP,
    data: abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: MSETH_ADDR,
        tokenOut: WETH_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      CURVE SWAP STEPS
  // ============================================================

  IStabilityPool.StepConfig internal BOLD_HAI_CURVE_STEP_CONFIG = IStabilityPool.StepConfig({
    step: CURVE_STEP,
    data: abi.encode(
      CurveSwapStep.Data({pool: CURVE_BOLD_HAI_POOL, i: int128(1), j: int128(0), tokenIn: BOLD_ADDR, tokenOut: HAI_ADDR})
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      BALANCER V3 SWAP STEPS
  // ============================================================

  IStabilityPool.StepConfig internal RETH_WA_OPT_WETH_BALANCER_V3_STEP_CONFIG = IStabilityPool.StepConfig({
    step: BALANCER_V3_STEP,
    data: abi.encode(
      BalancerV3StablePoolMathSwapStep.Data({
        router: BALANCER_V3_ROUTER,
        pool: BALANCER_V3_RETH_WA_OPT_WETH_POOL,
        tokenIn: RETH_ADDR,
        tokenOut: WA_OPT_WETH_ADDR,
        deadlineBuffer: 1 hours,
        userData: bytes('')
      })
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      ERC4626 WITHDRAWAL STEPS
  // ============================================================

  IStabilityPool.StepConfig internal WA_OPT_WETH_ERC4626_WITHDRAWAL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: ERC4626_STEP,
    data: abi.encode(
      ERC4626WithdrawalStep.Data({vault: WA_OPT_WETH_ADDR, vaultToken: WA_OPT_WETH_ADDR, assetToken: WETH_ADDR})
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      BEEFY VAULT WITHDRAWAL STEPS
  // ============================================================

  IStabilityPool.StepConfig internal BOLD_LUSD_VELO_BEEFY_VAULT_WITHDRAWAL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: BEEFY_STEP,
    data: abi.encode(
      BeefyVaultWithdrawalStep.Data({
        vault: BOLD_LUSD_VELO_BEEFY_VAULT,
        vaultToken: BOLD_LUSD_VELO_BEEFY_VAULT,
        lpToken: BOLD_LUSD_VELO_POOL,
        shareScale: 1e18
      })
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      YEARN VAULT WITHDRAWAL STEPS
  // ============================================================

  IStabilityPool.StepConfig internal ALETH_WETH_YEARN_VAULT_WITHDRAWAL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: YEARN_STEP,
    data: abi.encode(
      YearnVaultWithdrawalStep.Data({
        vault: ALETH_WETH_YEARN_VAULT,
        vaultToken: ALETH_WETH_YEARN_VAULT,
        lpToken: ALETH_WETH_VELO_POOL,
        shareScale: 1e18
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal MSETH_WETH_YEARN_VAULT_WITHDRAWAL_STEP_CONFIG = IStabilityPool.StepConfig({
    step: YEARN_STEP,
    data: abi.encode(
      YearnVaultWithdrawalStep.Data({
        vault: MSETH_WETH_YEARN_VAULT,
        vaultToken: MSETH_WETH_YEARN_VAULT,
        lpToken: MSETH_WETH_VELO_POOL,
        shareScale: 1e18
      })
    ),
    slippageBps: 0
  });

  // ============================================================
  //                      VELO LP REMOVAL AND SWAP STEPS
  // ============================================================

  IStabilityPool.StepConfig internal BOLD_LUSD_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_LP_REMOVE_AND_SWAP_STEP,
    data: abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: BOLD_LUSD_VELO_POOL,
        tokenA: BOLD_ADDR,
        tokenB: LUSD_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal ALETH_WETH_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_LP_REMOVE_AND_SWAP_STEP,
    data: abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: ALETH_WETH_VELO_POOL,
        tokenA: WETH_ADDR,
        tokenB: ALETH_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  IStabilityPool.StepConfig internal MSETH_WETH_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG = IStabilityPool.StepConfig({
    step: VELO_LP_REMOVE_AND_SWAP_STEP,
    data: abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: MSETH_WETH_VELO_POOL,
        tokenA: WETH_ADDR,
        tokenB: MSETH_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    ),
    slippageBps: 0
  });

  function setUp() public virtual {}

  /**
   * @notice This script is left as an example on how to use MainnetScript contract
   * @dev    This script is executed with `yarn script:mainnet` command
   */
  function run() public {
    _getEnvironmentParams();
    vm.startBroadcast();

    // balancerV3Step = address(new BalancerV3StablePoolMathSwapStep());
    // erc4626Step = address(new ERC4626WithdrawalStep());
    // curveStep = address(new CurveSwapStep());
    // veloSwapStep = address(new VeloSwapStep());
    // veloCLSwapStep = address(new VeloCLSwapStepViewQuoter(4096));
    // veloLPRemovalStep = address(new VeloLPRemovalStep());
    // veloLPRemoveAndSwapStep = address(new VeloLPRemoveAndSwapStep());
    // beefyStep = address(new BeefyVaultWithdrawalStep());
    // yearnStep = address(new YearnVaultWithdrawalStep());

    // Script goes here

    vm.stopBroadcast();
  }

  // --- WETH pipeline ---
  function _configureWETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](3);
    // Step 1: WETH -> USDC (VeloCL)
    _steps[0] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 2: USDC -> BOLD (Velo)
    _steps[1] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 3: BOLD -> HAI (Curve)
    _steps[2] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- WSTETH pipeline ---
  function _configureWSTETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: WSTETH -> WETH (VeloCL)
    _steps[0] = WSTETH_WETH_VELO_CL_STEP_CONFIG;
    // Step 2: WETH -> USDC (VeloCL)
    _steps[1] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- ALETH pipeline ---
  function _configureALETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: ALETH -> WETH (Velo)
    _steps[0] = ALETH_WETH_VELO_STEP_CONFIG;
    // Step 2: WETH -> USDC (VeloCL)
    _steps[1] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- RETH pipeline ---
  function _configureRETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](5);
    // Step 1: RETH -> WA_OPT_WETH (Balancer V3)
    _steps[0] = RETH_WA_OPT_WETH_BALANCER_V3_STEP_CONFIG;
    // Step 2: WA_OPT_WETH -> WETH (ERC4626)
    _steps[1] = WA_OPT_WETH_ERC4626_WITHDRAWAL_STEP_CONFIG;
    // Step 3: WETH -> USDC (VeloCL)
    _steps[2] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 4: USDC -> BOLD (Velo)
    _steps[3] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 5: BOLD -> HAI (Curve)
    _steps[4] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- HAIVELO pipeline ---
  function _configureHAIVELOV2() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: HAIVELO -> VELO (Velo)
    _steps[0] = HAIVELO_VELO_VELO_STEP_CONFIG;
    // Step 2: VELO -> USDC (Velo)
    _steps[1] = VELO_USDC_VELO_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- TBTC pipeline ---
  function _configureTBTC() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: TBTC -> WBTC (VeloCL)
    _steps[0] = TBTC_WBTC_VELO_CL_STEP_CONFIG;
    // Step 2: WBTC -> USDC (VeloCL)
    _steps[1] = WBTC_USDC_VELO_CL_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- MSETH pipeline ---
  function _configureMSETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: MSETH -> WETH (Velo)
    _steps[0] = MSETH_WETH_VELO_STEP_CONFIG;
    // Step 2: WETH -> USDC (VeloCL)
    _steps[1] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- OP pipeline ---
  function _configureOP() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](4);
    // Step 1: OP -> WETH (Velo)
    _steps[0] = OP_WETH_VELO_CL_STEP_CONFIG;
    // Step 2: WETH -> USDC (VeloCL)
    _steps[1] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 3: USDC -> BOLD (Velo)
    _steps[2] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 4: BOLD -> HAI (Curve)
    _steps[3] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- HAIAERO pipeline --- TODO: Implement
  function _configureHAIAERO() internal {}

  // --- MOO_VELO_BOLD_LUSD pipeline ---
  function _configureMOO_VELO_BOLD_LUSD() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](3);
    // Step 1: BOLD_LUSD_VELO_BEEFY_VAULT -> BOLD LUSD VELO LP TOKENS (Beefy)
    _steps[0] = BOLD_LUSD_VELO_BEEFY_VAULT_WITHDRAWAL_STEP_CONFIG;
    // Step 2: BOLD LUSD VELO LP TOKENS -> BOLD (Velo)
    _steps[1] = BOLD_LUSD_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG;
    // Step 3: BOLD -> HAI (Curve)
    _steps[2] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- YV_VELO_ALETH_WETH pipeline ---
  function _configureYV_VELO_ALETH_WETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](5);
    // Step 1: ALETH_WETH_YEARN_VAULT -> ALETH WETH VELO LP TOKENS (Yearn)
    _steps[0] = ALETH_WETH_YEARN_VAULT_WITHDRAWAL_STEP_CONFIG;
    // Step 2: ALETH WETH VELO LP TOKENS -> WETH (Velo)
    _steps[1] = ALETH_WETH_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG;
    // Step 3: WETH -> USDC (VeloCL)
    _steps[2] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 4: USDC -> BOLD (Velo)
    _steps[3] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 5: BOLD -> HAI (Curve)
    _steps[4] = BOLD_HAI_CURVE_STEP_CONFIG;
  }

  // --- YV_VELO_MSETH_WETH pipeline ---
  function _configureYV_VELO_MSETH_WETH() internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](5);
    // Step 1: MSETH_WETH_YEARN_VAULT -> MSETH WETH VELO LP TOKENS (Yearn)
    _steps[0] = MSETH_WETH_YEARN_VAULT_WITHDRAWAL_STEP_CONFIG;
    // Step 2: MSETH WETH VELO LP TOKENS -> WETH (Velo)
    _steps[1] = MSETH_WETH_VELO_LP_REMOVAL_AND_SWAP_STEP_CONFIG;
    // Step 3: WETH -> USDC (VeloCL)
    _steps[2] = WETH_USDC_VELO_CL_STEP_CONFIG;
    // Step 4: USDC -> BOLD (Velo)
    _steps[3] = USDC_BOLD_VELO_STEP_CONFIG;
    // Step 5: BOLD -> HAI (Curve)
    _steps[4] = BOLD_HAI_CURVE_STEP_CONFIG;
  }
}

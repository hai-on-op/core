// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ERC4626ShareOracle} from '@contracts/oracles/ERC4626ShareOracle.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {VeloLPRemovalStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';

abstract contract ForkedMainnetAt148368730 is HaiTest {
  uint256 internal constant FORK_BLOCK = 148_368_730;

  function _forkMainnetAtPinnedBlock() internal {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
  }
}

contract E2EBalancerV3StablePoolMathSwapStepForkTest is ForkedMainnetAt148368730 {
  address internal constant BALANCER_ROUTER = 0x84813aA3e079A665C0B80F944427eE83cBA63617;
  address internal constant BALANCER_POOL = 0x870c0Af8A1af0B58b4b0bD31CE4fe72864ae45BE;

  address internal constant RETH = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D;
  address internal constant WA_OPT_WETH = 0x464b808c2C7E04b07e860fDF7a91870620246148;
  address internal constant RETH_USD_ORACLE = 0xB43314DBdb9b8036E7012A3cDc267E2105Ee8740;
  address internal constant WETH_USD_ORACLE = 0x2fC0cb2c5065a79bC2db79e4fbD537b7CaCF6f36;
  uint16 internal constant ORACLE_TOLERANCE_BPS = 200;

  uint256 internal constant AMOUNT_IN = 8_633_153_881_674_896; // ~0.00863 rETH

  BalancerV3StablePoolMathSwapStep internal step;
  ERC4626ShareOracle internal waOptWethUsdOracle;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new BalancerV3StablePoolMathSwapStep();
    waOptWethUsdOracle = new ERC4626ShareOracle(IERC4626(WA_OPT_WETH), IBaseOracle(WETH_USD_ORACLE), 'waOptWETH / USD');
  }

  function test_balancer_v3_stable_pool_math_swap_step_preview_and_execute() public {
    deal(RETH, address(step), AMOUNT_IN);

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: BALANCER_ROUTER,
      pool: BALANCER_POOL,
      tokenIn: RETH,
      tokenOut: WA_OPT_WETH,
      deadlineBuffer: 1 hours,
      userData: bytes(''),
      tokenInOracle: RETH_USD_ORACLE,
      tokenOutOracle: address(waOptWethUsdOracle),
      oracleToleranceBps: ORACLE_TOLERANCE_BPS
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), AMOUNT_IN);
    assertEq(_preview.length, 1, 'preview length');
    assertGt(_preview[0], 0, 'preview should return WA_OPT_WETH');

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = (_preview[0] * 97) / 100;
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive WA_OPT_WETH');
    assertGe(_out[0], _minOuts[0], 'out should satisfy preview minOut');
    assertEq(IERC20(RETH).balanceOf(address(step)), 0, 'all RETH should be spent');
    assertGt(IERC20(WA_OPT_WETH).balanceOf(address(step)), 0, 'step should hold WA_OPT_WETH');
  }
}

contract E2EERC4626WithdrawalStepForkTest is ForkedMainnetAt148368730 {
  address internal constant WA_OPT_WETH = 0x464b808c2C7E04b07e860fDF7a91870620246148;
  address internal constant WETH = 0x4200000000000000000000000000000000000006;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 WA_OPT_WETH

  ERC4626WithdrawalStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new ERC4626WithdrawalStep();
  }

  function test_erc4626_withdrawal_step() public {
    deal(WA_OPT_WETH, address(step), AMOUNT_IN);

    ERC4626WithdrawalStep.Data memory _data =
      ERC4626WithdrawalStep.Data({vault: WA_OPT_WETH, vaultToken: WA_OPT_WETH, assetToken: WETH});

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive WETH');
    assertEq(IERC20(WA_OPT_WETH).balanceOf(address(step)), 0, 'all WA_OPT_WETH should be spent');
    assertGt(IERC20(WETH).balanceOf(address(step)), 0, 'step should hold WETH');
  }
}

contract E2EBeefyVaultWithdrawalStepForkTest is ForkedMainnetAt148368730 {
  address internal constant BEEFY_VAULT = 0xC06C0A19d0A3eD7B3BA9D7c3101B6BC9634b84a9;
  address internal constant LP_TOKEN = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 mooToken

  BeefyVaultWithdrawalStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new BeefyVaultWithdrawalStep();
  }

  function test_beefy_vault_withdrawal_step() public {
    deal(BEEFY_VAULT, address(step), AMOUNT_IN);

    BeefyVaultWithdrawalStep.Data memory _data =
      BeefyVaultWithdrawalStep.Data({vault: BEEFY_VAULT, vaultToken: BEEFY_VAULT, lpToken: LP_TOKEN, shareScale: 1e18});

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive LP token');
    assertEq(IERC20(BEEFY_VAULT).balanceOf(address(step)), 0, 'all mooTokens should be spent');
    assertGt(IERC20(LP_TOKEN).balanceOf(address(step)), 0, 'step should hold LP token');
  }
}

contract E2ECurveSwapStepForkTest is ForkedMainnetAt148368730 {
  address internal constant CURVE_POOL = 0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5;
  address internal constant HAI = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant BOLD = 0x03569CC076654F82679C4BA2124D64774781B01D;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 BOLD

  CurveSwapStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new CurveSwapStep();
  }

  function test_curve_swap_step() public {
    deal(BOLD, address(step), AMOUNT_IN);

    CurveSwapStep.Data memory _data =
      CurveSwapStep.Data({pool: CURVE_POOL, i: int128(1), j: int128(0), tokenIn: BOLD, tokenOut: HAI});

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive tokenOut');
    assertEq(IERC20(BOLD).balanceOf(address(step)), 0, 'all BOLD should be spent');
    assertGt(IERC20(HAI).balanceOf(address(step)), 0, 'step should hold tokenOut');
  }
}

contract E2EVeloCLSwapStepViewQuoterForkTest is ForkedMainnetAt148368730 {
  uint256 internal constant DEFAULT_MAX_QUOTE_STEPS = 4096;

  address internal constant VELO_CL_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

  address internal constant WETH = 0x4200000000000000000000000000000000000006;
  address internal constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

  bytes4 internal constant SELECTOR_FACTORY = 0xc45a0155;
  bytes4 internal constant SELECTOR_GET_POOL_INT24 = 0x28af8d0b;
  bytes4 internal constant SELECTOR_GET_POOL_UINT24 = 0x1698ee82;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 WETH
  int24 internal constant TICK_SPACING = 100;
  VeloCLSwapStepViewQuoter internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new VeloCLSwapStepViewQuoter(DEFAULT_MAX_QUOTE_STEPS);
  }

  function test_velo_cl_swap_step_view_quoter_preview_and_execute() public {
    address _factory = _factoryFromRouter(VELO_CL_ROUTER);
    address _pool = _poolFromFactory(_factory, WETH, USDC, TICK_SPACING);

    VeloCLSwapStepViewQuoter.Data memory _data = VeloCLSwapStepViewQuoter.Data({
      router: VELO_CL_ROUTER,
      pool: _pool,
      tokenIn: WETH,
      tokenOut: USDC,
      tickSpacing: TICK_SPACING,
      sqrtPriceLimitX96: 0,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), AMOUNT_IN);
    assertEq(_preview.length, 1);
    assertGt(_preview[0], 0, 'preview should return USDC out');

    deal(WETH, address(step), AMOUNT_IN);

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = (_preview[0] * 97) / 100;
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive USDC');
    assertGe(_out[0], _minOuts[0], 'out should satisfy quoted minOut');
    assertEq(IERC20(WETH).balanceOf(address(step)), 0, 'all WETH should be spent');
    assertGt(IERC20(USDC).balanceOf(address(step)), 0, 'step should hold USDC');
  }

  function _factoryFromRouter(address _router) internal view returns (address _factory) {
    (bool _ok, bytes memory _ret) = _router.staticcall(abi.encodeWithSelector(SELECTOR_FACTORY));
    require(_ok && _ret.length >= 32, 'factory() failed');
    _factory = abi.decode(_ret, (address));
    require(_factory != address(0), 'factory zero');
  }

  function _poolFromFactory(
    address _factory,
    address _tokenIn,
    address _tokenOut,
    int24 _tickSpacing
  ) internal view returns (address _pool) {
    (bool _okInt24, bytes memory _retInt24) =
      _factory.staticcall(abi.encodeWithSelector(SELECTOR_GET_POOL_INT24, _tokenIn, _tokenOut, _tickSpacing));
    if (_okInt24 && _retInt24.length >= 32) {
      _pool = abi.decode(_retInt24, (address));
    }
    if (_pool == address(0)) {
      (bool _okUint24, bytes memory _retUint24) = _factory.staticcall(
        abi.encodeWithSelector(SELECTOR_GET_POOL_UINT24, _tokenIn, _tokenOut, uint24(uint24(int24(_tickSpacing))))
      );
      require(_okUint24 && _retUint24.length >= 32, 'getPool failed');
      _pool = abi.decode(_retUint24, (address));
    }
    require(_pool != address(0), 'pool zero');
  }
}

contract E2EVeloLPRemovalStepForkTest is ForkedMainnetAt148368730 {
  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant LP_TOKEN = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;
  address internal constant TOKEN_A = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant TOKEN_B = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 LP tokens

  VeloLPRemovalStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new VeloLPRemovalStep();
  }

  function test_velo_lp_removal_step() public {
    deal(LP_TOKEN, address(step), AMOUNT_IN);

    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: VELO_ROUTER,
      lpToken: LP_TOKEN,
      tokenA: TOKEN_A,
      tokenB: TOKEN_B,
      stable: true,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](2);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 2);
    assertGt(_out[0], 0, 'should receive tokenA');
    assertGt(_out[1], 0, 'should receive tokenB');
    assertEq(IERC20(LP_TOKEN).balanceOf(address(step)), 0, 'all LP tokens should be spent');
    assertGt(IERC20(TOKEN_A).balanceOf(address(step)), 0, 'step should hold tokenA');
    assertGt(IERC20(TOKEN_B).balanceOf(address(step)), 0, 'step should hold tokenB');
  }
}

contract E2EVeloLPRemoveAndSwapStepForkTest is ForkedMainnetAt148368730 {
  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
  address internal constant LP_TOKEN = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;
  address internal constant TOKEN_A = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant TOKEN_B = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 LP tokens

  VeloLPRemoveAndSwapStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new VeloLPRemoveAndSwapStep();
  }

  function test_velo_lp_remove_and_swap_step() public {
    deal(LP_TOKEN, address(step), AMOUNT_IN);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: VELO_ROUTER,
      factory: VELO_FACTORY,
      lpToken: LP_TOKEN,
      tokenA: TOKEN_A,
      tokenB: TOKEN_B,
      stableLp: true,
      stableSwap: true,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive tokenA');
    assertEq(IERC20(LP_TOKEN).balanceOf(address(step)), 0, 'all LP tokens should be spent');
    assertGt(IERC20(TOKEN_A).balanceOf(address(step)), 0, 'step should hold tokenA');
    assertEq(IERC20(TOKEN_B).balanceOf(address(step)), 0, 'all tokenB should be swapped');
  }
}

contract E2EVeloSwapStepForkTest is ForkedMainnetAt148368730 {
  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
  address internal constant TOKEN_IN = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;
  address internal constant TOKEN_OUT = 0x03569CC076654F82679C4BA2124D64774781B01D;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 tokens

  VeloSwapStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new VeloSwapStep();
  }

  function test_velo_swap_step() public {
    deal(TOKEN_IN, address(step), AMOUNT_IN);

    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: VELO_ROUTER,
      factory: VELO_FACTORY,
      tokenIn: TOKEN_IN,
      tokenOut: TOKEN_OUT,
      stable: true,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive tokenOut');
    assertEq(IERC20(TOKEN_IN).balanceOf(address(step)), 0, 'all tokenIn should be spent');
    assertGt(IERC20(TOKEN_OUT).balanceOf(address(step)), 0, 'step should hold tokenOut');
  }
}

contract E2EYearnVaultWithdrawalStepForkTest is ForkedMainnetAt148368730 {
  address internal constant YEARN_VAULT = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;
  address internal constant LP_TOKEN = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;

  uint256 internal constant AMOUNT_IN = 1e16; // 0.01 yvTokens

  YearnVaultWithdrawalStep internal step;

  function setUp() public {
    _forkMainnetAtPinnedBlock();
    step = new YearnVaultWithdrawalStep();
  }

  function test_yearn_vault_withdrawal_step() public {
    deal(YEARN_VAULT, address(step), AMOUNT_IN);

    YearnVaultWithdrawalStep.Data memory _data =
      YearnVaultWithdrawalStep.Data({vault: YEARN_VAULT, vaultToken: YEARN_VAULT, lpToken: LP_TOKEN, shareScale: 1e18});

    uint256[] memory _minOuts = new uint256[](1);
    uint256[] memory _out = step.execute(abi.encode(_data), AMOUNT_IN, _minOuts);

    assertEq(_out.length, 1);
    assertGt(_out[0], 0, 'should receive LP token');
    assertEq(IERC20(YEARN_VAULT).balanceOf(address(step)), 0, 'all yvTokens should be spent');
    assertGt(IERC20(LP_TOKEN).balanceOf(address(step)), 0, 'step should hold LP token');
  }
}

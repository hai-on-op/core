// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';

import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {VeloLPRemovalStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {
  MockBeefyVaultForTest,
  MockYearnVaultForTest,
  MockVeloRouterForTest,
  MockVeloRouterWithQuoteExecutionMismatchForTest,
  MockVeloPairForTest,
  MockERC4626VaultForTest
} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';

abstract contract Base is HaiTest {}

contract Unit_StrategyStep_Branches is Base {
  function _expectedVeloLpRemoveAndSwapPreview(
    uint256 _reserveA,
    uint256 _reserveB,
    uint256 _amountIn,
    uint256 _totalSupply,
    uint256 _swapOutMultiplierWad
  ) internal pure returns (uint256 _expectedPreviewOut) {
    uint256 _expectedRemoveA = (_reserveA * _amountIn) / _totalSupply;
    uint256 _expectedRemoveB = (_reserveB * _amountIn) / _totalSupply;
    uint256 _lpShareWad = (_amountIn * 1e18) / _totalSupply;
    uint256 _swapHaircutWad = 1e18 - (_lpShareWad * _lpShareWad) / 1e18;
    _expectedPreviewOut =
      _expectedRemoveA + (((_expectedRemoveB * _swapOutMultiplierWad) / 1e18) * _swapHaircutWad) / 1e18;
  }

  function test_BeefyPreview_DefaultShareScaleWhenZero() public {
    BeefyVaultWithdrawalStep _step = new BeefyVaultWithdrawalStep();
    ERC20ForTest _lpToken = new ERC20ForTest();
    MockBeefyVaultForTest _vault = new MockBeefyVaultForTest(_lpToken);

    BeefyVaultWithdrawalStep.Data memory _data = BeefyVaultWithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(0xBEEF),
      lpToken: address(_lpToken),
      shareScale: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_BeefyExecute_ZeroAmount() public {
    BeefyVaultWithdrawalStep _step = new BeefyVaultWithdrawalStep();
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    BeefyVaultWithdrawalStep.Data memory _data = BeefyVaultWithdrawalStep.Data({
      vault: address(0xBEEF),
      vaultToken: address(0xCAFE),
      lpToken: address(0xF00D),
      shareScale: 1e18
    });

    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }

  function test_YearnPreview_DefaultShareScaleWhenZero() public {
    YearnVaultWithdrawalStep _step = new YearnVaultWithdrawalStep();
    ERC20ForTest _lpToken = new ERC20ForTest();
    MockYearnVaultForTest _vault = new MockYearnVaultForTest(_lpToken);

    YearnVaultWithdrawalStep.Data memory _data = YearnVaultWithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(0x1234),
      lpToken: address(_lpToken),
      shareScale: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_YearnExecute_ZeroAmount() public {
    YearnVaultWithdrawalStep _step = new YearnVaultWithdrawalStep();
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    YearnVaultWithdrawalStep.Data memory _data = YearnVaultWithdrawalStep.Data({
      vault: address(0xBEEF),
      vaultToken: address(0xCAFE),
      lpToken: address(0xF00D),
      shareScale: 1e18
    });

    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }

  function test_VeloLPRemoveAndSwap_PreviewAndExecute_HappyPath() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _lpToken.setState(1000e18, 500e18, 100e18);
    _lpToken.mint(address(_step), 10e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256 _expectedPreviewOut =
      _expectedVeloLpRemoveAndSwapPreview(1000e18, 500e18, 10e18, _lpToken.totalSupply(), 2e18);
    uint256 _expectedExecuteOut = 200e18;

    uint256[] memory _preview = _step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], _expectedPreviewOut);

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = _expectedPreviewOut;
    uint256[] memory _out = _step.execute(abi.encode(_data), 10e18, _minOuts);
    assertEq(_out[0], _expectedExecuteOut);
    assertEq(_tokenA.balanceOf(address(_step)), _expectedExecuteOut);
  }

  function test_VeloLPRemoveAndSwap_PreviewHaircutsOptimisticSwapQuote() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterWithQuoteExecutionMismatchForTest _router = new MockVeloRouterWithQuoteExecutionMismatchForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _lpToken.setState(500e18, 250e18, 50e18);
    _lpToken.mint(address(_step), 50e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: true,
      stableSwap: true,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 50e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 437_500_000_000_000_000_000);

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = _preview[0];
    uint256[] memory _out = _step.execute(abi.encode(_data), 50e18, _minOuts);
    assertEq(_out[0], 437_500_000_000_000_000_000);
  }

  function test_VeloLPRemoveAndSwap_Preview_OracleFloorEnabled_AllowsFairOutput() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    OracleForTest _tokenAOracle = new OracleForTest(2e18);
    OracleForTest _tokenBOracle = new OracleForTest(1e18);
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _lpToken.setState(1000e18, 2000e18, 100e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: true,
      tokenAOracle: address(_tokenAOracle),
      tokenBOracle: address(_tokenBOracle),
      oracleToleranceBps: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 50e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 2000e18);
  }

  function test_Revert_VeloLPRemoveAndSwap_Preview_WhenQuoteBelowOracleFloor() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    OracleForTest _tokenAOracle = new OracleForTest(2e18);
    OracleForTest _tokenBOracle = new OracleForTest(1e18);
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _router.setSwapOutMultiplier(0);
    _lpToken.setState(1000e18, 2000e18, 100e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: true,
      tokenAOracle: address(_tokenAOracle),
      tokenBOracle: address(_tokenBOracle),
      oracleToleranceBps: 0
    });

    vm.expectRevert(VeloLPRemoveAndSwapStep.VeloLPRemoveAndSwapStep_OracleFloorNotMet.selector);
    _step.preview(abi.encode(_data), 10e18);
  }

  function test_Revert_VeloLPRemoveAndSwap_Execute_UsesOracleFloorWhenMinOutIsLower() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    OracleForTest _tokenAOracle = new OracleForTest(2e18);
    OracleForTest _tokenBOracle = new OracleForTest(1e18);
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _router.setRemovePerLp(1e18, 0);
    _lpToken.setState(1000e18, 2000e18, 900e18);
    _lpToken.mint(address(_step), 100e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: true,
      tokenAOracle: address(_tokenAOracle),
      tokenBOracle: address(_tokenBOracle),
      oracleToleranceBps: 0
    });

    vm.expectRevert(VeloLPRemoveAndSwapStep.VeloLPRemoveAndSwapStep_InsufficientOutput.selector);
    _step.execute(abi.encode(_data), 100e18, new uint256[](0));
  }

  function test_Revert_VeloLPRemoveAndSwap_Preview_InvalidPairTokens() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    ERC20ForTest _wrongTokenB = new ERC20ForTest();
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    _lpToken.setState(1000e18, 500e18, 100e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_wrongTokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    vm.expectRevert(VeloLPRemoveAndSwapStep.VeloLPRemoveAndSwapStep_InvalidPairTokens.selector);
    _step.preview(abi.encode(_data), 10e18);
  }

  function test_VeloLPRemoveAndSwap_ExecuteZeroAmount() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(0xBEEF),
      factory: address(0xCAFE),
      lpToken: address(0xF00D),
      tokenA: address(0xAAAA),
      tokenB: address(0xBBBB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }

  function test_VeloLPRemoveAndSwap_Execute_UsesFixedDeadlineOffset() public {
    vm.warp(1000);

    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    ERC20ForTest _lpToken = new ERC20ForTest();

    _lpToken.mint(address(_step), 1e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 0,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    _step.execute(abi.encode(_data), 1e18, new uint256[](0));

    assertEq(_router.lastRemoveLiquidityDeadline(), block.timestamp + 1);
    assertEq(_router.lastSwapDeadline(), block.timestamp + 1);
  }

  function test_VeloLPRemoval_Preview_TokenOrderFlipBranch() public {
    VeloLPRemovalStep _step = new VeloLPRemovalStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();

    // token0 is tokenB to exercise the token-order flip branch
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenB), address(_tokenA));
    _lpToken.setState(1000e18, 400e18, 100e18);

    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(_router),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stable: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 40e18);
    assertEq(_preview[1], 100e18);
  }

  function test_VeloLPRemoval_Preview_ZeroTotalSupply() public {
    VeloLPRemovalStep _step = new VeloLPRemovalStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();
    MockVeloPairForTest _lpToken = new MockVeloPairForTest(address(_tokenA), address(_tokenB));

    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(_router),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stable: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _preview = _step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 0);
    assertEq(_preview[1], 0);
  }

  function test_VeloLPRemoval_Execute_ZeroAmount() public {
    VeloLPRemovalStep _step = new VeloLPRemovalStep();
    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(0xBEEF),
      lpToken: address(0xCAFE),
      tokenA: address(0xAAAA),
      tokenB: address(0xBBBB),
      stable: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _minOuts = new uint256[](2);
    _minOuts[0] = 1;
    _minOuts[1] = 1;

    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 2);
    assertEq(_out[0], 0);
    assertEq(_out[1], 0);
  }

  function test_VeloSwap_Execute_ZeroAmount() public {
    VeloSwapStep _step = new VeloSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();

    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(_router),
      factory: address(0),
      tokenIn: address(_tokenA),
      tokenOut: address(_tokenB),
      stable: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenInOracle: address(0),
      tokenOutOracle: address(0),
      oracleToleranceBps: 0
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;
    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }

  function test_VeloSwap_Execute_UsesFixedDeadlineOffset() public {
    vm.warp(1000);

    VeloSwapStep _step = new VeloSwapStep();
    MockVeloRouterForTest _router = new MockVeloRouterForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();

    _tokenA.mint(address(_step), 1e18);

    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(_router),
      factory: address(0),
      tokenIn: address(_tokenA),
      tokenOut: address(_tokenB),
      stable: false,
      deadlineBuffer: 0,
      useOracleFloor: false,
      tokenInOracle: address(0),
      tokenOutOracle: address(0),
      oracleToleranceBps: 0
    });

    _step.execute(abi.encode(_data), 1e18, new uint256[](0));

    assertEq(_router.lastSwapDeadline(), block.timestamp + 1);
  }

  function test_ERC4626Withdraw_Execute_ZeroAmount() public {
    ERC4626WithdrawalStep _step = new ERC4626WithdrawalStep();
    ERC20ForTest _assetToken = new ERC20ForTest();
    MockERC4626VaultForTest _vault = new MockERC4626VaultForTest(address(_assetToken));

    ERC4626WithdrawalStep.Data memory _data = ERC4626WithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(_vault),
      assetToken: address(_assetToken)
    });
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    uint256[] memory _out = _step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }
}

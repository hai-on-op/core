// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {
  MockVeloCLRouterForTest,
  MockVeloCLPoolForTest
} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

abstract contract Base is HaiTest {
  uint256 internal constant DEFAULT_MAX_QUOTE_STEPS = 4096;

  VeloCLSwapStepViewQuoter internal step;
  ERC20ForTest internal tokenIn;
  ERC20ForTest internal tokenOut;
  OracleForTest internal tokenInOracle;
  OracleForTest internal tokenOutOracle;
  MockVeloCLRouterForTest internal router;
  MockVeloCLPoolForTest internal pool;

  function setUp() public virtual {
    step = new VeloCLSwapStepViewQuoter(DEFAULT_MAX_QUOTE_STEPS);
    tokenIn = new ERC20ForTest();
    tokenOut = new ERC20ForTest();
    tokenInOracle = new OracleForTest(1e18);
    tokenOutOracle = new OracleForTest(1e18);
    router = new MockVeloCLRouterForTest(tokenIn, tokenOut);
    pool = new MockVeloCLPoolForTest(address(tokenIn), address(tokenOut));
  }

  function _data(
    address _tokenIn,
    address _tokenOut,
    int24 _tickSpacing,
    uint160 _sqrtPriceLimitX96
  ) internal view returns (VeloCLSwapStepViewQuoter.Data memory _out) {
    _out = VeloCLSwapStepViewQuoter.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: _tokenIn,
      tokenOut: _tokenOut,
      tickSpacing: _tickSpacing,
      sqrtPriceLimitX96: _sqrtPriceLimitX96,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenInOracle: address(0),
      tokenOutOracle: address(0),
      oracleToleranceBps: 0
    });
  }

  function _oracleData() internal view returns (VeloCLSwapStepViewQuoter.Data memory _out) {
    _out = _data(address(tokenIn), address(tokenOut), 60, 0);
    _out.useOracleFloor = true;
    _out.tokenInOracle = address(tokenInOracle);
    _out.tokenOutOracle = address(tokenOutOracle);
  }
}

contract Unit_VeloCLSwapStepViewQuoter is Base {
  function test_Revert_Constructor_InvalidMaxQuoteSteps() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidMaxQuoteSteps.selector);
    new VeloCLSwapStepViewQuoter(0);
  }

  function test_Preview_ZeroAmount() public view {
    uint256[] memory _preview = step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), 0);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 0);
  }

  function test_Revert_Preview_InvalidAmountIn() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidAmountIn.selector);
    step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), uint256(type(int256).max) + 1);
  }

  function test_Revert_Preview_InvalidTickSpacing_Zero() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidTickSpacing.selector);
    step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 0, 0)), 1e18);
  }

  function test_Revert_Preview_PoolNotFound() public {
    VeloCLSwapStepViewQuoter.Data memory _stepData = VeloCLSwapStepViewQuoter.Data({
      router: address(router),
      pool: address(0),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      tickSpacing: 60,
      sqrtPriceLimitX96: 0,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenInOracle: address(0),
      tokenOutOracle: address(0),
      oracleToleranceBps: 0
    });

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_PoolNotFound.selector);
    step.preview(abi.encode(_stepData), 1e18);
  }

  function test_Revert_Preview_InvalidFeePips() public {
    pool.setFee(0);
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidFeePips.selector);
    step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), 1e18);
  }

  function test_Revert_Preview_InvalidPoolTokens() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidPoolTokens.selector);
    step.preview(abi.encode(_data(address(0xBEEF), address(tokenOut), 60, 0)), 1e18);
  }

  function test_Revert_Preview_InvalidTickSpacing_MismatchWithPool() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidTickSpacing.selector);
    step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 10, 0)), 1e18);
  }

  function test_Revert_Preview_InvalidSqrtPriceLimit_ZeroForOne() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidSqrtPriceLimitX96.selector);
    step.preview(
      abi.encode(
        _data(
          address(tokenIn),
          address(tokenOut),
          60,
          79_228_162_514_264_337_593_543_950_336 // current sqrt price
        )
      ),
      1e18
    );
  }

  function test_Revert_Preview_InvalidSqrtPriceLimit_OneForZero() public {
    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidSqrtPriceLimitX96.selector);
    step.preview(
      abi.encode(
        _data(
          address(tokenOut),
          address(tokenIn),
          60,
          79_228_162_514_264_337_593_543_950_336 // current sqrt price
        )
      ),
      1e18
    );
  }

  function test_Preview_PositiveAmount_DoesNotRevert() public view {
    uint160 _limit = 79_228_162_514_264_337_593_543_950_335; // current sqrt price - 1
    uint256[] memory _preview = step.preview(abi.encode(_data(address(tokenIn), address(tokenOut), 60, _limit)), 1e18);
    assertEq(_preview.length, 1);
  }

  function test_Revert_Preview_WhenPoolQuoteBelowOracleFloor() public {
    VeloCLSwapStepViewQuoter.Data memory _stepData = _oracleData();
    tokenInOracle.setPriceAndValidity(1_000_000e18, true);
    tokenOutOracle.setPriceAndValidity(1e18, true);

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_OracleFloorNotMet.selector);
    step.preview(abi.encode(_stepData), 1e18);
  }

  function test_Preview_OracleFloorDisabled_IgnoresMissingOracle() public view {
    VeloCLSwapStepViewQuoter.Data memory _stepData = _data(address(tokenIn), address(tokenOut), 60, 0);
    _stepData.tokenInOracle = address(0);
    _stepData.tokenOutOracle = address(0);

    uint256[] memory _preview = step.preview(abi.encode(_stepData), 1e18);
    assertEq(_preview.length, 1);
  }

  function test_Revert_Preview_InvalidOracle() public {
    VeloCLSwapStepViewQuoter.Data memory _stepData = _oracleData();
    _stepData.tokenInOracle = address(0);

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidOracle.selector);
    step.preview(abi.encode(_stepData), 1e18);
  }

  function test_Revert_Preview_InvalidOraclePrice() public {
    tokenInOracle.setPriceAndValidity(1e18, false);

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidOraclePrice.selector);
    step.preview(abi.encode(_oracleData()), 1e18);
  }

  function test_Revert_Preview_InvalidOracleTolerance() public {
    VeloCLSwapStepViewQuoter.Data memory _stepData = _oracleData();
    _stepData.oracleToleranceBps = 10_001;

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_InvalidOracleTolerance.selector);
    step.preview(abi.encode(_stepData), 1e18);
  }

  function test_Preview_QuoteLoopLimit_IsConfigurable() public {
    VeloCLSwapStepViewQuoter _lowCapStep = new VeloCLSwapStepViewQuoter(1);
    VeloCLSwapStepViewQuoter _highCapStep = new VeloCLSwapStepViewQuoter(DEFAULT_MAX_QUOTE_STEPS);

    pool.setTickSpacing(1);
    VeloCLSwapStepViewQuoter.Data memory _stepData =
      _data(address(tokenIn), address(tokenOut), 1, TickMath.MIN_SQRT_RATIO + 1);

    vm.expectRevert(VeloCLSwapStepViewQuoter.VeloCLSwapStepViewQuoter_QuoteLoopExceeded.selector);
    _lowCapStep.preview(abi.encode(_stepData), 1e36);

    uint256[] memory _preview = _highCapStep.preview(abi.encode(_stepData), 1e36);
    assertEq(_preview.length, 1);
    assertGt(_preview[0], 0);
  }

  function test_Execute() public {
    tokenIn.mint(address(step), 10e18);
    router.setAmountToSpend(1);
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 20e18;

    uint256[] memory _out = step.execute(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(tokenOut.balanceOf(address(step)), 20e18);
    assertEq(router.lastRecipient(), address(step));
    assertEq(router.lastAmountIn(), 10e18);
    assertEq(router.lastMinOut(), 20e18);
    assertEq(router.lastTickSpacing(), 60);
    assertEq(router.lastSqrtPriceLimit(), 0);
    assertEq(tokenIn.allowance(address(step), address(router)), 0);
  }

  function test_Execute_WithoutMinOuts() public {
    tokenIn.mint(address(step), 10e18);
    uint256[] memory _noMinOuts = new uint256[](0);

    uint256[] memory _out =
      step.execute(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), 10e18, _noMinOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(router.lastMinOut(), 0);
  }

  function test_Revert_Execute_UsesOracleFloorWhenMinOutIsLower() public {
    tokenIn.mint(address(step), 10e18);
    tokenInOracle.setPriceAndValidity(3e18, true);
    tokenOutOracle.setPriceAndValidity(1e18, true);

    vm.expectRevert(bytes('min-out'));
    step.execute(abi.encode(_oracleData()), 10e18, new uint256[](0));
  }

  function test_Execute_OracleFloorDisabled_UsesRouterOutput() public {
    tokenIn.mint(address(step), 10e18);
    tokenInOracle.setPriceAndValidity(3e18, true);
    tokenOutOracle.setPriceAndValidity(1e18, true);

    VeloCLSwapStepViewQuoter.Data memory _stepData = _oracleData();
    _stepData.useOracleFloor = false;

    uint256[] memory _out = step.execute(abi.encode(_stepData), 10e18, new uint256[](0));

    assertEq(_out[0], 20e18);
    assertEq(router.lastMinOut(), 0);
  }

  function test_Execute_ZeroAmount() public {
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    uint256[] memory _out = step.execute(abi.encode(_data(address(tokenIn), address(tokenOut), 60, 0)), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {VeloLPRemovalStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol';
import {MockVeloRouter, MockVeloPair} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';

abstract contract Base is HaiTest {
  MockVeloRouter router;
  ERC20ForTest tokenA;
  ERC20ForTest tokenB;

  function setUp() public virtual {
    router = new MockVeloRouter();
    tokenA = new ERC20ForTest();
    tokenB = new ERC20ForTest();
  }
}

contract Unit_VeloSwapStep is Base {
  VeloSwapStep step;

  function setUp() public override {
    super.setUp();
    step = new VeloSwapStep();
  }

  function test_Preview() public view {
    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(router),
      factory: address(0),
      tokenIn: address(tokenA),
      tokenOut: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_Execute() public {
    tokenA.mint(address(step), 10e18);

    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(router),
      factory: address(0),
      tokenIn: address(tokenA),
      tokenOut: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 20e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(tokenB.balanceOf(address(step)), 20e18);
  }
}

contract Unit_VeloLPRemovalStep is Base {
  VeloLPRemovalStep step;
  MockVeloPair lpToken;
  OracleForTest tokenAOracle;
  OracleForTest tokenBOracle;

  function setUp() public override {
    super.setUp();
    step = new VeloLPRemovalStep();
    lpToken = new MockVeloPair(address(tokenA), address(tokenB));
    tokenAOracle = new OracleForTest(2e18);
    tokenBOracle = new OracleForTest(1e18);

    lpToken.setState(5000e18, 10_000e18, 900e18);
    lpToken.mint(address(step), 100e18);
  }

  function test_Preview_MultiOutput() public view {
    VeloLPRemovalStep.Data memory _data = _defaultData(lpToken);

    uint256[] memory _preview = step.preview(abi.encode(_data), 100e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 500e18);
    assertEq(_preview[1], 1000e18);
  }

  function test_Preview_OracleFloorEnabled_AllowsFairReserves() public view {
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);

    uint256[] memory _preview = step.preview(abi.encode(_data), 100e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 500e18);
    assertEq(_preview[1], 1000e18);
  }

  function test_Revert_Preview_WhenReserveQuoteBelowOracleFloor() public {
    MockVeloPair _skewedLpToken = new MockVeloPair(address(tokenA), address(tokenB));
    _skewedLpToken.setState(1000e18, 50_000e18, 900e18);
    _skewedLpToken.mint(address(step), 100e18);
    VeloLPRemovalStep.Data memory _data = _oracleData(_skewedLpToken);

    vm.expectRevert(VeloLPRemovalStep.VeloLPRemovalStep_OracleFloorNotMet.selector);
    step.preview(abi.encode(_data), 100e18);
  }

  function test_Execute_MultiOutput() public {
    VeloLPRemovalStep.Data memory _data = _defaultData(lpToken);

    uint256[] memory _minOuts = new uint256[](2);
    _minOuts[0] = 500e18;
    _minOuts[1] = 1000e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 100e18, _minOuts);

    assertEq(_out.length, 2);
    assertEq(_out[0], 500e18);
    assertEq(_out[1], 1000e18);
    assertEq(tokenA.balanceOf(address(step)), 500e18);
    assertEq(tokenB.balanceOf(address(step)), 1000e18);
  }

  function test_Execute_OracleFloorDisabled_UsesRouterOutput() public {
    router.setRemovePerLp(1e18, 50e18);
    VeloLPRemovalStep.Data memory _data = _defaultData(lpToken);

    uint256[] memory _out = step.execute(abi.encode(_data), 100e18, new uint256[](0));

    assertEq(_out.length, 2);
    assertEq(_out[0], 100e18);
    assertEq(_out[1], 5000e18);
  }

  function test_Revert_Execute_UsesOracleFloorWhenMinOutsLower() public {
    router.setRemovePerLp(1e18, 50e18);
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);

    vm.expectRevert(bytes('min-out'));
    step.execute(abi.encode(_data), 100e18, new uint256[](0));
  }

  function test_Revert_Preview_InvalidOracle() public {
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);
    _data.tokenAOracle = address(0);

    vm.expectRevert(VeloLPRemovalStep.VeloLPRemovalStep_InvalidOracle.selector);
    step.preview(abi.encode(_data), 100e18);
  }

  function test_Revert_Preview_InvalidOraclePrice() public {
    tokenAOracle.setPriceAndValidity(0, false);
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);

    vm.expectRevert(VeloLPRemovalStep.VeloLPRemovalStep_InvalidOraclePrice.selector);
    step.preview(abi.encode(_data), 100e18);
  }

  function test_Revert_Preview_InvalidOracleTolerance() public {
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);
    _data.oracleToleranceBps = 10_001;

    vm.expectRevert(VeloLPRemovalStep.VeloLPRemovalStep_InvalidOracleTolerance.selector);
    step.preview(abi.encode(_data), 100e18);
  }

  function test_Revert_Preview_UnsupportedStableOracleFloor() public {
    VeloLPRemovalStep.Data memory _data = _oracleData(lpToken);
    _data.stable = true;

    vm.expectRevert(VeloLPRemovalStep.VeloLPRemovalStep_UnsupportedOracleFloor.selector);
    step.preview(abi.encode(_data), 100e18);
  }

  function test_Execute_UsesFixedDeadlineOffset() public {
    vm.warp(1000);

    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 0,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });

    step.execute(abi.encode(_data), 100e18, new uint256[](0));

    assertEq(router.lastRemoveLiquidityDeadline(), block.timestamp + 1);
  }

  function _defaultData(MockVeloPair _lpToken) internal view returns (VeloLPRemovalStep.Data memory _data) {
    _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(_lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours,
      useOracleFloor: false,
      tokenAOracle: address(0),
      tokenBOracle: address(0),
      oracleToleranceBps: 0
    });
  }

  function _oracleData(MockVeloPair _lpToken) internal view returns (VeloLPRemovalStep.Data memory _data) {
    _data = _defaultData(_lpToken);
    _data.useOracleFloor = true;
    _data.tokenAOracle = address(tokenAOracle);
    _data.tokenBOracle = address(tokenBOracle);
  }
}

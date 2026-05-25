// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';
import {MockCurvePoolForTest} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';

abstract contract Base is HaiTest {
  CurveSwapStep internal step;
  ERC20ForTest internal tokenIn;
  ERC20ForTest internal tokenOut;
  OracleForTest internal tokenInOracle;
  OracleForTest internal tokenOutOracle;
  MockCurvePoolForTest internal pool;

  function setUp() public virtual {
    step = new CurveSwapStep();
    tokenIn = new ERC20ForTest();
    tokenOut = new ERC20ForTest();
    tokenInOracle = new OracleForTest(1e18);
    tokenOutOracle = new OracleForTest(1e18);
    pool = new MockCurvePoolForTest(tokenIn, tokenOut);
  }

  function _data() internal view returns (CurveSwapStep.Data memory _dataOut) {
    _dataOut = CurveSwapStep.Data({
      pool: address(pool),
      i: int128(0),
      j: int128(1),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      tokenInOracle: address(tokenInOracle),
      tokenOutOracle: address(tokenOutOracle),
      oracleToleranceBps: 0
    });
  }
}

contract Unit_CurveSwapStep is Base {
  function test_Preview() public view {
    uint256[] memory _preview = step.preview(abi.encode(_data()), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_Revert_Preview_WhenCurveQuoteBelowOracleFloor() public {
    pool.setOutMultiplier(1.7e18);
    tokenInOracle.setPriceAndValidity(2e18, true);
    tokenOutOracle.setPriceAndValidity(1e18, true);

    vm.expectRevert(CurveSwapStep.CurveSwapStep_OracleFloorNotMet.selector);
    step.preview(abi.encode(_data()), 10e18);
  }

  function test_Preview_ZeroAmount() public view {
    uint256[] memory _preview = step.preview(abi.encode(_data()), 0);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 0);
  }

  function test_Revert_Preview_InvalidOracle() public {
    CurveSwapStep.Data memory _data = _data();
    _data.tokenInOracle = address(0);

    vm.expectRevert(CurveSwapStep.CurveSwapStep_InvalidOracle.selector);
    step.preview(abi.encode(_data), 10e18);
  }

  function test_Revert_Preview_InvalidOraclePrice() public {
    tokenInOracle.setPriceAndValidity(1e18, false);

    vm.expectRevert(CurveSwapStep.CurveSwapStep_InvalidOraclePrice.selector);
    step.preview(abi.encode(_data()), 10e18);
  }

  function test_Revert_Preview_InvalidOracleTolerance() public {
    CurveSwapStep.Data memory _data = _data();
    _data.oracleToleranceBps = 10_001;

    vm.expectRevert(CurveSwapStep.CurveSwapStep_InvalidOracleTolerance.selector);
    step.preview(abi.encode(_data), 10e18);
  }

  function test_Execute() public {
    tokenIn.mint(address(step), 10e18);

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 20e18;
    uint256[] memory _out = step.execute(abi.encode(_data()), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(tokenOut.balanceOf(address(step)), 20e18);
  }

  function test_Execute_WithoutMinOuts() public {
    tokenIn.mint(address(step), 5e18);
    uint256[] memory _noMinOuts = new uint256[](0);

    uint256[] memory _out = step.execute(abi.encode(_data()), 5e18, _noMinOuts);
    assertEq(_out[0], 10e18);
  }

  function test_Revert_Execute_UsesOracleFloorWhenMinOutIsLower() public {
    pool.setOutMultiplier(1.9e18);
    tokenIn.mint(address(step), 10e18);
    tokenInOracle.setPriceAndValidity(2e18, true);
    tokenOutOracle.setPriceAndValidity(1e18, true);

    vm.expectRevert(bytes('min-out'));
    step.execute(abi.encode(_data()), 10e18, new uint256[](0));
  }

  function test_Execute_ZeroAmount() public {
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;
    uint256[] memory _out = step.execute(abi.encode(_data()), 0, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }
}

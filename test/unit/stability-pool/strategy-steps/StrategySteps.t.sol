// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
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

  function setUp() public override {
    super.setUp();
    step = new VeloLPRemovalStep();
    lpToken = new MockVeloPair(address(tokenA), address(tokenB));

    lpToken.setState(5000e18, 10_000e18, 900e18);
    lpToken.mint(address(step), 100e18);
  }

  function test_Preview_MultiOutput() public view {
    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 100e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 500e18);
    assertEq(_preview[1], 1000e18);
  }

  function test_Execute_MultiOutput() public {
    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

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
}

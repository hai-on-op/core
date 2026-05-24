// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {
  MockBalancerV3Router,
  MockBalancerV3StablePool,
  MockBalancerV3StableVault
} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';

abstract contract Base is HaiTest {
  ERC20ForTest tokenIn;
  ERC20ForTest tokenOut;

  function setUp() public virtual {
    tokenIn = new ERC20ForTest();
    tokenOut = new ERC20ForTest();
  }
}

contract Unit_BalancerV3StablePoolMathSwapStep is Base {
  BalancerV3StablePoolMathSwapStep step;
  MockBalancerV3StablePool pool;
  MockBalancerV3StableVault vault;
  MockBalancerV3Router router;

  function setUp() public override {
    super.setUp();
    step = new BalancerV3StablePoolMathSwapStep();
    pool = new MockBalancerV3StablePool();
    vault = new MockBalancerV3StableVault(IERC20(address(tokenIn)), IERC20(address(tokenOut)));
    router = new MockBalancerV3Router(address(vault));
  }

  function test_Preview_StablePoolMath() public view {
    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 30e18);
  }

  function test_Preview_StablePoolMath_AppliesSwapFee() public {
    vault.setSwapFeePercentage(1e16); // 1%
    pool.setOutMultiplier(1e18); // passthrough amountGivenScaled18

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 10e18);
    assertEq(_preview[0], 9.9e18);
  }

  function test_Preview_StablePoolMath_RevertsForSwapHooks() public {
    vault.setSwapHooksEnabled(true);

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    vm.expectRevert(BalancerV3StablePoolMathSwapStep.BalancerV3StablePoolMathSwapStep_UnsupportedHooks.selector);
    step.preview(abi.encode(_data), 10e18);
  }

  function test_Execute_StablePoolMath() public {
    tokenIn.mint(address(step), 10e18);

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 30e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 30e18);
    assertEq(tokenOut.balanceOf(address(step)), 30e18);
  }

  function test_Execute_StablePoolMath_UsesFixedDeadlineOffset() public {
    vm.warp(1000);
    tokenIn.mint(address(step), 10e18);

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(router),
      pool: address(pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 0,
      userData: bytes('')
    });

    uint256[] memory _out = step.execute(abi.encode(_data), 10e18, new uint256[](0));

    assertEq(_out[0], 30e18);
    assertEq(router.lastDeadline(), block.timestamp + 1);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {
  MockBalancerRouterForTest,
  MockBalancerPoolForTest,
  MockBalancerVaultForTest,
  MockBalancerVaultNoHooksSelectorForTest,
  MockBalancerVaultShortHooksReturnForTest
} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';

abstract contract Base is HaiTest {
  BalancerV3StablePoolMathSwapStep internal step;
  ERC20ForTest internal tokenIn;
  ERC20ForTest internal tokenOut;

  function setUp() public virtual {
    step = new BalancerV3StablePoolMathSwapStep();
    tokenIn = new ERC20ForTest();
    tokenOut = new ERC20ForTest();
  }
}

contract Unit_BalancerV3StablePoolMathSwapStep_Guards is Base {
  function test_Revert_Preview_WhenHooksStaticcallFails() public {
    MockBalancerVaultNoHooksSelectorForTest _vault = new MockBalancerVaultNoHooksSelectorForTest();
    MockBalancerRouterForTest _router = new MockBalancerRouterForTest(address(_vault));

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(_router),
      pool: address(0xBEEF),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    vm.expectRevert(BalancerV3StablePoolMathSwapStep.BalancerV3StablePoolMathSwapStep_UnsupportedHooks.selector);
    step.preview(abi.encode(_data), 1e18);
  }

  function test_Revert_Preview_WhenHooksStaticcallReturnsShortData() public {
    MockBalancerVaultShortHooksReturnForTest _vault = new MockBalancerVaultShortHooksReturnForTest();
    MockBalancerRouterForTest _router = new MockBalancerRouterForTest(address(_vault));

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(_router),
      pool: address(0xBEEF),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    vm.expectRevert(BalancerV3StablePoolMathSwapStep.BalancerV3StablePoolMathSwapStep_UnsupportedHooks.selector);
    step.preview(abi.encode(_data), 1e18);
  }

  function test_Preview_RateScalingAndConversionPath() public {
    MockBalancerPoolForTest _pool = new MockBalancerPoolForTest();
    MockBalancerVaultForTest _vault = new MockBalancerVaultForTest(IERC20(address(tokenIn)), IERC20(address(tokenOut)));
    MockBalancerRouterForTest _router = new MockBalancerRouterForTest(address(_vault));

    _vault.setSwapFeePercentage(0);
    _vault.setPoolTokenRates(1e12, 1e12, 2e18, 2e18);
    _vault.setCurrentLiveBalances(1000e18, 1000e18);
    _pool.setOutMultiplier(1e18); // passthrough scaled amount

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(_router),
      pool: address(_pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 1e6);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 1e6);
  }

  function test_Execute_ZeroAmount() public {
    MockBalancerPoolForTest _pool = new MockBalancerPoolForTest();
    MockBalancerVaultForTest _vault = new MockBalancerVaultForTest(IERC20(address(tokenIn)), IERC20(address(tokenOut)));
    MockBalancerRouterForTest _router = new MockBalancerRouterForTest(address(_vault));

    BalancerV3StablePoolMathSwapStep.Data memory _data = BalancerV3StablePoolMathSwapStep.Data({
      router: address(_router),
      pool: address(_pool),
      tokenIn: address(tokenIn),
      tokenOut: address(tokenOut),
      deadlineBuffer: 1 hours,
      userData: bytes('')
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 1;

    uint256[] memory _out = step.execute(abi.encode(_data), 0, _minOuts);
    assertEq(_out.length, 1);
    assertEq(_out[0], 0);
  }
}

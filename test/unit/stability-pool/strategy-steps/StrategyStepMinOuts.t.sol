// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {
  MockERC4626VaultForMinOut,
  MockBeefyVaultForMinOut,
  MockYearnVaultForMinOut,
  MockVeloRouterForMinOut
} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';

abstract contract Base is HaiTest {}

contract Unit_StrategyStep_MinOutErrors is Base {
  function test_Revert_ERC4626WithdrawalStep_InsufficientOutput() public {
    ERC4626WithdrawalStep _step = new ERC4626WithdrawalStep();
    ERC20ForTest _assetToken = new ERC20ForTest();
    MockERC4626VaultForMinOut _vault = new MockERC4626VaultForMinOut(address(_assetToken));
    _vault.mint(address(_step), 10e18);

    ERC4626WithdrawalStep.Data memory _data = ERC4626WithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(_vault),
      assetToken: address(_assetToken)
    });
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 21e18; // actual is 20e18

    vm.expectRevert(ERC4626WithdrawalStep.ERC4626WithdrawalStep_InsufficientOutput.selector);
    _step.execute(abi.encode(_data), 10e18, _minOuts);
  }

  function test_Revert_BeefyVaultWithdrawalStep_InsufficientOutput() public {
    BeefyVaultWithdrawalStep _step = new BeefyVaultWithdrawalStep();
    ERC20ForTest _lpToken = new ERC20ForTest();
    MockBeefyVaultForMinOut _vault = new MockBeefyVaultForMinOut(_lpToken);

    BeefyVaultWithdrawalStep.Data memory _data = BeefyVaultWithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(0xBEEF),
      lpToken: address(_lpToken),
      shareScale: 1e18
    });
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 11e18; // actual is 10e18

    vm.expectRevert(BeefyVaultWithdrawalStep.BeefyVaultWithdrawalStep_InsufficientOutput.selector);
    _step.execute(abi.encode(_data), 10e18, _minOuts);
  }

  function test_Revert_YearnVaultWithdrawalStep_InsufficientOutput() public {
    YearnVaultWithdrawalStep _step = new YearnVaultWithdrawalStep();
    ERC20ForTest _lpToken = new ERC20ForTest();
    MockYearnVaultForMinOut _vault = new MockYearnVaultForMinOut(_lpToken);

    YearnVaultWithdrawalStep.Data memory _data = YearnVaultWithdrawalStep.Data({
      vault: address(_vault),
      vaultToken: address(0x1234),
      lpToken: address(_lpToken),
      shareScale: 1e18
    });
    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 11e18; // actual is 10e18

    vm.expectRevert(YearnVaultWithdrawalStep.YearnVaultWithdrawalStep_InsufficientOutput.selector);
    _step.execute(abi.encode(_data), 10e18, _minOuts);
  }

  function test_Revert_VeloLPRemoveAndSwapStep_InsufficientOutput() public {
    VeloLPRemoveAndSwapStep _step = new VeloLPRemoveAndSwapStep();
    MockVeloRouterForMinOut _router = new MockVeloRouterForMinOut();
    ERC20ForTest _lpToken = new ERC20ForTest();
    ERC20ForTest _tokenA = new ERC20ForTest();
    ERC20ForTest _tokenB = new ERC20ForTest();

    _router.setRemovePerLp(1e18, 0);
    _lpToken.mint(address(_step), 1e18);

    VeloLPRemoveAndSwapStep.Data memory _data = VeloLPRemoveAndSwapStep.Data({
      router: address(_router),
      factory: address(0),
      lpToken: address(_lpToken),
      tokenA: address(_tokenA),
      tokenB: address(_tokenB),
      stableLp: false,
      stableSwap: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 2e18; // actual is 1e18

    vm.expectRevert(VeloLPRemoveAndSwapStep.VeloLPRemoveAndSwapStep_InsufficientOutput.selector);
    _step.execute(abi.encode(_data), 1e18, _minOuts);
  }
}

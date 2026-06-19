// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {MockERC4626Vault} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';

abstract contract Base is HaiTest {
  ERC4626WithdrawalStep step;
  ERC20ForTest assetToken;
  MockERC4626Vault vault;

  function setUp() public virtual {
    step = new ERC4626WithdrawalStep();
    assetToken = new ERC20ForTest();
    vault = new MockERC4626Vault(address(assetToken));
  }
}

contract Unit_ERC4626WithdrawalStep is Base {
  function test_Preview() public view {
    ERC4626WithdrawalStep.Data memory _data =
      ERC4626WithdrawalStep.Data({vault: address(vault), vaultToken: address(vault), assetToken: address(assetToken)});

    uint256[] memory _preview = step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_Execute() public {
    vault.mint(address(step), 10e18);

    ERC4626WithdrawalStep.Data memory _data =
      ERC4626WithdrawalStep.Data({vault: address(vault), vaultToken: address(vault), assetToken: address(assetToken)});

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 20e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(assetToken.balanceOf(address(step)), 20e18);
    assertEq(vault.balanceOf(address(step)), 0);
  }
}

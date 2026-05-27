// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {MockERC4626Vault} from '@test/mocks/stability-pool/strategy-steps/StrategyStepsForTest.sol';
import {ERC4626ShareOracle} from '@contracts/oracles/ERC4626ShareOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';

contract Unit_ERC4626ShareOracle is HaiTest {
  ERC20ForTest internal asset;
  MockERC4626Vault internal vault;
  OracleForTest internal assetOracle;
  ERC4626ShareOracle internal shareOracle;

  function setUp() public {
    asset = new ERC20ForTest();
    vault = new MockERC4626Vault(address(asset));
    assetOracle = new OracleForTest(2000e18);
    shareOracle = new ERC4626ShareOracle(IERC4626(address(vault)), assetOracle, 'vault share / USD');
  }

  function test_GetResultWithValidity_ConvertsAssetPriceToSharePrice() public view {
    (uint256 _result, bool _validity) = shareOracle.getResultWithValidity();

    assertEq(_result, 4000e18);
    assertEq(_validity, true);
  }

  function test_Read_ConvertsAssetPriceToSharePrice() public view {
    assertEq(shareOracle.read(), 4000e18);
  }

  function test_GetResultWithValidity_InvalidAssetOracle() public {
    assetOracle.setPriceAndValidity(2000e18, false);

    (uint256 _result, bool _validity) = shareOracle.getResultWithValidity();

    assertEq(_result, 0);
    assertEq(_validity, false);
  }

  function test_Revert_Read_InvalidAssetOracle() public {
    assetOracle.setPriceAndValidity(0, true);

    vm.expectRevert(IBaseOracle.InvalidPriceFeed.selector);
    shareOracle.read();
  }
}

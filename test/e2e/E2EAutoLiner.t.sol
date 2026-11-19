// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, COLLAT, TKN} from './Common.t.sol';
import {AutoLiner} from '@contracts/utils/AutoLiner.sol';
import {IAutoLiner} from '@interfaces/utils/IAutoLiner.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {RAY} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';

abstract contract E2EAutoLinerTest is BaseUser, Common {
  AutoLiner autoLiner;

  uint256 minDebt = rad(100 ether);
  uint256 gap = rad(50 ether);
  uint256 cooldown = 12 hours;

  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(deployer);
    autoLiner = new AutoLiner(address(safeEngine), IAutoLiner.AutoLinerParams({cooldown: cooldown}));
    autoLiner.initializeCollateralType(
      TKN,
      abi.encode(
        IAutoLiner.AutoLinerCollateralParams({
          ceilingCap: safeEngine.cParams(TKN).debtCeiling, minDebt: minDebt, gap: gap
        })
      )
    );
    safeEngine.addAuthorization(address(autoLiner));
    vm.stopPrank();
  }

  function rad(uint256 _wad) internal pure returns (uint256 _rad) {
    return _wad * RAY;
  }

  function _currentDebt(bytes32 _cType) internal view returns (uint256 _currentDebtRad) {
    ISAFEEngine.SAFEEngineCollateralData memory _cData = safeEngine.cData(_cType);
    return _cData.debtAmount * _cData.accumulatedRate;
  }

  function test_update_ceiling_follow_debt_and_cooldown() public {
    _generateDebt(alice, address(collateralJoin[TKN]), int256(1000 * COLLAT), int256(500 ether));

    uint256 _firstCurrentDebt = _currentDebt(TKN);
    uint256 _firstExpectedCeiling = _firstCurrentDebt + gap;

    autoLiner.updateCeiling(TKN);

    assertEq(safeEngine.cParams(TKN).debtCeiling, _firstExpectedCeiling);

    _generateDebt(alice, address(collateralJoin[TKN]), int256(100 * COLLAT), int256(50 ether));

    uint256 _secondCurrentDebt = _currentDebt(TKN);
    uint256 _secondExpectedCeiling = _secondCurrentDebt + gap;

    vm.expectRevert(IAutoLiner.AutoLiner_Cooldown.selector);
    autoLiner.updateCeiling(TKN);

    vm.warp(block.timestamp + cooldown);
    autoLiner.updateCeiling(TKN);

    assertEq(safeEngine.cParams(TKN).debtCeiling, _secondExpectedCeiling);

    (uint256 _generatedDebt, uint256 _lockedCollateral) = _getSafeStatus(TKN, alice);
    _repayDebtAndExit(alice, address(collateralJoin[TKN]), _lockedCollateral, _generatedDebt);

    vm.expectRevert(IAutoLiner.AutoLiner_Cooldown.selector);
    autoLiner.updateCeiling(TKN);

    vm.warp(block.timestamp + cooldown);
    autoLiner.updateCeiling(TKN);

    assertEq(_currentDebt(TKN), 0);
    assertEq(safeEngine.cParams(TKN).debtCeiling, minDebt);
  }

  function test_update_ceiling_return_cap_when_gap_is_max_uint() public {
    vm.prank(deployer);
    autoLiner.modifyParameters(TKN, 'gap', abi.encode(type(uint256).max));

    uint256 _ceilingCap = autoLiner.cParams(TKN).ceilingCap;
    uint256 _lowerLiveCeiling = rad(1000 ether);

    vm.prank(deployer);
    safeEngine.modifyParameters(TKN, 'debtCeiling', abi.encode(_lowerLiveCeiling));

    autoLiner.updateCeiling(TKN);

    assertEq(autoLiner.cParams(TKN).ceilingCap, _ceilingCap);
    assertEq(safeEngine.cParams(TKN).debtCeiling, _ceilingCap);
  }
}

contract E2EAutoLinerTestDirectUser is DirectUser, E2EAutoLinerTest {}

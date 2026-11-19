// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AutoLiner} from '@contracts/utils/AutoLiner.sol';
import {IAutoLiner} from '@interfaces/utils/IAutoLiner.sol';
import {SAFEEngineForTest, ISAFEEngine} from '@test/mocks/SAFEEngineForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {RAY} from '@libraries/Math.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);
  event UpdateCeiling(bytes32 indexed _cType, uint256 _oldDebtCeiling, uint256 _newDebtCeiling);
  event InitializeCollateralType(bytes32 _cType);

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  bytes32 collateralType = 'collateralType';
  bytes32 unregisteredCollateralType = 'unregisteredCollateralType';

  uint256 minDebt = rad(100 ether);
  uint256 gap = rad(50 ether);
  uint256 cooldown = 12 hours;
  uint256 liveDebtCeiling = rad(1000 ether);

  SAFEEngineForTest safeEngine;
  AutoLiner autoLiner;

  function setUp() public virtual {
    vm.startPrank(deployer);

    safeEngine = new SAFEEngineForTest(
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: type(uint256).max})
    );
    safeEngine.initializeCollateralType(
      collateralType, abi.encode(ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: liveDebtCeiling, debtFloor: 0}))
    );

    autoLiner = new AutoLiner(address(safeEngine), IAutoLiner.AutoLinerParams({cooldown: cooldown}));
    autoLiner.addAuthorization(authorizedAccount);
    autoLiner.initializeCollateralType(
      collateralType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: gap}))
    );
    safeEngine.addAuthorization(address(autoLiner));

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
    vm.stopPrank();
  }

  function rad(uint256 _wad) internal pure returns (uint256 _rad) {
    return _wad * RAY;
  }

  function _mockCurrentDebt(bytes32 _cType, uint256 _debtRad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(0)
      .checked_write(_debtRad / RAY);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(2).checked_write(RAY);
  }

  function _mockLastUpdateTime(bytes32 _cType, uint256 _lastUpdateTime) internal {
    stdstore.target(address(autoLiner)).sig(IAutoLiner.cData.selector).with_key(_cType).depth(0)
      .checked_write(_lastUpdateTime);
  }

  function _setLiveDebtCeiling(bytes32 _cType, uint256 _debtCeiling) internal {
    vm.prank(deployer);
    safeEngine.modifyParameters(_cType, 'debtCeiling', abi.encode(_debtCeiling));
  }
}

contract Unit_AutoLiner_Constructor is Base {
  function test_Set_SafeEngine() public {
    assertEq(address(autoLiner.safeEngine()), address(safeEngine));
  }

  function test_Set_Params() public {
    IAutoLiner.AutoLinerParams memory _params = autoLiner.params();

    assertEq(_params.cooldown, cooldown);
  }

  function test_Set_AuthorizedAccounts() public {
    assertEq(autoLiner.authorizedAccounts(deployer), true);
    assertEq(autoLiner.authorizedAccounts(authorizedAccount), true);
  }

  function test_Revert_NullSafeEngine() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new AutoLiner(address(0), IAutoLiner.AutoLinerParams({cooldown: cooldown}));
  }
}

contract Unit_AutoLiner_ModifyParameters is Base {
  function test_Revert_ModifyParameters_Global_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    autoLiner.modifyParameters('cooldown', abi.encode(cooldown + 1));
  }

  function test_Revert_ModifyParameters_Collateral_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(gap + 1));
  }

  function test_ModifyParameters_Global_Cooldown() public authorized {
    uint256 _newCooldown = cooldown + 1;
    autoLiner.modifyParameters('cooldown', abi.encode(_newCooldown));

    assertEq(autoLiner.params().cooldown, _newCooldown);
  }

  function test_ModifyParameters_Collateral_SetGap_WithoutSeedingCap() public authorized {
    uint256 _newGap = rad(25 ether);

    vm.expectEmit();
    emit ModifyParameters('gap', collateralType, abi.encode(_newGap));

    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(_newGap));

    IAutoLiner.AutoLinerCollateralParams memory _cParams = autoLiner.cParams(collateralType);
    assertEq(_cParams.ceilingCap, liveDebtCeiling);
    assertEq(_cParams.gap, _newGap);
  }

  function test_ModifyParameters_Collateral_SetMinDebt() public authorized {
    uint256 _newMinDebt = rad(200 ether);
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(_newMinDebt));

    assertEq(autoLiner.cParams(collateralType).minDebt, _newMinDebt);
  }

  function test_ModifyParameters_Collateral_SetCeilingCap() public authorized {
    uint256 _newCeilingCap = rad(800 ether);
    autoLiner.modifyParameters(collateralType, 'ceilingCap', abi.encode(_newCeilingCap));

    assertEq(autoLiner.cParams(collateralType).ceilingCap, _newCeilingCap);
  }

  function test_ModifyParameters_Collateral_UnregisteredCollateral() public authorized {
    autoLiner.initializeCollateralType(
      unregisteredCollateralType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: gap}))
    );
    autoLiner.modifyParameters(unregisteredCollateralType, 'gap', abi.encode(gap + 1));

    assertEq(autoLiner.cParams(unregisteredCollateralType).gap, gap + 1);
  }

  function test_Revert_ModifyParameters_Collateral_NotInitialized() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedCType.selector);
    autoLiner.modifyParameters(unregisteredCollateralType, 'gap', abi.encode(gap));
  }

  function test_Revert_ModifyParameters_Collateral_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    autoLiner.modifyParameters(collateralType, 'invalidParam', abi.encode(gap));
  }

  function test_Revert_ModifyParameters_Collateral_NullMinDebt() public authorized {
    vm.expectRevert(IAutoLiner.AutoLiner_NullMinDebt.selector);
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(0));
  }

  function test_Revert_ModifyParameters_Collateral_NullGap() public authorized {
    vm.expectRevert(IAutoLiner.AutoLiner_NullGap.selector);
    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(0));
  }
}

contract Unit_AutoLiner_GetNextDebtCeiling is Base {
  function test_Revert_NotInitializedCollateral() public {
    vm.expectRevert(IAutoLiner.AutoLiner_CollateralTypeNotInitialized.selector);
    autoLiner.getNextDebtCeiling(unregisteredCollateralType);
  }

  function test_Revert_SAFEEngineCollateralNotRegistered() public authorized {
    autoLiner.initializeCollateralType(
      unregisteredCollateralType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: gap}))
    );

    vm.expectRevert(IAutoLiner.AutoLiner_CollateralTypeNotRegistered.selector);
    autoLiner.getNextDebtCeiling(unregisteredCollateralType);
  }

  function test_Return_MinDebt_WhenDebtIs0() public {
    assertEq(autoLiner.getNextDebtCeiling(collateralType), minDebt);
    assertEq(autoLiner.cParams(collateralType).ceilingCap, liveDebtCeiling);
  }

  function test_Return_CurrentDebtPlusGap() public {
    _mockCurrentDebt(collateralType, rad(100 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(150 ether));
  }

  function test_Return_CurrentDebtPlusCollateralGap() public authorized {
    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(rad(10 ether)));
    _mockCurrentDebt(collateralType, rad(100 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(110 ether));
  }

  function test_Return_CollateralMinDebt_WhenDebtIs0() public authorized {
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(rad(150 ether)));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(150 ether));
  }

  function test_Return_Gap_WhenDebtIs0_AndGapIsAboveMinDebt() public authorized {
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(rad(25 ether)));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), gap);
  }

  function test_Return_MinDebt_WhenCurrentDebtPlusGapIsBelowMinDebt() public authorized {
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(rad(200 ether)));
    _mockCurrentDebt(collateralType, rad(100 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(200 ether));
  }

  function test_Return_CeilingCap_WhenGapIsMaxUint() public authorized {
    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(type(uint256).max));
    _mockCurrentDebt(collateralType, rad(100 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), liveDebtCeiling);
  }

  function test_Return_CeilingCap_WhenCurrentDebtIsAboveCap() public authorized {
    autoLiner.modifyParameters(collateralType, 'ceilingCap', abi.encode(rad(200 ether)));
    _mockCurrentDebt(collateralType, rad(250 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(200 ether));
  }

  function test_Return_CeilingCap_WhenCurrentDebtPlusGapExceedsCap() public authorized {
    autoLiner.modifyParameters(collateralType, 'ceilingCap', abi.encode(rad(140 ether)));
    _mockCurrentDebt(collateralType, rad(100 ether));

    assertEq(autoLiner.getNextDebtCeiling(collateralType), rad(140 ether));
  }
}

contract Unit_AutoLiner_UpdateCeiling is Base {
  function test_LowerCeiling() public {
    _mockCurrentDebt(collateralType, rad(100 ether));

    vm.expectEmit();
    emit UpdateCeiling(collateralType, liveDebtCeiling, rad(150 ether));

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, rad(150 ether));
    assertEq(safeEngine.cParams(collateralType).debtCeiling, rad(150 ether));
    assertEq(autoLiner.cParams(collateralType).ceilingCap, liveDebtCeiling);
    assertEq(autoLiner.cData(collateralType).lastUpdateTime, block.timestamp);
  }

  function test_NoOp_DoesNotUpdateLastUpdateTime() public {
    _mockCurrentDebt(collateralType, rad(100 ether));
    autoLiner.updateCeiling(collateralType);

    uint256 _lastUpdateTime = autoLiner.cData(collateralType).lastUpdateTime;
    vm.warp(block.timestamp + 1);

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, rad(150 ether));
    assertEq(autoLiner.cData(collateralType).lastUpdateTime, _lastUpdateTime);
  }

  function test_Revert_Cooldown_OnIncrease() public {
    _mockCurrentDebt(collateralType, rad(100 ether));
    autoLiner.updateCeiling(collateralType);

    _mockCurrentDebt(collateralType, rad(140 ether));

    vm.expectRevert(IAutoLiner.AutoLiner_Cooldown.selector);
    autoLiner.updateCeiling(collateralType);
  }

  function test_Revert_Cooldown_OnDecrease() public {
    _mockCurrentDebt(collateralType, rad(100 ether));
    autoLiner.updateCeiling(collateralType);

    _mockCurrentDebt(collateralType, 0);

    vm.expectRevert(IAutoLiner.AutoLiner_Cooldown.selector);
    autoLiner.updateCeiling(collateralType);
  }

  function test_UpdateCeiling_AfterCooldown_OnIncrease() public {
    _mockCurrentDebt(collateralType, rad(100 ether));
    autoLiner.updateCeiling(collateralType);

    _mockCurrentDebt(collateralType, rad(140 ether));
    vm.warp(block.timestamp + cooldown);

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, rad(190 ether));
    assertEq(safeEngine.cParams(collateralType).debtCeiling, rad(190 ether));
  }

  function test_UpdateCeiling_AfterCooldown_OnDecrease() public {
    _mockCurrentDebt(collateralType, rad(100 ether));
    autoLiner.updateCeiling(collateralType);

    _mockCurrentDebt(collateralType, 0);
    vm.warp(block.timestamp + cooldown);

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, minDebt);
    assertEq(safeEngine.cParams(collateralType).debtCeiling, minDebt);
  }

  function test_UpdateCeiling_FloorToMinDebt_WhenCurrentDebtPlusGapIsBelowMinDebt() public authorized {
    autoLiner.modifyParameters(collateralType, 'minDebt', abi.encode(rad(200 ether)));
    _mockCurrentDebt(collateralType, rad(100 ether));

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, rad(200 ether));
    assertEq(safeEngine.cParams(collateralType).debtCeiling, rad(200 ether));
  }

  function test_UpdateCeiling_ReturnCap_WhenGapIsMaxUint() public authorized {
    autoLiner.modifyParameters(collateralType, 'gap', abi.encode(type(uint256).max));
    uint256 _lowerLiveDebtCeiling = rad(300 ether);
    safeEngine.modifyParameters(collateralType, 'debtCeiling', abi.encode(_lowerLiveDebtCeiling));

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, liveDebtCeiling);
    assertEq(safeEngine.cParams(collateralType).debtCeiling, liveDebtCeiling);
  }

  function test_UpdateCeiling_ClampsToCap() public authorized {
    autoLiner.modifyParameters(collateralType, 'ceilingCap', abi.encode(rad(130 ether)));
    _mockCurrentDebt(collateralType, rad(120 ether));

    uint256 _nextDebtCeiling = autoLiner.updateCeiling(collateralType);

    assertEq(_nextDebtCeiling, rad(130 ether));
    assertEq(safeEngine.cParams(collateralType).debtCeiling, rad(130 ether));
  }

  function test_UpdateCeiling_Revert_NotInitializedCollateral() public {
    vm.expectRevert(IAutoLiner.AutoLiner_CollateralTypeNotInitialized.selector);
    autoLiner.updateCeiling(unregisteredCollateralType);
  }

  function test_UpdateCeiling_Revert_SAFEEngineCollateralNotRegistered() public authorized {
    autoLiner.initializeCollateralType(
      unregisteredCollateralType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: gap}))
    );

    vm.expectRevert(IAutoLiner.AutoLiner_CollateralTypeNotRegistered.selector);
    autoLiner.updateCeiling(unregisteredCollateralType);
  }

  function test_UpdateCeiling_Revert_InactiveCollateral() public authorized {
    autoLiner.modifyParameters(collateralType, 'ceilingCap', abi.encode(0));

    vm.expectRevert(IAutoLiner.AutoLiner_CollateralTypeNotActive.selector);
    autoLiner.updateCeiling(collateralType);
  }
}

contract Unit_AutoLiner_InitializeCollateralType is Base {
  function test_InitializeCollateralType_StoresParams() public authorized {
    bytes32 _newCType = 'newCollateralType';
    IAutoLiner.AutoLinerCollateralParams memory _params =
      IAutoLiner.AutoLinerCollateralParams({ceilingCap: rad(500 ether), minDebt: rad(120 ether), gap: rad(25 ether)});

    vm.expectEmit();
    emit InitializeCollateralType(_newCType);

    autoLiner.initializeCollateralType(_newCType, abi.encode(_params));

    IAutoLiner.AutoLinerCollateralParams memory _storedParams = autoLiner.cParams(_newCType);
    assertEq(_storedParams.ceilingCap, _params.ceilingCap);
    assertEq(_storedParams.minDebt, _params.minDebt);
    assertEq(_storedParams.gap, _params.gap);
  }

  function test_Revert_InitializeCollateralType_NullCeilingCap() public authorized {
    bytes32 _newCType = 'newCollateralType';

    vm.expectRevert(IAutoLiner.AutoLiner_NullCeilingCap.selector);
    autoLiner.initializeCollateralType(
      _newCType, abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: 0, minDebt: minDebt, gap: gap}))
    );
  }

  function test_Revert_InitializeCollateralType_NullMinDebt() public authorized {
    bytes32 _newCType = 'newCollateralType';

    vm.expectRevert(IAutoLiner.AutoLiner_NullMinDebt.selector);
    autoLiner.initializeCollateralType(
      _newCType, abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: 0, gap: gap}))
    );
  }

  function test_Revert_InitializeCollateralType_NullGap() public authorized {
    bytes32 _newCType = 'newCollateralType';

    vm.expectRevert(IAutoLiner.AutoLiner_NullGap.selector);
    autoLiner.initializeCollateralType(
      _newCType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: 0}))
    );
  }

  function test_Revert_InitializeCollateralType_AlreadyInitialized() public authorized {
    vm.expectRevert();
    autoLiner.initializeCollateralType(
      collateralType,
      abi.encode(IAutoLiner.AutoLinerCollateralParams({ceilingCap: liveDebtCeiling, minDebt: minDebt, gap: gap}))
    );
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {EmissionsControllerJobForTest, IEmissionsControllerJob} from '@test/mocks/EmissionsControllerJobForTest.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IEmissionsController mockEmissionsController = IEmissionsController(mockContract('EmissionsController'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  EmissionsControllerJobForTest emissionsControllerJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    emissionsControllerJob = new EmissionsControllerJobForTest(
      address(mockEmissionsController), address(mockStabilityFeeTreasury), REWARD_AMOUNT
    );
    label(address(emissionsControllerJob), 'EmissionsControllerJob');

    emissionsControllerJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(emissionsControllerJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWork(bool _shouldWork) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    emissionsControllerJob.setShouldWork(_shouldWork);
  }
}

contract Unit_EmissionsControllerJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new EmissionsControllerJobForTest(
      address(mockEmissionsController), address(mockStabilityFeeTreasury), REWARD_AMOUNT
    );
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(emissionsControllerJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(emissionsControllerJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_EmissionsController(address _emissionsController)
    public
    happyPath
    mockAsContract(_emissionsController)
  {
    emissionsControllerJob =
      new EmissionsControllerJobForTest(_emissionsController, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(emissionsControllerJob.emissionsController()), _emissionsController);
  }

  function test_Set_ShouldWork() public happyPath {
    assertEq(emissionsControllerJob.shouldWork(), true);
  }

  function test_Revert_Null_EmissionsController() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new EmissionsControllerJobForTest(address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new EmissionsControllerJobForTest(address(mockEmissionsController), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new EmissionsControllerJobForTest(address(mockEmissionsController), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_EmissionsControllerJob_WorkUpdateRewardSplit is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  function _mockValues(bool _shouldWork) internal {
    _mockShouldWork(_shouldWork);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false);

    vm.expectRevert(IJob.NotWorkable.selector);

    emissionsControllerJob.workUpdateRewardSplit();
  }

  function test_Call_EmissionsController_UpdateRewardSplit() public {
    _mockValues(true);
    vm.expectCall(address(mockEmissionsController), abi.encodeCall(mockEmissionsController.updateRewardSplit, ()), 1);

    emissionsControllerJob.workUpdateRewardSplit();
  }

  function test_Emit_Rewarded() public {
    _mockValues(true);

    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    vm.prank(user);
    emissionsControllerJob.workUpdateRewardSplit();
  }
}

contract Unit_EmissionsControllerJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_EmissionsController(address _emissionsController)
    public
    happyPath
    mockAsContract(_emissionsController)
  {
    emissionsControllerJob.modifyParameters('emissionsController', abi.encode(_emissionsController));

    assertEq(address(emissionsControllerJob.emissionsController()), _emissionsController);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    emissionsControllerJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(emissionsControllerJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWork(bool _shouldWork) public happyPath {
    emissionsControllerJob.modifyParameters('shouldWork', abi.encode(_shouldWork));

    assertEq(emissionsControllerJob.shouldWork(), _shouldWork);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    emissionsControllerJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(emissionsControllerJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_EmissionsController() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    emissionsControllerJob.modifyParameters('emissionsController', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    emissionsControllerJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    emissionsControllerJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    emissionsControllerJob.modifyParameters('unrecognizedParam', _data);
  }
}

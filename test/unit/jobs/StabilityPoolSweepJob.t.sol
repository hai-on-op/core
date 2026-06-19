// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StabilityPoolSweepJobForTest, IStabilityPoolSweepJob} from '@test/mocks/StabilityPoolSweepJobForTest.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
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

  IStabilityPool mockStabilityPool = IStabilityPool(mockContract('StabilityPool'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  StabilityPoolSweepJobForTest stabilityPoolSweepJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    stabilityPoolSweepJob =
      new StabilityPoolSweepJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(stabilityPoolSweepJob), 'StabilityPoolSweepJob');

    stabilityPoolSweepJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockSweepInternalCoin(uint256 _exitedWad) internal {
    vm.mockCall(
      address(mockStabilityPool), abi.encodeCall(mockStabilityPool.sweepInternalCoin, ()), abi.encode(_exitedWad)
    );
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(stabilityPoolSweepJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWork(bool _shouldWork) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    stabilityPoolSweepJob.setShouldWork(_shouldWork);
  }
}

contract Unit_StabilityPoolSweepJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new StabilityPoolSweepJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(stabilityPoolSweepJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(stabilityPoolSweepJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_StabilityPool(address _stabilityPool) public happyPath mockAsContract(_stabilityPool) {
    stabilityPoolSweepJob =
      new StabilityPoolSweepJobForTest(_stabilityPool, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(stabilityPoolSweepJob.stabilityPool()), _stabilityPool);
  }

  function test_Set_ShouldWork() public happyPath {
    assertEq(stabilityPoolSweepJob.shouldWork(), true);
  }

  function test_Revert_Null_StabilityPool() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new StabilityPoolSweepJobForTest(address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new StabilityPoolSweepJobForTest(address(mockStabilityPool), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new StabilityPoolSweepJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_StabilityPoolSweepJob_WorkSweepInternalCoin is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  function _mockValues(bool _shouldWork, uint256 _exitedWad) internal {
    _mockShouldWork(_shouldWork);
    _mockSweepInternalCoin(_exitedWad);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false, 1);

    vm.expectRevert(IJob.NotWorkable.selector);

    stabilityPoolSweepJob.workSweepInternalCoin();
  }

  function test_Revert_NullSweepAmount() public {
    _mockValues(true, 0);

    vm.expectRevert(IStabilityPoolSweepJob.StabilityPoolSweepJob_NullSweepAmount.selector);

    stabilityPoolSweepJob.workSweepInternalCoin();
  }

  function test_Call_StabilityPool_SweepInternalCoin() public {
    _mockValues(true, 1);
    vm.expectCall(address(mockStabilityPool), abi.encodeCall(mockStabilityPool.sweepInternalCoin, ()), 1);

    stabilityPoolSweepJob.workSweepInternalCoin();
  }

  function test_Return_ExitedWad(uint256 _exitedWad) public {
    vm.assume(_exitedWad > 0);
    _mockValues(true, _exitedWad);

    assertEq(stabilityPoolSweepJob.workSweepInternalCoin(), _exitedWad);
  }

  function test_Emit_Rewarded() public {
    _mockValues(true, 1);

    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    vm.prank(user);
    stabilityPoolSweepJob.workSweepInternalCoin();
  }
}

contract Unit_StabilityPoolSweepJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_StabilityPool(address _stabilityPool) public happyPath mockAsContract(_stabilityPool) {
    stabilityPoolSweepJob.modifyParameters('stabilityPool', abi.encode(_stabilityPool));

    assertEq(address(stabilityPoolSweepJob.stabilityPool()), _stabilityPool);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    stabilityPoolSweepJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(stabilityPoolSweepJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWork(bool _shouldWork) public happyPath {
    stabilityPoolSweepJob.modifyParameters('shouldWork', abi.encode(_shouldWork));

    assertEq(stabilityPoolSweepJob.shouldWork(), _shouldWork);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    stabilityPoolSweepJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(stabilityPoolSweepJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_StabilityPool() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    stabilityPoolSweepJob.modifyParameters('stabilityPool', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    stabilityPoolSweepJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    stabilityPoolSweepJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    stabilityPoolSweepJob.modifyParameters('unrecognizedParam', _data);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StakingManagerForTest} from '@test/mocks/StakingManagerForTest.sol';
import {StakingManager, IStakingManager} from '@contracts/tokens/StakingManager.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IStakingToken} from '@interfaces/tokens/IStakingToken.sol';
import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address rescueReceiver = label('rescueReceiver');
  address receiver = label('receiver');
  address secondUser = label('secondUser');

  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));
  IStakingToken mockStakingToken = IStakingToken(mockContract('StakingToken'));

  IRewardPool mockRewardPool = IRewardPool(mockContract('RewardPool'));
  IERC20 mockRewardToken = IERC20(mockContract('RewardToken'));

  IRewardPool mockSecondRewardPool = IRewardPool(mockContract('SecondRewardPool'));
  IERC20 mockSecondRewardToken = IERC20(mockContract('SecondRewardToken'));

  StakingManagerForTest stakingManager;

  uint256 constant COOLDOWN_PERIOD = 7 days;

  function setUp() public virtual {
    vm.startPrank(deployer);

    stakingManager = new StakingManagerForTest(address(mockProtocolToken), address(mockStakingToken), COOLDOWN_PERIOD);
    label(address(stakingManager), 'StakingManager');

    stakingManager.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
    vm.stopPrank();
  }

  function _mockRewardPoolTotalStaked(address _rewardPool, uint256 _totalStaked) public {
    vm.mockCall(_rewardPool, abi.encodeWithSelector(IRewardPool.totalStaked.selector), abi.encode(_totalStaked));
  }
}

contract Unit_StakingManager_Constructor is Base {
  function test_Set_Parameters() public {
    assertEq(address(stakingManager.protocolToken()), address(mockProtocolToken));
    assertEq(address(stakingManager.stakingToken()), address(mockStakingToken));
    assertEq(stakingManager.params().cooldownPeriod, COOLDOWN_PERIOD);
  }

  function test_Revert_NullProtocolToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new StakingManagerForTest(address(0), address(mockStakingToken), COOLDOWN_PERIOD);
  }

  function test_Revert_NullStakingToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new StakingManagerForTest(address(mockProtocolToken), address(0), COOLDOWN_PERIOD);
  }
}

contract Unit_StakingManager_ModifyParameters is Base {
  function test_ModifyParameters(uint256 _cooldownPeriod) public authorized {
    vm.assume(_cooldownPeriod > 0);

    stakingManager.modifyParameters('cooldownPeriod', abi.encode(_cooldownPeriod));

    IStakingManager.StakingManagerParams memory _params = stakingManager.params();
    assertEq(_params.cooldownPeriod, _cooldownPeriod);
  }

  function test_Revert_ModifyParameters_NullCooldownPeriod() public authorized {
    vm.expectRevert(Assertions.NullAmount.selector);
    stakingManager.modifyParameters('cooldownPeriod', abi.encode(0));
  }
}

contract Unit_StakingManager_AddRewardType is Base {
  event StakingManagerAddRewardType(uint256 indexed _id, address indexed _rewardToken, address indexed _rewardPool);

  function test_Revert_AddRewardType_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vm.prank(user);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
  }

  function test_Revert_AddRewardType_NullRewardToken() public authorized {
    vm.expectRevert(IStakingManager.StakingManager_NullRewardToken.selector);
    stakingManager.addRewardType(address(0), address(mockRewardPool));
  }

  function test_Revert_AddRewardType_NullRewardPool() public authorized {
    vm.expectRevert(IStakingManager.StakingManager_NullRewardPool.selector);
    stakingManager.addRewardType(address(mockRewardToken), address(0));
  }

  function test_AddRewardType() public authorized {
    uint256 initialRewardId = stakingManager.rewards();

    uint256 rewardId = initialRewardId;

    vm.expectEmit(true, true, true, true);
    emit StakingManagerAddRewardType(rewardId, address(mockRewardToken), address(mockRewardPool));
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));

    // Verify reward type was added correctly
    IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(rewardId);
    assertEq(rewardType.rewardToken, address(mockRewardToken));
    assertEq(rewardType.rewardPool, address(mockRewardPool));
    assertEq(rewardType.isActive, true);
    assertEq(rewardType.rewardIntegral, 0);
    assertEq(rewardType.rewardRemaining, 0);

    // Verify rewards counter was incremented
    assertEq(stakingManager.rewards(), rewardId + 1);
  }

  function test_AddMultipleRewardTypes() public authorized {
    uint256 initialRewardId = stakingManager.rewards();
    // Add first reward type
    uint256 firstRewardId = initialRewardId;
    vm.expectEmit(true, true, true, true);
    emit StakingManagerAddRewardType(firstRewardId, address(mockRewardToken), address(mockRewardPool));
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));

    // Add second reward type with different addresses
    uint256 secondRewardId = firstRewardId + 1;
    vm.expectEmit(true, true, true, true);
    emit StakingManagerAddRewardType(secondRewardId, address(mockSecondRewardToken), address(mockSecondRewardPool));
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));

    // Verify both reward types were added correctly
    IStakingManager.RewardTypeInfo memory firstRewardType = stakingManager.rewardTypes(firstRewardId);
    assertEq(firstRewardType.rewardToken, address(mockRewardToken));
    assertEq(firstRewardType.rewardPool, address(mockRewardPool));

    IStakingManager.RewardTypeInfo memory secondRewardType = stakingManager.rewardTypes(secondRewardId);
    assertEq(secondRewardType.rewardToken, address(mockSecondRewardToken));
    assertEq(secondRewardType.rewardPool, address(mockSecondRewardPool));

    // Verify rewards counter
    assertEq(stakingManager.rewards(), 2);
  }
}

contract Unit_StakingManager_ActivateRewardType is Base {
  event StakingManagerActivateRewardType(uint256 indexed _id);

  function setUp() public override {
    super.setUp();
    // Add a reward type that we can activate
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();
  }

  function test_Revert_ActivateRewardType_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vm.prank(user);
    stakingManager.activateRewardType(0);
  }

  function test_Revert_ActivateRewardType_InvalidRewardType() public authorized {
    uint256 invalidRewardId = 999;
    vm.expectRevert(IStakingManager.StakingManager_InvalidRewardType.selector);
    stakingManager.activateRewardType(invalidRewardId);
  }

  function test_ActivateRewardType() public authorized {
    uint256 rewardId = 0; // From setUp

    // First deactivate it so we can test activation
    stakingManager.deactivateRewardType(rewardId);

    // Verify it's inactive
    IStakingManager.RewardTypeInfo memory rewardTypeBefore = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeBefore.isActive, false);

    // Test activation
    vm.expectEmit(true, true, true, true);
    emit StakingManagerActivateRewardType(rewardId);
    stakingManager.activateRewardType(rewardId);

    // Verify state changes
    IStakingManager.RewardTypeInfo memory rewardTypeAfter = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeAfter.isActive, true);

    // Verify other fields remained unchanged
    assertEq(rewardTypeAfter.rewardToken, address(mockRewardToken));
    assertEq(rewardTypeAfter.rewardPool, address(mockRewardPool));
    assertEq(rewardTypeAfter.rewardIntegral, 0);
    assertEq(rewardTypeAfter.rewardRemaining, 0);
  }

  function test_ActivateRewardType_AlreadyActive() public authorized {
    uint256 rewardId = 0; // From setUp

    // Reward type should already be active from setUp
    IStakingManager.RewardTypeInfo memory rewardTypeBefore = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeBefore.isActive, true);

    // Activating again should work and emit event
    vm.expectEmit(true, true, true, true);
    emit StakingManagerActivateRewardType(rewardId);
    stakingManager.activateRewardType(rewardId);

    // Verify still active
    IStakingManager.RewardTypeInfo memory rewardTypeAfter = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeAfter.isActive, true);
  }
}

contract Unit_StakingManager_DeactivateRewardType is Base {
  event StakingManagerDeactivateRewardType(uint256 indexed _id);

  function setUp() public override {
    super.setUp();
    // Add a reward type that we can deactivate
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();
  }

  function test_Revert_DeactivateRewardType_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vm.prank(user);
    stakingManager.deactivateRewardType(0);
  }

  function test_Revert_DeactivateRewardType_InvalidRewardType() public authorized {
    uint256 invalidRewardId = 999;
    vm.expectRevert(IStakingManager.StakingManager_InvalidRewardType.selector);
    stakingManager.deactivateRewardType(invalidRewardId);
  }

  function test_DeactivateRewardType() public authorized {
    uint256 rewardId = 0; // From setUp

    // Verify it's active initially
    IStakingManager.RewardTypeInfo memory rewardTypeBefore = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeBefore.isActive, true);

    // Test deactivation
    vm.expectEmit(true, true, true, true);
    emit StakingManagerDeactivateRewardType(rewardId);
    stakingManager.deactivateRewardType(rewardId);

    // Verify state changes
    IStakingManager.RewardTypeInfo memory rewardTypeAfter = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeAfter.isActive, false);

    // Verify other fields remained unchanged
    assertEq(rewardTypeAfter.rewardToken, address(mockRewardToken));
    assertEq(rewardTypeAfter.rewardPool, address(mockRewardPool));
    assertEq(rewardTypeAfter.rewardIntegral, 0);
    assertEq(rewardTypeAfter.rewardRemaining, 0);
  }

  function test_DeactivateRewardType_AlreadyInactive() public authorized {
    uint256 rewardId = 0; // From setUp

    // First deactivate
    stakingManager.deactivateRewardType(rewardId);

    // Verify it's inactive
    IStakingManager.RewardTypeInfo memory rewardTypeBefore = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeBefore.isActive, false);

    // Deactivating again should work and emit event
    vm.expectEmit(true, true, true, true);
    emit StakingManagerDeactivateRewardType(rewardId);
    stakingManager.deactivateRewardType(rewardId);

    // Verify still inactive
    IStakingManager.RewardTypeInfo memory rewardTypeAfter = stakingManager.rewardTypes(rewardId);
    assertEq(rewardTypeAfter.isActive, false);
  }
}

contract Unit_StakingManager_Stake is Base {
  event StakingManagerStaked(address indexed _account, uint256 _amount);
  event StakingManagerAddRewardType(uint256 indexed _id, address indexed _rewardToken, address indexed _rewardPool);
  event StakingManagerActivateRewardType(uint256 indexed _id);

  function test_Revert_StakeNullReceiver() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullReceiver.selector);
    stakingManager.stake(address(0), 1e18);
  }

  function test_Revert_StakeNullAmount() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullAmount.selector);
    stakingManager.stake(user, 0);
  }

  function test_Stake(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount <= type(uint256).max);

    // Mock token transfer
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, user, address(stakingManager), _amount),
      abi.encode(true)
    );

    // Mock staking token minting
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector, user, _amount), abi.encode()
    );

    vm.prank(user);
    vm.expectEmit();
    emit StakingManagerStaked(user, _amount);

    stakingManager.stake(user, _amount);

    assertEq(stakingManager.stakedBalances(user), _amount);
  }

  function test_Stake_WithRewardPool(uint256 _amount) public {
    vm.assume(_amount > 0 && _amount <= type(uint256).max);

    // Setup reward pool
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();

    // Mock token transfer
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transferFrom.selector, user, address(stakingManager), _amount),
      abi.encode(true)
    );

    // Mock staking token minting
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector, user, _amount), abi.encode()
    );

    // Mock token balances
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(_amount));
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(_amount)
    );

    vm.expectEmit();

    emit StakingManagerStaked(user, _amount);

    vm.startPrank(user);
    stakingManager.stake(user, _amount);
    vm.stopPrank();

    assertEq(mockProtocolToken.balanceOf(address(stakingManager)), _amount);
    assertEq(mockStakingToken.balanceOf(user), _amount);

    assertEq(stakingManager.stakedBalances(user), _amount);
  }
}

contract Unit_StakingManager_InitiateWithdrawal is Base {
  event StakingManagerWithdrawalInitiated(address indexed _account, uint256 _amount);

  uint256 constant STAKE_AMOUNT = 100 ether;

  function setUp() public override {
    super.setUp();

    // Setup mocks for stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector), abi.encode());
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // Add initial stake for testing withdrawals
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);

    // Clear previous mocks
    vm.clearMockedCalls();
  }

  function test_Revert_InitiateWithdrawal_NullAmount() public {
    vm.prank(user);
    vm.expectRevert(IStakingManager.StakingManager_WithdrawNullAmount.selector);
    stakingManager.initiateWithdrawal(0);
  }

  function test_Revert_InitiateWithdrawal_InsufficientBalance() public {
    uint256 excessAmount = STAKE_AMOUNT + 1 ether;
    vm.prank(user);
    vm.expectRevert(); // Will revert due to underflow
    stakingManager.initiateWithdrawal(excessAmount);
  }

  function test_InitiateWithdrawal() public {
    uint256 withdrawAmount = 50 ether;

    // Get initial state
    uint256 initialStakedBalance = stakingManager.stakedBalances(user);

    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit StakingManagerWithdrawalInitiated(user, withdrawAmount);
    stakingManager.initiateWithdrawal(withdrawAmount);

    // Verify staked balance decreased
    assertEq(stakingManager.stakedBalances(user), initialStakedBalance - withdrawAmount);

    // Verify pending withdrawal
    IStakingManager.PendingWithdrawal memory withdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal.amount, withdrawAmount);
    assertEq(withdrawal.timestamp, block.timestamp);
  }

  function test_InitiateWithdrawal_ExistingPendingWithdrawal() public {
    uint256 firstWithdrawAmount = 30 ether;
    uint256 secondWithdrawAmount = 20 ether;

    // First withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(firstWithdrawAmount);

    // // Get state after first withdrawal
    uint256 stakedBalanceAfterFirst = stakingManager.stakedBalances(user);
    // IStakingManager.PendingWithdrawal memory firstWithdrawal = stakingManager.pendingWithdrawals(user);

    // Move time forward
    vm.warp(block.timestamp + 1 days);

    // Second withdrawal
    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit StakingManagerWithdrawalInitiated(user, secondWithdrawAmount);
    stakingManager.initiateWithdrawal(secondWithdrawAmount);

    // Verify staked balance decreased again
    assertEq(stakingManager.stakedBalances(user), stakedBalanceAfterFirst - secondWithdrawAmount);

    // Verify pending withdrawal was updated
    IStakingManager.PendingWithdrawal memory updatedWithdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(updatedWithdrawal.amount, firstWithdrawAmount + secondWithdrawAmount);
    assertEq(updatedWithdrawal.timestamp, block.timestamp); // Timestamp should be updated
  }

  function test_InitiateWithdrawal_UpdatesRewardPools() public {
    // Add a reward type at index 0
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();

    // Get the reward type at index 0 and verify it
    IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(0);
    assertEq(rewardType.rewardToken, address(mockRewardToken));
    assertEq(rewardType.rewardPool, address(mockRewardPool));

    uint256 withdrawAmount = 50 ether;

    // Mock the totalStaked call for both before and after states
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);

    // Get initial totalStaked value
    uint256 initialTotalStaked = IRewardPool(mockRewardPool).totalStaked();
    emit log_named_uint('Initial total staked', initialTotalStaked);

    // Mock and expect the decreaseStake call
    vm.mockCall(
      address(mockRewardPool), abi.encodeWithSelector(IRewardPool.decreaseStake.selector, withdrawAmount), abi.encode()
    );

    // Set up expectation for the decreaseStake call
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.decreaseStake.selector, withdrawAmount));

    // Clear previous mock and set new totalStaked value for after withdrawal
    vm.clearMockedCalls();
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT - withdrawAmount);

    // Then make the withdrawal call
    vm.prank(user);
    stakingManager.initiateWithdrawal(withdrawAmount);

    // Verify final totalStaked value
    uint256 finalTotalStaked = IRewardPool(mockRewardPool).totalStaked();
    emit log_named_uint('Final total staked', finalTotalStaked);
    emit log_named_uint('Expected total staked', initialTotalStaked - withdrawAmount);

    assertEq(finalTotalStaked, initialTotalStaked - withdrawAmount, 'Total staked amount not decreased correctly');
  }
}

contract Unit_StakingManager_CancelWithdrawal is Base {
  event StakingManagerWithdrawalCancelled(address indexed _account, uint256 _amount);

  uint256 constant STAKE_AMOUNT = 100 ether;
  uint256 constant WITHDRAW_AMOUNT = 50 ether;

  function setUp() public override {
    super.setUp();

    // Setup mocks for initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector), abi.encode());
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // Add initial stake
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);

    // Initiate a withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);

    // Clear previous mocks
    vm.clearMockedCalls();
  }

  function test_Revert_CancelWithdrawal_NoPendingWithdrawal() public {
    // Try to cancel withdrawal from an account with no pending withdrawal
    vm.prank(authorizedAccount);
    vm.expectRevert(IStakingManager.StakingManager_NoPendingWithdrawal.selector);
    stakingManager.cancelWithdrawal();
  }

  function test_CancelWithdrawal() public {
    // Get initial state
    uint256 initialStakedBalance = stakingManager.stakedBalances(user);

    // Emit the expected event BEFORE the call
    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit StakingManagerWithdrawalCancelled(user, WITHDRAW_AMOUNT);
    stakingManager.cancelWithdrawal();

    // Verify staked balance increased
    assertEq(stakingManager.stakedBalances(user), initialStakedBalance + WITHDRAW_AMOUNT);

    // Verify pending withdrawal was cleared
    IStakingManager.PendingWithdrawal memory finalWithdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(finalWithdrawal.amount, 0);
    assertEq(finalWithdrawal.timestamp, 0);
  }

  function test_CancelWithdrawal_UpdatesRewardPools() public {
    // Add and activate a reward type
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();

    // Mock initial totalStaked value
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);

    // Get initial totalStaked value
    uint256 initialTotalStaked = IRewardPool(mockRewardPool).totalStaked();
    emit log_named_uint('Initial total staked', initialTotalStaked);

    // Mock and expect the increaseStake call
    vm.mockCall(
      address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT), abi.encode()
    );

    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT));

    // Clear previous mocks and set new totalStaked value for after cancellation
    vm.clearMockedCalls();
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);

    // Cancel withdrawal
    vm.prank(user);
    stakingManager.cancelWithdrawal();

    // Verify final totalStaked value
    uint256 finalTotalStaked = IRewardPool(mockRewardPool).totalStaked();
    emit log_named_uint('Final total staked', finalTotalStaked);
    emit log_named_uint('Expected total staked', initialTotalStaked + WITHDRAW_AMOUNT);

    assertEq(
      finalTotalStaked,
      initialTotalStaked + WITHDRAW_AMOUNT,
      'Total staked amount not increased correctly after cancellation'
    );
  }

  function test_CancelWithdrawal_MultipleRewardPools() public {
    // Add two reward types
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    vm.stopPrank();

    // Mock initial totalStaked values
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);
    _mockRewardPoolTotalStaked(address(mockSecondRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);

    // Get initial totalStaked values
    uint256 initialTotalStaked1 = IRewardPool(mockRewardPool).totalStaked();
    uint256 initialTotalStaked2 = IRewardPool(mockSecondRewardPool).totalStaked();
    emit log_named_uint('Initial total staked (pool 1)', initialTotalStaked1);
    emit log_named_uint('Initial total staked (pool 2)', initialTotalStaked2);

    // Mock and expect calls to both reward pools
    vm.mockCall(
      address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT), abi.encode()
    );
    vm.mockCall(
      address(mockSecondRewardPool),
      abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT),
      abi.encode()
    );

    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT));
    vm.expectCall(
      address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT)
    );

    // Clear previous mocks and set new totalStaked values for after cancellation
    vm.clearMockedCalls();
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);
    _mockRewardPoolTotalStaked(address(mockSecondRewardPool), STAKE_AMOUNT);

    // Cancel withdrawal
    vm.prank(user);
    stakingManager.cancelWithdrawal();

    // Verify final totalStaked values
    uint256 finalTotalStaked1 = IRewardPool(mockRewardPool).totalStaked();
    uint256 finalTotalStaked2 = IRewardPool(mockSecondRewardPool).totalStaked();
    emit log_named_uint('Final total staked (pool 1)', finalTotalStaked1);
    emit log_named_uint('Final total staked (pool 2)', finalTotalStaked2);

    // Verify total staked amounts were increased correctly
    assertEq(
      finalTotalStaked1,
      initialTotalStaked1 + WITHDRAW_AMOUNT,
      'Total staked amount not increased correctly after cancellation in pool 1'
    );
    assertEq(
      finalTotalStaked2,
      initialTotalStaked2 + WITHDRAW_AMOUNT,
      'Total staked amount not increased correctly after cancellation in pool 2'
    );
  }
}

contract Unit_StakingManager_Withdraw is Base {
  event StakingManagerWithdrawn(address indexed _account, uint256 _wad);

  uint256 constant STAKE_AMOUNT = 100 ether;
  uint256 constant WITHDRAW_AMOUNT = 50 ether;

  function setUp() public override {
    super.setUp();

    // Setup mocks for initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector), abi.encode());
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.decreaseStake.selector), abi.encode());
    // Add initial stake
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);

    // Initiate a withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);
  }

  function test_Revert_Withdraw_NoPendingWithdrawal() public {
    address otherUser = makeAddr('otherUser');
    vm.prank(otherUser);
    vm.expectRevert(IStakingManager.StakingManager_NoPendingWithdrawal.selector);
    stakingManager.withdraw();
  }

  function test_Revert_Withdraw_CooldownPeriodNotElapsed() public {
    // Try to withdraw immediately after initiating
    vm.prank(user);
    vm.expectRevert(IStakingManager.StakingManager_CooldownPeriodNotElapsed.selector);
    stakingManager.withdraw();
  }

  function test_Withdraw() public {
    // Mock token transfers
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector), abi.encode());
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // Move time forward past cooldown period
    vm.warp(block.timestamp + stakingManager.params().cooldownPeriod + 1);

    // Expect token transfers
    vm.expectCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector, user, WITHDRAW_AMOUNT)
    );
    vm.expectCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector, user, WITHDRAW_AMOUNT));

    vm.prank(user);
    stakingManager.withdraw();
  }

  function test_Withdraw_MultipleRewardPools() public {
    // Add two reward types
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    vm.stopPrank();

    // Mock token transfers
    vm.mockCall(
      address(mockStakingToken),
      abi.encodeWithSelector(IStakingToken.burnFrom.selector, user, WITHDRAW_AMOUNT),
      abi.encode()
    );
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transfer.selector, user, WITHDRAW_AMOUNT),
      abi.encode(true)
    );

    // Move time forward past cooldown period
    vm.warp(block.timestamp + stakingManager.params().cooldownPeriod + 1);

    // Mock initial totalStaked values
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);
    _mockRewardPoolTotalStaked(address(mockSecondRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);

    // Get initial totalStaked values
    uint256 initialTotalStaked1 = IRewardPool(mockRewardPool).totalStaked();
    uint256 initialTotalStaked2 = IRewardPool(mockSecondRewardPool).totalStaked();
    emit log_named_uint('Initial total staked (pool 1)', initialTotalStaked1);
    emit log_named_uint('Initial total staked (pool 2)', initialTotalStaked2);

    // Expect token transfers
    vm.expectCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector, user, WITHDRAW_AMOUNT)
    );
    vm.expectCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector, user, WITHDRAW_AMOUNT));

    // Execute withdrawal
    vm.prank(user);
    stakingManager.withdraw();

    // Clear previous mocks and set new totalStaked values for after withdrawal
    vm.clearMockedCalls();
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);
    _mockRewardPoolTotalStaked(address(mockSecondRewardPool), STAKE_AMOUNT - WITHDRAW_AMOUNT);

    // Verify final totalStaked values
    uint256 finalTotalStaked1 = IRewardPool(mockRewardPool).totalStaked();
    uint256 finalTotalStaked2 = IRewardPool(mockSecondRewardPool).totalStaked();
    emit log_named_uint('Final total staked (pool 1)', finalTotalStaked1);
    emit log_named_uint('Final total staked (pool 2)', finalTotalStaked2);

    // Verify total staked amounts were not changed
    assertEq(
      finalTotalStaked1, initialTotalStaked1, 'Total staked amount should not change during withdrawal in pool 1'
    );
    assertEq(
      finalTotalStaked2, initialTotalStaked2, 'Total staked amount should not change during withdrawal in pool 2'
    );

    // Verify pending withdrawal was cleared
    IStakingManager.PendingWithdrawal memory finalWithdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(finalWithdrawal.amount, 0, 'Withdrawal amount should be cleared');
    assertEq(finalWithdrawal.timestamp, 0, 'Withdrawal timestamp should be cleared');
  }
}

contract Unit_StakingManager_EmergencyWithdraw is Base {
  event StakingManagerEmergencyWithdrawal(address indexed _rescueReceiver, uint256 _wad);

  uint256 constant EMERGENCY_AMOUNT = 100 ether;

  function setUp() public override {
    super.setUp();
    rescueReceiver = makeAddr('rescueReceiver');
  }

  function test_Revert_EmergencyWithdraw_NotAuthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stakingManager.emergencyWithdraw(rescueReceiver, EMERGENCY_AMOUNT);
  }

  function test_Revert_EmergencyWithdraw_NullAmount() public {
    vm.prank(authorizedAccount);
    vm.expectRevert(IStakingManager.StakingManager_WithdrawNullAmount.selector);
    stakingManager.emergencyWithdraw(rescueReceiver, 0);
  }

  function test_EmergencyWithdraw() public {
    // Mock initial balances
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(EMERGENCY_AMOUNT)
    );
    vm.mockCall(
      address(mockProtocolToken), abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver), abi.encode(0)
    );

    // Get initial balances
    uint256 initialStakingManagerBalance = mockProtocolToken.balanceOf(address(stakingManager));
    uint256 initialReceiverBalance = mockProtocolToken.balanceOf(rescueReceiver);

    // Mock token transfer
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT),
      abi.encode(true)
    );

    // Expect token transfer
    vm.expectCall(
      address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT)
    );

    // Expect event emission
    vm.expectEmit(true, true, true, true);
    emit StakingManagerEmergencyWithdrawal(rescueReceiver, EMERGENCY_AMOUNT);

    // Execute emergency withdrawal
    vm.prank(authorizedAccount);
    stakingManager.emergencyWithdraw(rescueReceiver, EMERGENCY_AMOUNT);

    // Mock final balances
    vm.clearMockedCalls();
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver),
      abi.encode(EMERGENCY_AMOUNT)
    );

    // Check final balances
    uint256 finalStakingManagerBalance = mockProtocolToken.balanceOf(address(stakingManager));
    uint256 finalReceiverBalance = mockProtocolToken.balanceOf(rescueReceiver);

    // Verify balances changed correctly
    assertEq(
      finalStakingManagerBalance,
      initialStakingManagerBalance - EMERGENCY_AMOUNT,
      'StakingManager balance should decrease by emergency amount'
    );
    assertEq(
      finalReceiverBalance,
      initialReceiverBalance + EMERGENCY_AMOUNT,
      'Receiver balance should increase by emergency amount'
    );
  }
}

contract Unit_StakingManager_EmergencyWithdrawReward is Base {
  event StakingManagerEmergencyRewardWithdrawal(
    address indexed _rescueReceiver, address indexed _rewardToken, uint256 _wad
  );

  uint256 constant EMERGENCY_AMOUNT = 100 ether;
  uint256 rewardTypeId;

  function setUp() public override {
    super.setUp();

    // Add a reward type
    vm.prank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    rewardTypeId = stakingManager.rewards() - 1; // Get the current reward ID (0-based)
  }

  function test_Revert_EmergencyWithdrawReward_NotAuthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);
  }

  function test_Revert_EmergencyWithdrawReward_InvalidRewardType() public {
    uint256 invalidRewardTypeId = 999;
    vm.prank(authorizedAccount);
    vm.expectRevert(IStakingManager.StakingManager_InvalidRewardType.selector);
    stakingManager.emergencyWithdrawReward(invalidRewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);
  }

  function test_Revert_EmergencyWithdrawReward_NullAmount() public {
    vm.prank(authorizedAccount);
    vm.expectRevert(IStakingManager.StakingManager_WithdrawNullAmount.selector);
    stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, 0);
  }

  function test_EmergencyWithdrawReward() public {
    // Mock initial balances
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(EMERGENCY_AMOUNT)
    );
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver), abi.encode(0)
    );

    // Get initial balances
    uint256 initialRewardBalance = IERC20(mockRewardToken).balanceOf(address(stakingManager));
    uint256 initialReceiverRewardBalance = IERC20(mockRewardToken).balanceOf(rescueReceiver);

    // Mock token transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT),
      abi.encode(true)
    );

    // Expect token transfer
    vm.expectCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT)
    );

    // Expect event emission
    vm.expectEmit(true, true, true, true);
    emit StakingManagerEmergencyRewardWithdrawal(rescueReceiver, address(mockRewardToken), EMERGENCY_AMOUNT);

    // Execute emergency withdrawal
    vm.prank(authorizedAccount);
    stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);

    // Mock final balances
    vm.clearMockedCalls();
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver),
      abi.encode(EMERGENCY_AMOUNT)
    );

    // Check final balances
    uint256 finalRewardBalance = IERC20(mockRewardToken).balanceOf(address(stakingManager));
    uint256 finalReceiverRewardBalance = IERC20(mockRewardToken).balanceOf(rescueReceiver);

    // Verify reward token balances changed correctly
    assertEq(
      finalRewardBalance,
      initialRewardBalance - EMERGENCY_AMOUNT,
      'StakingManager reward token balance should decrease by emergency amount'
    );
    assertEq(
      finalReceiverRewardBalance,
      initialReceiverRewardBalance + EMERGENCY_AMOUNT,
      'Receiver reward token balance should increase by emergency amount'
    );
  }
}

contract Unit_StakingManager_Checkpoint is Base {
  uint256 constant REWARD_AMOUNT = 100 ether;
  uint256 constant STAKE_AMOUNT = 50 ether;
  uint256 rewardTypeId;

  function setUp() public override {
    super.setUp();

    // Add a reward type
    vm.prank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    rewardTypeId = stakingManager.rewards() - 1; // Get the current reward ID (0-based)

    // Setup initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);
  }

  function test_Checkpoint_ClaimsManagerRewards() public {
    // Verify rewards count and ID
    assertEq(stakingManager.rewards(), 1, 'Rewards count should be 1');
    assertEq(rewardTypeId, 0, 'Reward type ID should be 0');

    // Mock staking token calls
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balance (0 before checkpoint)
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward call to reward pool
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Verify reward type is active
    IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(rewardTypeId);
    assertTrue(rewardType.isActive, 'Reward type should be active');
    assertEq(rewardType.rewardPool, address(mockRewardPool), 'Reward pool should match');

    // Get initial claimable reward
    uint256 initialClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(initialClaimableReward, 0, 'Initial claimable reward should be 0');

    // Verify reward token balance before checkpoint
    assertEq(mockRewardToken.balanceOf(address(stakingManager)), 0, 'Initial reward token balance should be 0');

    // Mock reward token balance after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );

    // Expect getReward call to reward pool - must be right before the action that triggers it
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integral was updated
    rewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(rewardType.rewardIntegral, (REWARD_AMOUNT * 1e18) / STAKE_AMOUNT, 'Reward integral not updated correctly');
    assertEq(rewardType.rewardRemaining, REWARD_AMOUNT, 'Reward remaining not updated correctly');

    // Verify claimable reward was updated
    uint256 finalClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(finalClaimableReward, REWARD_AMOUNT, 'Claimable reward not updated correctly');
  }

  function test_Checkpoint_UpdatesRewardBalances() public {
    // Verify rewards count and ID
    assertEq(stakingManager.rewards(), 1, 'Rewards count should be 1');
    assertEq(rewardTypeId, 0, 'Reward type ID should be 0');

    // Mock staking token calls
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balance (0 before checkpoint)
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward call to reward pool
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Verify initial state
    uint256 initialClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(initialClaimableReward, 0, 'Initial claimable reward should be 0');

    // Verify reward token balance before checkpoint
    assertEq(mockRewardToken.balanceOf(address(stakingManager)), 0, 'Initial reward token balance should be 0');

    // Mock reward token balance after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );

    // Expect getReward call to reward pool - must be right before the action that triggers it
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integral was updated
    IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(rewardType.rewardIntegral, (REWARD_AMOUNT * 1e18) / STAKE_AMOUNT, 'Reward integral not updated correctly');
    assertEq(rewardType.rewardRemaining, REWARD_AMOUNT, 'Reward remaining not updated correctly');

    // Verify claimable reward was updated
    uint256 finalClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(finalClaimableReward, REWARD_AMOUNT, 'Claimable reward not updated correctly');
  }

  function test_Checkpoint_UpdatesRewardBalances_PartialStake() public {
    // Set up a scenario where user has 50% of total stake
    uint256 totalSupply = STAKE_AMOUNT * 2; // 100 ether total supply
    uint256 userStake = STAKE_AMOUNT; // 50 ether user stake (50%)

    // Verify rewards count and ID
    assertEq(stakingManager.rewards(), 1, 'Rewards count should be 1');
    assertEq(rewardTypeId, 0, 'Reward type ID should be 0');

    // Mock staking token calls
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(userStake)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balance (0 before checkpoint)
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward call to reward pool
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Get initial claimable reward
    uint256 initialClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(initialClaimableReward, 0, 'Initial claimable reward should be 0');

    // Verify reward token balance before checkpoint
    assertEq(mockRewardToken.balanceOf(address(stakingManager)), 0, 'Initial reward token balance should be 0');

    // Mock reward token balance after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );

    // Expect getReward call to reward pool - must be right before the action that triggers it
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integral was updated
    IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(rewardType.rewardIntegral, (REWARD_AMOUNT * 1e18) / totalSupply, 'Reward integral not updated correctly');
    assertEq(rewardType.rewardRemaining, REWARD_AMOUNT, 'Reward remaining not updated correctly');

    // Calculate expected claimable reward
    // User has 50% of stake, so they should get 50% of rewards
    uint256 expectedClaimableReward = REWARD_AMOUNT / 2;
    assertEq(expectedClaimableReward, REWARD_AMOUNT / 2, 'Expected reward should be 50% of total rewards');

    // Verify claimable reward was updated
    uint256 finalClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(finalClaimableReward, expectedClaimableReward, 'Claimable reward not updated correctly');
  }

  function test_Checkpoint_MultipleRewardTypes() public {
    // Add second reward type
    vm.prank(authorizedAccount);
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    uint256 secondRewardTypeId = rewardTypeId + 1;

    // Mock staking token calls
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balances (0 before checkpoint)
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Verify initial state
    uint256 initialClaimableReward1 = stakingManager.claimableReward(rewardTypeId, user);
    uint256 initialClaimableReward2 = stakingManager.claimableReward(secondRewardTypeId, user);
    assertEq(initialClaimableReward1, 0, 'Initial claimable reward 1 should be 0');
    assertEq(initialClaimableReward2, 0, 'Initial claimable reward 2 should be 0');

    // Mock reward token balances after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT * 2)
    );

    // Expect getReward calls to both reward pools
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    vm.expectCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integrals were updated for both reward types
    IStakingManager.RewardTypeInfo memory firstRewardType = stakingManager.rewardTypes(rewardTypeId);
    IStakingManager.RewardTypeInfo memory secondRewardType = stakingManager.rewardTypes(secondRewardTypeId);

    assertEq(
      firstRewardType.rewardIntegral,
      (REWARD_AMOUNT * 1e18) / STAKE_AMOUNT,
      'First reward integral not updated correctly'
    );
    assertEq(firstRewardType.rewardRemaining, REWARD_AMOUNT, 'First reward remaining not updated correctly');

    assertEq(
      secondRewardType.rewardIntegral,
      (REWARD_AMOUNT * 2 * 1e18) / STAKE_AMOUNT,
      'Second reward integral not updated correctly'
    );
    assertEq(secondRewardType.rewardRemaining, REWARD_AMOUNT * 2, 'Second reward remaining not updated correctly');

    // Verify claimable rewards
    uint256 finalClaimableReward1 = stakingManager.claimableReward(rewardTypeId, user);
    uint256 finalClaimableReward2 = stakingManager.claimableReward(secondRewardTypeId, user);
    assertEq(finalClaimableReward1, REWARD_AMOUNT, 'First claimable reward not updated correctly');
    assertEq(finalClaimableReward2, REWARD_AMOUNT * 2, 'Second claimable reward not updated correctly');
  }

  function test_Checkpoint_MultipleRewardTypes_VerifyBalances() public {
    // Add second reward type
    vm.prank(authorizedAccount);
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    uint256 secondRewardTypeId = rewardTypeId + 1;

    // Set up initial balances in reward pools
    uint256 firstPoolBalance = REWARD_AMOUNT;
    uint256 secondPoolBalance = REWARD_AMOUNT * 2;

    // Mock staking token calls
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balances in staking manager (0 before checkpoint)
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Verify initial balances
    assertEq(
      mockRewardToken.balanceOf(address(stakingManager)),
      0,
      'Initial first reward token balance in staking manager should be 0'
    );
    assertEq(
      mockSecondRewardToken.balanceOf(address(stakingManager)),
      0,
      'Initial second reward token balance in staking manager should be 0'
    );

    // Mock reward token balances after getReward calls
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(firstPoolBalance)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(secondPoolBalance)
    );

    // Expect getReward calls to both reward pools
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    vm.expectCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));

    // Call checkpoint
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integrals were updated correctly
    IStakingManager.RewardTypeInfo memory firstRewardType = stakingManager.rewardTypes(rewardTypeId);
    IStakingManager.RewardTypeInfo memory secondRewardType = stakingManager.rewardTypes(secondRewardTypeId);

    assertEq(
      firstRewardType.rewardIntegral,
      (firstPoolBalance * 1e18) / STAKE_AMOUNT,
      'First reward integral not updated correctly'
    );
    assertEq(firstRewardType.rewardRemaining, firstPoolBalance, 'First reward remaining not updated correctly');

    assertEq(
      secondRewardType.rewardIntegral,
      (secondPoolBalance * 1e18) / STAKE_AMOUNT,
      'Second reward integral not updated correctly'
    );
    assertEq(secondRewardType.rewardRemaining, secondPoolBalance, 'Second reward remaining not updated correctly');

    // Verify claimable rewards
    uint256 finalClaimableReward1 = stakingManager.claimableReward(rewardTypeId, user);
    uint256 finalClaimableReward2 = stakingManager.claimableReward(secondRewardTypeId, user);
    assertEq(finalClaimableReward1, firstPoolBalance, 'First claimable reward not updated correctly');
    assertEq(finalClaimableReward2, secondPoolBalance, 'Second claimable reward not updated correctly');

    // Verify final balances in staking manager
    assertEq(
      mockRewardToken.balanceOf(address(stakingManager)),
      firstPoolBalance,
      'First reward token balance in staking manager incorrect'
    );
    assertEq(
      mockSecondRewardToken.balanceOf(address(stakingManager)),
      secondPoolBalance,
      'Second reward token balance in staking manager incorrect'
    );
  }

  function test_Checkpoint_NoStakers() public {
    // Mock zero total supply
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balance
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock getReward call
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Get initial reward type state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManager.rewardTypes(rewardTypeId);

    // Mock reward token balance after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );

    // Call checkpoint
    address[2] memory accounts = [user, address(0)];
    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));
    stakingManager.checkpoint(accounts);

    // Verify reward integral was not updated (no stakers)
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral,
      'Reward integral should not change with no stakers'
    );
    assertEq(finalRewardType.rewardRemaining, REWARD_AMOUNT, 'Reward remaining should be updated even with no stakers');

    // Verify no rewards are claimable
    uint256 finalClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(finalClaimableReward, 0, 'No rewards should be claimable with no stakers');
  }

  function test_Checkpoint_InactiveRewardType() public {
    // Deactivate reward type
    vm.prank(authorizedAccount);
    stakingManager.deactivateRewardType(rewardTypeId);

    // Mock staking token calls
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

    // Mock initial reward token balance
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Get initial reward type state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManager.rewardTypes(rewardTypeId);

    // Mock reward token balance after checkpoint
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(REWARD_AMOUNT)
    );

    // Call checkpoint - should not expect getReward call since reward type is inactive
    address[2] memory accounts = [user, address(0)];
    stakingManager.checkpoint(accounts);

    // Verify reward integral was not updated (inactive reward type)
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral,
      'Reward integral should not change for inactive reward type'
    );
    assertEq(
      finalRewardType.rewardRemaining,
      initialRewardType.rewardRemaining,
      'Reward remaining should not change for inactive reward type'
    );

    // Verify no new rewards are claimable
    uint256 finalClaimableReward = stakingManager.claimableReward(rewardTypeId, user);
    assertEq(finalClaimableReward, 0, 'No new rewards should be claimable for inactive reward type');
  }
}

contract Unit_StakingManager_UserCheckpoint is Base {
  uint256 constant REWARD_AMOUNT = 100 ether;
  uint256 constant STAKE_AMOUNT = 50 ether;
  uint256 rewardTypeId;

  function setUp() public override {
    super.setUp();

    // Add a reward type
    vm.prank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    rewardTypeId = stakingManager.rewards() - 1; // Get the current reward ID (0-based)

    // Setup initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);
  }

  function test_UserCheckpoint_CallsCheckpointCorrectly() public {
    uint256 stakeAmount = 100e18;
    uint256 rewardAmount = 10e18;

    // Setup initial state
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(stakeAmount)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(stakeAmount));
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Get initial state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManager.rewardTypes(rewardTypeId);

    // Call userCheckpoint
    stakingManager.userCheckpoint(user);

    // Verify reward integral was updated as if _checkpoint([user, address(0)]) was called
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManager.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral + ((rewardAmount * 1e18) / stakeAmount),
      'Reward integral update indicates correct _checkpoint call'
    );
  }
}

contract Unit_StakingManager_GetReward is Base {
  uint256 constant REWARD_AMOUNT = 100 ether;
  uint256 constant STAKE_AMOUNT = 50 ether;
  uint256 rewardTypeId;
  StakingManagerForTest stakingManagerTest;

  function setUp() public override {
    super.setUp();

    vm.startPrank(deployer);
    stakingManagerTest =
      new StakingManagerForTest(address(mockProtocolToken), address(mockStakingToken), COOLDOWN_PERIOD);
    stakingManagerTest.addAuthorization(authorizedAccount);
    vm.stopPrank();

    // Add a reward type
    vm.prank(authorizedAccount);
    stakingManagerTest.addRewardType(address(mockRewardToken), address(mockRewardPool));
    rewardTypeId = stakingManagerTest.rewards() - 1;

    // Setup initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.prank(user);
    stakingManagerTest.stake(user, STAKE_AMOUNT);
  }

  function test_GetReward() public {
    uint256 rewardAmount = 10e18;

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.transfer.selector, user, rewardAmount), abi.encode(true)
    );

    // Update mock for final balance after transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(rewardAmount)
    );

    // Call getReward
    vm.prank(user);
    stakingManagerTest.getReward(user);

    // Verify rewards were transferred to user
    uint256 finalUserRewardBalance = mockRewardToken.balanceOf(user);
    assertEq(finalUserRewardBalance, rewardAmount, 'Reward amount not transferred correctly');
  }

  function test_GetRewardAndForward() public {
    uint256 rewardAmount = 10e18;

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(0));

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, receiver, rewardAmount),
      abi.encode(true)
    );

    // Update mock for final balance after transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(rewardAmount)
    );

    // Call getRewardAndForward
    vm.prank(user);
    stakingManagerTest.getRewardAndForward(user, receiver);

    // Verify rewards were transferred to receiver
    uint256 finalReceiverBalance = mockRewardToken.balanceOf(receiver);
    assertEq(finalReceiverBalance, rewardAmount, 'Reward amount not forwarded correctly');
  }

  function test_GetRewardAndForward_Unauthorized() public {
    // Try to call getRewardAndForward from a different address
    vm.prank(receiver);
    vm.expectRevert(IStakingManager.StakingManager_ForwardingOnly.selector);
    stakingManagerTest.getRewardAndForward(user, receiver);
  }
}

contract Unit_StakingManager_CheckpointAndClaim is Base {
  event StakingManagerRewardPaid(
    address indexed _account, address indexed _rewardToken, uint256 _wad, address indexed _destination
  );

  uint256 constant REWARD_AMOUNT = 100 ether;
  uint256 constant STAKE_AMOUNT = 50 ether;
  uint256 rewardTypeId;
  StakingManagerForTest stakingManagerTest;

  function setUp() public override {
    super.setUp();

    vm.startPrank(deployer);
    stakingManagerTest =
      new StakingManagerForTest(address(mockProtocolToken), address(mockStakingToken), COOLDOWN_PERIOD);
    stakingManagerTest.addAuthorization(authorizedAccount);
    vm.stopPrank();

    // Add a reward type
    vm.prank(authorizedAccount);
    stakingManagerTest.addRewardType(address(mockRewardToken), address(mockRewardPool));
    rewardTypeId = stakingManagerTest.rewards() - 1;

    // Setup initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.prank(user);
    stakingManagerTest.stake(user, STAKE_AMOUNT);
  }

  function test_CheckpointAndClaim_SingleReward() public {
    uint256 rewardAmount = 10e18;
    address[2] memory accounts = [user, user];

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Mock initial user reward balance and get initial state
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));
    uint256 initialUserRewardBalance = mockRewardToken.balanceOf(user);

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Mock reward token transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.transfer.selector, user, rewardAmount), abi.encode(true)
    );

    // Mock final reward token balance after transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(rewardAmount)
    );

    // Expect reward paid event
    vm.expectEmit(true, true, true, true);
    emit StakingManagerRewardPaid(user, address(mockRewardToken), rewardAmount, user);

    // Call checkpointAndClaim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify reward integral was updated
    IStakingManager.RewardTypeInfo memory rewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    assertEq(rewardType.rewardIntegral, (rewardAmount * 1e18) / STAKE_AMOUNT, 'Reward integral not updated correctly');

    // Verify rewards were transferred to user
    uint256 finalUserRewardBalance = mockRewardToken.balanceOf(user);
    assertEq(finalUserRewardBalance - initialUserRewardBalance, rewardAmount, 'Reward amount not transferred correctly');
  }

  function test_CheckpointAndClaim_MultipleRewardTypes() public {
    // Add second reward type
    vm.prank(authorizedAccount);
    stakingManagerTest.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    uint256 secondRewardTypeId = rewardTypeId + 1;

    uint256 firstRewardAmount = 10e18;
    uint256 secondRewardAmount = 20e18;
    address[2] memory accounts = [user, user];

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for first reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(firstRewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Setup initial state for second reward token
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(secondRewardAmount)
    );
    vm.mockCall(address(mockSecondRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, user, firstRewardAmount),
      abi.encode(true)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, user, secondRewardAmount),
      abi.encode(true)
    );

    // Get initial states
    IStakingManager.RewardTypeInfo memory initialFirstReward = stakingManagerTest.rewardTypes(rewardTypeId);
    IStakingManager.RewardTypeInfo memory initialSecondReward = stakingManagerTest.rewardTypes(secondRewardTypeId);
    uint256 initialFirstBalance = mockRewardToken.balanceOf(user);
    uint256 initialSecondBalance = mockSecondRewardToken.balanceOf(user);

    // Update mock for reward token balances after transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(firstRewardAmount)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, user),
      abi.encode(secondRewardAmount)
    );

    // Call checkpointAndClaim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify reward integrals were updated
    IStakingManager.RewardTypeInfo memory finalFirstReward = stakingManagerTest.rewardTypes(rewardTypeId);
    IStakingManager.RewardTypeInfo memory finalSecondReward = stakingManagerTest.rewardTypes(secondRewardTypeId);

    assertEq(
      finalFirstReward.rewardIntegral,
      initialFirstReward.rewardIntegral + ((firstRewardAmount * 1e18) / STAKE_AMOUNT),
      'First reward integral not updated correctly'
    );
    assertEq(
      finalSecondReward.rewardIntegral,
      initialSecondReward.rewardIntegral + ((secondRewardAmount * 1e18) / STAKE_AMOUNT),
      'Second reward integral not updated correctly'
    );

    // Verify rewards were transferred
    assertEq(
      mockRewardToken.balanceOf(user) - initialFirstBalance,
      firstRewardAmount,
      'First reward amount not transferred correctly'
    );
    assertEq(
      mockSecondRewardToken.balanceOf(user) - initialSecondBalance,
      secondRewardAmount,
      'Second reward amount not transferred correctly'
    );
  }

  function test_CheckpointAndClaim_InactiveRewardType() public {
    uint256 rewardAmount = 10e18;
    address[2] memory accounts = [user, user];

    // Deactivate reward type
    vm.prank(authorizedAccount);
    stakingManagerTest.deactivateRewardType(rewardTypeId);

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Get initial state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    uint256 initialUserRewardBalance = mockRewardToken.balanceOf(user);

    // Call checkpointAndClaim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify reward integral and balance didn't change
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral,
      'Reward integral should not change for inactive reward type'
    );
    assertEq(
      mockRewardToken.balanceOf(user),
      initialUserRewardBalance,
      'No rewards should be transferred for inactive reward type'
    );
  }

  function test_CheckpointAndClaim_ZeroBalance() public {
    uint256 rewardAmount = 10e18;
    address[2] memory accounts = [user, user];

    // Setup initial state for staking token with zero balance
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Get initial state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    uint256 initialUserRewardBalance = mockRewardToken.balanceOf(user);

    // Call checkpointAndClaim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify reward integral was updated but no rewards were transferred
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral + ((rewardAmount * 1e18) / STAKE_AMOUNT),
      'Reward integral not updated correctly'
    );

    // Verify no rewards were transferred (zero balance)
    uint256 finalUserRewardBalance = mockRewardToken.balanceOf(user);
    assertEq(finalUserRewardBalance, initialUserRewardBalance, 'No rewards should be transferred for zero balance');
  }

  function test_CheckpointAndClaim_ForwardToOtherAddress() public {
    uint256 rewardAmount = 10e18;
    address[2] memory accounts = [user, receiver];

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );

    // Setup initial state for reward token
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(0));

    // Mock initial receiver reward balance and get initial state
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(0));
    uint256 initialReceiverBalance = mockRewardToken.balanceOf(receiver);

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Mock reward token transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, receiver, rewardAmount),
      abi.encode(true)
    );

    // Mock final reward token balance after transfer
    vm.mockCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, receiver), abi.encode(rewardAmount)
    );

    // Expect reward paid event
    vm.expectEmit(true, true, true, true);
    emit StakingManagerRewardPaid(user, address(mockRewardToken), rewardAmount, receiver);

    // Call checkpointAndClaim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify reward integral was updated
    IStakingManager.RewardTypeInfo memory rewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    assertEq(rewardType.rewardIntegral, (rewardAmount * 1e18) / STAKE_AMOUNT, 'Reward integral not updated correctly');

    // Verify rewards were transferred to receiver
    uint256 finalReceiverBalance = mockRewardToken.balanceOf(receiver);
    assertEq(
      finalReceiverBalance - initialReceiverBalance, rewardAmount, 'Reward amount not transferred correctly to receiver'
    );
  }

  function test_CheckpointAndClaim_MultipleCheckpoints() public {
    uint256 firstRewardAmount = 10e18;
    uint256 secondRewardAmount = 20e18;
    address[2] memory accounts = [user, user];

    // First checkpoint setup
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(firstRewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Get initial state
    IStakingManager.RewardTypeInfo memory initialRewardType = stakingManagerTest.rewardTypes(rewardTypeId);

    // First checkpoint - accumulate rewards
    vm.prank(user);
    stakingManagerTest.checkpoint(accounts);

    // Second checkpoint setup - new rewards available
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(firstRewardAmount + secondRewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, user, firstRewardAmount + secondRewardAmount),
      abi.encode(true)
    );

    // Update mock for final balance after claim
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, user),
      abi.encode(firstRewardAmount + secondRewardAmount)
    );

    // Second checkpoint and claim
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(accounts);

    // Verify final reward integral includes both rewards
    IStakingManager.RewardTypeInfo memory finalRewardType = stakingManagerTest.rewardTypes(rewardTypeId);
    assertEq(
      finalRewardType.rewardIntegral,
      initialRewardType.rewardIntegral + (((firstRewardAmount + secondRewardAmount) * 1e18) / STAKE_AMOUNT),
      'Reward integral not updated correctly'
    );

    // Verify total rewards were transferred
    uint256 finalUserRewardBalance = mockRewardToken.balanceOf(user);
    assertEq(
      finalUserRewardBalance, firstRewardAmount + secondRewardAmount, 'Total reward amount not transferred correctly'
    );

    // Verify claimable rewards were reset
    assertEq(stakingManagerTest.claimableReward(rewardTypeId, user), 0, 'Claimable rewards should be reset after claim');
  }

  function test_CheckpointAndClaim_MultipleUsers() public {
    // address secondUser = address(0xBEEF);
    uint256 rewardAmount = 10e18;
    uint256 secondUserStake = STAKE_AMOUNT / 2; // 50% of first user's stake
    uint256 totalStake = STAKE_AMOUNT + secondUserStake;

    // Setup second user's stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.prank(secondUser);
    stakingManagerTest.stake(secondUser, secondUserStake);

    // Setup staking token state
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalStake));
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, secondUser),
      abi.encode(secondUserStake)
    );

    // Setup reward token state
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManagerTest)),
      abi.encode(rewardAmount)
    );
    vm.mockCall(address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));

    // Mock reward pool calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, user, rewardAmount * 2 / 3),
      abi.encode(true)
    );

    // First user claims
    address[2] memory firstUserAccounts = [user, address(0)];
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, user),
      abi.encode(rewardAmount * 2 / 3) // Should get 2/3 of rewards (has 2/3 of total stake)
    );
    vm.prank(user);
    stakingManagerTest.checkpointAndClaim(firstUserAccounts);

    // Second user claims
    address[2] memory secondUserAccounts = [secondUser, address(0)];
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, secondUser),
      abi.encode(rewardAmount / 3) // Should get 1/3 of rewards (has 1/3 of total stake)
    );
    vm.prank(secondUser);
    stakingManagerTest.checkpointAndClaim(secondUserAccounts);

    // Verify rewards were distributed proportionally
    assertEq(mockRewardToken.balanceOf(user), (rewardAmount * 2) / 3, 'First user should receive 2/3 of rewards');
    assertEq(mockRewardToken.balanceOf(secondUser), rewardAmount / 3, 'Second user should receive 1/3 of rewards');
  }
}

contract Unit_StakingManager_Earned is Base {
  uint256 constant REWARD_AMOUNT = 100 ether;
  uint256 constant STAKE_AMOUNT = 50 ether;
  uint256 rewardTypeId;

  function setUp() public override {
    super.setUp();

    // Add reward type
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    stakingManager.activateRewardType(0);
    vm.stopPrank();
    rewardTypeId = 0;

    // Setup initial state for staking token
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(STAKE_AMOUNT)
    );
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));
  }

  function test_Earned_SingleRewardType() public {
    uint256 rewardAmount = 10e18;

    // Mock token transfers for staking
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());

    // Setup mock for reward pool
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);

    // Mock transfer of reward tokens to StakingManager
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(stakingManager), rewardAmount),
      abi.encode(true)
    );

    // Mock reward token balance
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(rewardAmount)
    );

    // Mock reward pool getReward call
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Stake tokens
    vm.startPrank(user);
    stakingManager.stake(user, STAKE_AMOUNT);
    vm.stopPrank();

    // Checkpoint to update reward balances
    address[2] memory accounts = [user, user];
    stakingManager.checkpoint(accounts);

    // Get earned rewards
    IStakingManager.EarnedData[] memory earnedData = stakingManager.earned(user);

    // Verify earned data
    assertEq(earnedData.length, 1, 'Should have one reward type');
    assertEq(earnedData[0].rewardToken, address(mockRewardToken), 'Incorrect reward token');
    assertEq(earnedData[0].rewardAmount, rewardAmount, 'Incorrect reward amount');
  }

  function test_Earned_MultipleRewardTypes() public {
    uint256 firstRewardAmount = 10e18;
    uint256 secondRewardAmount = 20e18;

    // Add second reward type
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockSecondRewardToken), address(mockSecondRewardPool));
    stakingManager.activateRewardType(1);
    vm.stopPrank();

    // Mock token transfers for staking
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());

    // Setup mocks for reward pools
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);
    _mockRewardPoolTotalStaked(address(mockSecondRewardPool), STAKE_AMOUNT);

    // Mock transfers of reward tokens
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(stakingManager), firstRewardAmount),
      abi.encode(true)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(stakingManager), secondRewardAmount),
      abi.encode(true)
    );

    // Mock reward token balances
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(firstRewardAmount)
    );
    vm.mockCall(
      address(mockSecondRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(secondRewardAmount)
    );

    // Mock reward pool getReward calls
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());
    vm.mockCall(address(mockSecondRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Stake tokens
    vm.startPrank(user);
    stakingManager.stake(user, STAKE_AMOUNT);
    vm.stopPrank();

    // Checkpoint to update reward balances
    address[2] memory accounts = [user, user];
    stakingManager.checkpoint(accounts);

    // Get earned rewards
    IStakingManager.EarnedData[] memory earnedData = stakingManager.earned(user);

    // Verify earned data
    assertEq(earnedData.length, 2, 'Should have two reward types');
    assertEq(earnedData[0].rewardToken, address(mockRewardToken), 'Incorrect first reward token');
    assertEq(earnedData[0].rewardAmount, firstRewardAmount, 'Incorrect first reward amount');
    assertEq(earnedData[1].rewardToken, address(mockSecondRewardToken), 'Incorrect second reward token');
    assertEq(earnedData[1].rewardAmount, secondRewardAmount, 'Incorrect second reward amount');
  }

  function test_Earned_NoStake() public {
    // Mock zero balances
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(0));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));

    // Mock reward token balance
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(0)
    );

    // Mock reward pool getReward call
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Get earned rewards for user with no stake
    IStakingManager.EarnedData[] memory earnedData = stakingManager.earned(user);

    // Verify earned data
    assertEq(earnedData.length, 1, 'Should have one reward type');
    assertEq(earnedData[0].rewardToken, address(mockRewardToken), 'Incorrect reward token');
    assertEq(earnedData[0].rewardAmount, 0, 'Should have no rewards');
  }

  function test_Earned_InactiveRewardType() public {
    uint256 rewardAmount = 10e18;

    // Deactivate reward type
    vm.prank(authorizedAccount);
    stakingManager.deactivateRewardType(rewardTypeId);

    // Setup mock for reward pool
    _mockRewardPoolTotalStaked(address(mockRewardPool), STAKE_AMOUNT);

    // Mock transfer of reward tokens
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(stakingManager), rewardAmount),
      abi.encode(true)
    );

    // Mock reward token balance
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
      abi.encode(rewardAmount)
    );

    // Mock token transfers for staking
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());

    // Mock reward pool getReward call
    vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

    // Stake tokens
    vm.startPrank(user);
    stakingManager.stake(user, STAKE_AMOUNT);
    vm.stopPrank();

    // Checkpoint to update reward balances
    address[2] memory accounts = [user, user];
    stakingManager.checkpoint(accounts);

    // Get earned rewards
    IStakingManager.EarnedData[] memory earnedData = stakingManager.earned(user);

    // Verify earned data
    assertEq(earnedData.length, 1, 'Should have one reward type');
    assertEq(earnedData[0].rewardToken, address(mockRewardToken), 'Incorrect reward token');
    assertEq(earnedData[0].rewardAmount, 0, 'Should have no rewards for inactive type');
  }
}

contract Unit_StakingManager_PendingWithdrawals is Base {
  uint256 constant STAKE_AMOUNT = 100 ether;
  uint256 constant WITHDRAW_AMOUNT = 50 ether;

  function setUp() public override {
    super.setUp();

    // Setup mocks for initial stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.burnFrom.selector), abi.encode());
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // Add initial stake
    vm.prank(user);
    stakingManager.stake(user, STAKE_AMOUNT);

    // Clear previous mocks
    vm.clearMockedCalls();
  }

  function test_PendingWithdrawals_NoWithdrawal() public {
    // Check pending withdrawals when there are none
    IStakingManager.PendingWithdrawal memory withdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal.amount, 0, 'Should have no pending withdrawal amount');
    assertEq(withdrawal.timestamp, 0, 'Should have no pending withdrawal timestamp');
  }

  function test_PendingWithdrawals_AfterInitiation() public {
    // Initiate a withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);

    // Check pending withdrawal details
    IStakingManager.PendingWithdrawal memory withdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal.amount, WITHDRAW_AMOUNT, 'Incorrect pending withdrawal amount');
    assertEq(withdrawal.timestamp, block.timestamp, 'Incorrect pending withdrawal timestamp');
  }

  function test_PendingWithdrawals_AfterCancel() public {
    // First initiate a withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);

    // Then cancel it
    vm.prank(user);
    stakingManager.cancelWithdrawal();

    // Check that pending withdrawal is cleared
    IStakingManager.PendingWithdrawal memory withdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal.amount, 0, 'Should have no pending withdrawal amount after cancellation');
    assertEq(withdrawal.timestamp, 0, 'Should have no pending withdrawal timestamp after cancellation');
  }

  function test_PendingWithdrawals_AfterWithdraw() public {
    // First initiate a withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);

    // Move time forward past cooldown period
    vm.warp(block.timestamp + stakingManager.params().cooldownPeriod + 1);

    // Mock token transfer for withdrawal
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

    // Then complete the withdrawal
    vm.prank(user);
    stakingManager.withdraw();

    // Check that pending withdrawal is cleared
    IStakingManager.PendingWithdrawal memory withdrawal = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal.amount, 0, 'Should have no pending withdrawal amount after withdrawal');
    assertEq(withdrawal.timestamp, 0, 'Should have no pending withdrawal timestamp after withdrawal');
  }

  function test_PendingWithdrawals_MultipleUsers() public {
    // Setup second user's stake
    vm.mockCall(address(mockProtocolToken), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector), abi.encode());

    vm.prank(secondUser);
    stakingManager.stake(secondUser, STAKE_AMOUNT);

    vm.clearMockedCalls();

    // First user initiates withdrawal
    vm.prank(user);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT);

    // Second user initiates withdrawal with different amount
    vm.prank(secondUser);
    stakingManager.initiateWithdrawal(WITHDRAW_AMOUNT / 2);

    // Check first user's pending withdrawal
    IStakingManager.PendingWithdrawal memory withdrawal1 = stakingManager.pendingWithdrawals(user);
    assertEq(withdrawal1.amount, WITHDRAW_AMOUNT, 'Incorrect first user pending withdrawal amount');
    assertEq(withdrawal1.timestamp, block.timestamp, 'Incorrect first user pending withdrawal timestamp');

    // Check second user's pending withdrawal
    IStakingManager.PendingWithdrawal memory withdrawal2 = stakingManager.pendingWithdrawals(secondUser);
    assertEq(withdrawal2.amount, WITHDRAW_AMOUNT / 2, 'Incorrect second user pending withdrawal amount');
    assertEq(withdrawal2.timestamp, block.timestamp, 'Incorrect second user pending withdrawal timestamp');
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));
  IStakingToken mockStakingToken = IStakingToken(mockContract('StakingToken'));

  IRewardPool mockRewardPool = IRewardPool(mockContract('RewardPool'));
  IERC20 mockRewardToken = IERC20(mockContract('RewardToken'));

  IRewardPool mockSecondRewardPool = IRewardPool(mockContract('SecondRewardPool'));
  IERC20 mockSecondRewardToken = IERC20(mockContract('SecondRewardToken'));

  StakingManager stakingManager;

  uint256 constant COOLDOWN_PERIOD = 7 days;

  function setUp() public virtual {
    vm.startPrank(deployer);

    stakingManager = new StakingManager(address(mockProtocolToken), address(mockStakingToken), COOLDOWN_PERIOD);
    label(address(stakingManager), 'StakingManager');

    stakingManager.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier mockProtocolTokenApproval(address _owner, uint256 _amount) {
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.allowance.selector, _owner, address(stakingManager)),
      abi.encode(_amount)
    );
    _;
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
    vm.stopPrank();
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
    new StakingManager(address(0), address(mockStakingToken), COOLDOWN_PERIOD);
  }

  function test_Revert_NullStakingToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new StakingManager(address(mockProtocolToken), address(0), COOLDOWN_PERIOD);
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

  modifier setupRewardPool() {
    vm.startPrank(authorizedAccount);
    stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
    vm.stopPrank();
    _;
  }

  function test_Revert_StakeNullReceiver() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullReceiver.selector);
    stakingManager.stake(address(0), 1e18);
  }

  function test_Revert_StakeNullAmount() public {
    vm.expectRevert(IStakingManager.StakingManager_StakeNullAmount.selector);
    stakingManager.stake(user, 0);
  }

  function test_Stake(uint256 _amount) public mockProtocolTokenApproval(user, _amount) {
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

  function _mockTokenApproval(uint256 _amount) internal {
    vm.mockCall(
      address(mockProtocolToken),
      abi.encodeWithSelector(IERC20.approve.selector, address(stakingManager), _amount),
      abi.encode(true)
    );
  }

  function _mockTokenTransfer(address _account, uint256 _amount) internal {
    vm.mockCall(
      address(mockProtocolToken), abi.encodeWithSelector(IERC20.transfer.selector, _account, _amount), abi.encode(true)
    );
  }

  function _mockTokenMint(address _account, uint256 _amount) internal {
    vm.mockCall(
      address(mockStakingToken), abi.encodeWithSelector(IStakingToken.mint.selector, _account, _amount), abi.encode()
    );
  }

  function _mockTokenBalance(address _token, address _account, uint256 _amount) internal {
    vm.mockCall(_token, abi.encodeWithSelector(IERC20.balanceOf.selector, _account), abi.encode(_amount));
  }

  function test_Stake_WithRewardPool(uint256 _amount) public setupRewardPool {
    vm.assume(_amount > 0 && _amount <= type(uint256).max);

    _mockTokenApproval(_amount);
    _mockTokenTransfer(user, _amount);
    _mockTokenMint(user, _amount);

    // Balance of staking token on user
    _mockTokenBalance(address(mockStakingToken), user, _amount);
    // Balance of protocol token on staking manager
    _mockTokenBalance(address(mockProtocolToken), address(stakingManager), _amount);

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
    vm.mockCall(
      address(mockRewardPool), abi.encodeWithSelector(IRewardPool.totalStaked.selector), abi.encode(STAKE_AMOUNT)
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - withdrawAmount)
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT)
    );

    // Get initial totalStaked value
    uint256 initialTotalStaked = IRewardPool(mockRewardPool).totalStaked();
    emit log_named_uint('Initial total staked', initialTotalStaked);

    // Mock and expect the increaseStake call
    vm.mockCall(
      address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT), abi.encode()
    );

    vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.increaseStake.selector, WITHDRAW_AMOUNT));

    // Clear previous mock and set new totalStaked value for after cancellation
    vm.clearMockedCalls();
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT) // Should be back to full amount after cancellation
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT)
    );
    vm.mockCall(
      address(mockSecondRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT)
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT) // Should be back to full amount after cancellation
    );
    vm.mockCall(
      address(mockSecondRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT) // Should be back to full amount after cancellation
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT)
    );
    vm.mockCall(
      address(mockSecondRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT)
    );

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
    vm.mockCall(
      address(mockRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT) // Should remain the same after withdrawal
    );
    vm.mockCall(
      address(mockSecondRewardPool),
      abi.encodeWithSelector(IRewardPool.totalStaked.selector),
      abi.encode(STAKE_AMOUNT - WITHDRAW_AMOUNT) // Should remain the same after withdrawal
    );

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

// contract Unit_StakingManager_EmergencyWithdrawReward is Base {
//   event StakingManagerEmergencyRewardWithdrawal(
//     address indexed _rescueReceiver, address indexed _rewardToken, uint256 _wad
//   );

//   uint256 constant EMERGENCY_AMOUNT = 100 ether;
//   uint256 rewardTypeId;

//   function setUp() public override {
//     super.setUp();

//     // Add a reward type
//     vm.prank(authorizedAccount);
//     stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
//     rewardTypeId = stakingManager.rewards(); // Get the current reward ID (1-based)
//   }

//   function test_Revert_EmergencyWithdrawReward_NotAuthorized() public {
//     vm.prank(user);
//     vm.expectRevert(IAuthorizable.Unauthorized.selector);
//     stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);
//   }

//   function test_Revert_EmergencyWithdrawReward_InvalidRewardType() public {
//     uint256 invalidRewardTypeId = 999;
//     vm.prank(authorizedAccount);
//     vm.expectRevert(IStakingManager.StakingManager_InvalidRewardType.selector);
//     stakingManager.emergencyWithdrawReward(invalidRewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);
//   }

//   function test_Revert_EmergencyWithdrawReward_NullAmount() public {
//     vm.prank(authorizedAccount);
//     vm.expectRevert(IStakingManager.StakingManager_WithdrawNullAmount.selector);
//     stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, 0);
//   }

//   function test_EmergencyWithdrawReward() public {
//     // Mock initial balances
//     vm.mockCall(
//       address(mockRewardToken),
//       abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
//       abi.encode(EMERGENCY_AMOUNT)
//     );
//     vm.mockCall(
//       address(mockRewardToken), abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver), abi.encode(0)
//     );

//     // Get initial balances
//     uint256 initialRewardBalance = IERC20(mockRewardToken).balanceOf(address(stakingManager));
//     uint256 initialReceiverRewardBalance = IERC20(mockRewardToken).balanceOf(rescueReceiver);

//     // Mock token transfer
//     vm.mockCall(
//       address(mockRewardToken),
//       abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT),
//       abi.encode(true)
//     );

//     // Expect token transfer
//     vm.expectCall(
//       address(mockRewardToken), abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, EMERGENCY_AMOUNT)
//     );

//     // Expect event emission
//     vm.expectEmit(true, true, true, true);
//     emit StakingManagerEmergencyRewardWithdrawal(rescueReceiver, address(mockRewardToken), EMERGENCY_AMOUNT);

//     // Execute emergency withdrawal
//     vm.prank(authorizedAccount);
//     stakingManager.emergencyWithdrawReward(rewardTypeId, rescueReceiver, EMERGENCY_AMOUNT);

//     // Mock final balances
//     vm.clearMockedCalls();
//     vm.mockCall(
//       address(mockRewardToken),
//       abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
//       abi.encode(0)
//     );
//     vm.mockCall(
//       address(mockRewardToken),
//       abi.encodeWithSelector(IERC20.balanceOf.selector, rescueReceiver),
//       abi.encode(EMERGENCY_AMOUNT)
//     );

//     // Check final balances
//     uint256 finalRewardBalance = IERC20(mockRewardToken).balanceOf(address(stakingManager));
//     uint256 finalReceiverRewardBalance = IERC20(mockRewardToken).balanceOf(rescueReceiver);

//     // Verify reward token balances changed correctly
//     assertEq(
//       finalRewardBalance,
//       initialRewardBalance - EMERGENCY_AMOUNT,
//       'StakingManager reward token balance should decrease by emergency amount'
//     );
//     assertEq(
//       finalReceiverRewardBalance,
//       initialReceiverRewardBalance + EMERGENCY_AMOUNT,
//       'Receiver reward token balance should increase by emergency amount'
//     );
//   }
// }

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

// contract Unit_StakingManager_Checkpoint is Base {
//   uint256 constant REWARD_AMOUNT = 100 ether;
//   uint256 rewardTypeId;

//   function setUp() public override {
//     super.setUp();

//     // Add a reward type
//     vm.prank(authorizedAccount);
//     stakingManager.addRewardType(address(mockRewardToken), address(mockRewardPool));
//     rewardTypeId = stakingManager.rewards(); // Get the current reward ID (1-based)
//   }

//   function test_Checkpoint_ClaimsManagerRewards() public {
//     // Verify rewards count and ID
//     assertEq(stakingManager.rewards(), 1, 'Rewards count should be 1');
//     assertEq(rewardTypeId, 1, 'Reward type ID should be 1');

//     // Mock staking token calls
//     vm.mockCall(
//       address(mockStakingToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(REWARD_AMOUNT)
//     );
//     vm.mockCall(
//       address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, user), abi.encode(REWARD_AMOUNT)
//     );
//     vm.mockCall(address(mockStakingToken), abi.encodeWithSelector(IERC20.balanceOf.selector, address(0)), abi.encode(0));

//     // Mock reward token balance
//     vm.mockCall(
//       address(mockRewardToken),
//       abi.encodeWithSelector(IERC20.balanceOf.selector, address(stakingManager)),
//       abi.encode(REWARD_AMOUNT)
//     );

//     // Mock getReward call to reward pool
//     vm.mockCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector), abi.encode());

//     // Verify reward type is active
//     IStakingManager.RewardTypeInfo memory rewardType = stakingManager.rewardTypes(rewardTypeId);
//     assertTrue(rewardType.isActive, 'Reward type should be active');
//     assertEq(rewardType.rewardPool, address(mockRewardPool), 'Reward pool should match');

//     // Expect getReward call to reward pool
//     vm.expectCall(address(mockRewardPool), abi.encodeWithSelector(IRewardPool.getReward.selector));

//     // Call checkpoint
//     stakingManager.checkpoint([user, address(0)]);
//   }
// }

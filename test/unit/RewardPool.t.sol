// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {RewardPool, IRewardPool} from '@contracts/tokens/RewardPool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {VmSafe} from 'forge-std/Vm.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address factoryDeployer = label('factoryDeployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IStakingManager mockStakingManager = IStakingManager(mockContract('StakingManager'));
  IERC20 mockRewardToken = IERC20(mockContract('RewardToken'));

  RewardPool rewardPool;

  // RewardPool params
  uint256 constant DURATION = 365 days;
  uint256 constant NEW_REWARD_RATIO = 420;

  IRewardPool.RewardPoolParams rewardPoolParams;

  function setUp() public virtual {
    vm.startPrank(deployer);

    rewardPoolParams = IRewardPool.RewardPoolParams({
      stakingManager: address(mockStakingManager),
      duration: DURATION,
      newRewardRatio: NEW_REWARD_RATIO
    });

    rewardPool = new RewardPool(
      address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO, address(factoryDeployer)
    );
    label(address(rewardPool), 'RewardPool');

    rewardPool.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier setupStakingRewards(uint256 _stakeAmount, uint256 _rewardAmount) {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake some amount
    rewardPool.stake(_stakeAmount);
    assertEq(rewardPool.totalStaked(), _stakeAmount);

    // Mock reward token transfer to the pool
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    // Mock balanceOf call
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(rewardPool)),
      abi.encode(_rewardAmount)
    );

    // Notify reward amount
    rewardPool.notifyRewardAmount(_rewardAmount);

    // Advance time to accumulate rewards
    vm.warp(block.timestamp + 7 days);

    _;
  }
}

contract Unit_RewardPool_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Set_RewardToken() public happyPath {
    assertEq(address(rewardPool.rewardToken()), address(mockRewardToken));
  }

  function test_Set_StakingManager() public happyPath {
    assertEq(rewardPool.params().stakingManager, address(mockStakingManager));
  }

  function test_Set_Duration() public happyPath {
    assertEq(rewardPool.params().duration, DURATION);
  }

  function test_Set_NewRewardRatio() public happyPath {
    assertEq(rewardPool.params().newRewardRatio, NEW_REWARD_RATIO);
  }

  function test_Revert_NullAddress_RewardToken() public {
    vm.expectRevert(IRewardPool.RewardPool_InvalidRewardToken.selector);
    new RewardPool(address(0), address(mockStakingManager), DURATION, NEW_REWARD_RATIO, address(deployer));
  }

  function test_Revert_NullAddress_StakingManager() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new RewardPool(address(mockRewardToken), address(0), DURATION, NEW_REWARD_RATIO, address(deployer));
  }

  function test_Revert_NullAmount_Duration() public {
    vm.expectRevert(Assertions.NullAmount.selector);
    new RewardPool(address(mockRewardToken), address(mockStakingManager), 0, NEW_REWARD_RATIO, address(deployer));
  }

  function test_Revert_NullAmount_NewRewardRatio() public {
    vm.expectRevert(Assertions.NullAmount.selector);
    new RewardPool(address(mockRewardToken), address(mockStakingManager), DURATION, 0, address(deployer));
  }
}

contract Unit_RewardPool_Stake is Base {
  event RewardPoolStaked(address indexed _account, uint256 _amount);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.stake(1);
  }

  function test_Revert_NullAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_StakeNullAmount.selector);
    rewardPool.stake(0);
  }

  function test_Stake(uint256 _amount) public happyPath {
    vm.assume(_amount > 0);

    vm.expectEmit();
    emit RewardPoolStaked(authorizedAccount, _amount);

    rewardPool.stake(_amount);
    assertEq(rewardPool.totalStaked(), _amount);
  }
}

contract Unit_RewardPool_IncreaseStake is Base {
  event RewardPoolIncreaseStake(address indexed _account, uint256 _amount);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.increaseStake(1);
  }

  function test_Revert_NullAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_IncreaseStakeNullAmount.selector);
    rewardPool.increaseStake(0);
  }

  function test_IncreaseStake(uint256 _amount) public happyPath {
    vm.assume(_amount > 0);

    vm.expectEmit();
    emit RewardPoolIncreaseStake(authorizedAccount, _amount);

    rewardPool.increaseStake(_amount);
    assertEq(rewardPool.totalStaked(), _amount);
  }
}

contract Unit_RewardPool_DecreaseStake is Base {
  event RewardPoolDecreaseStake(address indexed _account, uint256 _amount);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.decreaseStake(1);
  }

  function test_Revert_NullAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_DecreaseStakeNullAmount.selector);
    rewardPool.decreaseStake(0);
  }

  function test_Revert_InsufficientBalance() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_InsufficientBalance.selector);
    rewardPool.decreaseStake(1);
  }

  function test_DecreaseStake(uint256 _stakeAmount, uint256 _decreaseAmount) public happyPath {
    vm.assume(_stakeAmount > 0 && _decreaseAmount > 0 && _decreaseAmount <= _stakeAmount);

    // First stake some amount
    rewardPool.stake(_stakeAmount);
    assertEq(rewardPool.totalStaked(), _stakeAmount);

    // Then decrease stake
    vm.expectEmit();
    emit RewardPoolDecreaseStake(authorizedAccount, _decreaseAmount);

    rewardPool.decreaseStake(_decreaseAmount);
    assertEq(rewardPool.totalStaked(), _stakeAmount - _decreaseAmount);
  }
}

contract Unit_RewardPool_Withdraw is Base {
  event RewardPoolWithdrawn(address indexed _account, uint256 _amount);
  event RewardPoolRewardPaid(address indexed _account, uint256 _reward);

  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.withdraw(1, false);
  }

  function test_Revert_NullAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_WithdrawNullAmount.selector);
    rewardPool.withdraw(0, false);
  }

  function test_Revert_InsufficientBalance() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_InsufficientBalance.selector);
    rewardPool.withdraw(1, false);
  }

  function test_Withdraw_WithoutClaim(uint256 _stakeAmount, uint256 _withdrawAmount) public happyPath {
    vm.assume(_stakeAmount > 0 && _withdrawAmount > 0 && _withdrawAmount <= _stakeAmount);

    // First stake some amount
    rewardPool.stake(_stakeAmount);
    assertEq(rewardPool.totalStaked(), _stakeAmount);

    // Then withdraw without claiming rewards
    vm.expectEmit();
    emit RewardPoolWithdrawn(address(mockStakingManager), _withdrawAmount);

    rewardPool.withdraw(_withdrawAmount, false);
    assertEq(rewardPool.totalStaked(), _stakeAmount - _withdrawAmount);
  }

  function test_Withdraw_WithClaim(
    uint256 _stakeAmount,
    uint256 _withdrawAmount,
    uint256 _rewardAmount
  ) public happyPath {
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _withdrawAmount = bound(_withdrawAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    vm.assume(_stakeAmount > 0 && _withdrawAmount > 0 && _withdrawAmount <= _stakeAmount);

    // Transfer reward token to the reward pool
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );
    // Mock balanceOf call to return the transferred amount
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(rewardPool)),
      abi.encode(_rewardAmount)
    );

    uint256 balance = IERC20(mockRewardToken).balanceOf(address(rewardPool));

    // Test reward pool token balance
    assertEq(balance, _rewardAmount);

    // Notify reward amount
    rewardPool.notifyRewardAmount(_rewardAmount);

    // Test expected reward pool values
    assertEq(rewardPool.currentRewards(), _rewardAmount);
    // Is 0 because no fn() w/ updateReward modifier has been called yet
    assertEq(rewardPool.rewards(), 0);
    assertEq(rewardPool.historicalRewards(), _rewardAmount);
    assertEq(rewardPool.rewardRate(), _rewardAmount / DURATION);
    assertEq(rewardPool.lastUpdateTime(), block.timestamp);
    assertEq(rewardPool.periodFinish(), block.timestamp + DURATION);

    // First stake some amount
    rewardPool.stake(_stakeAmount);
    // Test total staked
    assertEq(rewardPool.totalStaked(), _stakeAmount);

    vm.warp(block.timestamp + 7 days);

    assertEq(rewardPool.lastTimeRewardApplicable(), block.timestamp);

    uint256 rewardPerTokenStored = rewardPool.rewardPerTokenStored();
    assertEq(rewardPerTokenStored, 0);
    assertEq(rewardPool.rewardPerTokenPaid(), 0);
    assertEq(
      rewardPool.rewardPerToken(),
      rewardPerTokenStored
        + ((rewardPool.lastTimeRewardApplicable() - rewardPool.lastUpdateTime()) * rewardPool.rewardRate() * 1e18)
          / _stakeAmount
    );

    assertEq(
      rewardPool.earned(),
      ((_stakeAmount * (rewardPool.rewardPerToken() - rewardPool.rewardPerTokenPaid())) / 1e18) + rewardPool.rewards()
    );

    // Start the recorder
    vm.recordLogs();

    rewardPool.withdraw(_withdrawAmount, true);

    VmSafe.Log[] memory entries = vm.getRecordedLogs();

    assertEq(entries.length, 2);

    assertEq(entries[0].topics[0], keccak256('RewardPoolRewardPaid(address,uint256)'));
    assertEq(entries[0].topics[1], bytes32(uint256(uint160(address(mockStakingManager)))));
    uint256 amountPaid = abi.decode(entries[0].data, (uint256));

    assertEq(entries[1].topics[0], keccak256('RewardPoolWithdrawn(address,uint256)'));
    assertEq(entries[1].topics[1], bytes32(uint256(uint160(address(mockStakingManager)))));
    assertEq(abi.decode(entries[1].data, (uint256)), _withdrawAmount);

    assertEq(rewardPool.earned(), 0);

    uint256 rewardPerTokenPaid = rewardPool.rewardPerTokenPaid();

    assertEq(rewardPool.totalStaked(), _stakeAmount - _withdrawAmount);

    assertEq(amountPaid, (rewardPerTokenPaid * _stakeAmount) / 1e18);
  }
}

contract Unit_RewardPool_GetReward is Base {
  event RewardPoolRewardPaid(address indexed _account, uint256 _reward);

  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.getReward();
  }

  function test_GetReward_WithRewards(
    uint256 _stakeAmount,
    uint256 _rewardAmount
  ) public happyPath setupStakingRewards(_stakeAmount, _rewardAmount) {
    // Calculate expected reward
    uint256 expectedReward = rewardPool.earned();

    // Mock the reward transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), expectedReward),
      abi.encode(true)
    );

    // Start recording events
    vm.recordLogs();

    // Get reward
    rewardPool.getReward();

    // Verify events
    VmSafe.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1);
    assertEq(entries[0].topics[0], keccak256('RewardPoolRewardPaid(address,uint256)'));
    assertEq(entries[0].topics[1], bytes32(uint256(uint160(address(mockStakingManager)))));
    assertEq(abi.decode(entries[0].data, (uint256)), expectedReward);

    // Verify state after reward claim
    assertEq(rewardPool.earned(), 0);
    assertEq(rewardPool.rewards(), 0);
  }
}

contract Unit_RewardPool_LastTimeRewardApplicable is Base {
  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  modifier setupRewards(uint256 _rewardAmount) {
    // Setup initial rewards
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // Mock reward token transfer to the pool
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    // Notify reward amount - this sets periodFinish to block.timestamp + DURATION
    rewardPool.notifyRewardAmount(_rewardAmount);

    _;
  }

  function test_LastTimeRewardApplicable_BeforePeriodFinish(uint256 _rewardAmount)
    public
    happyPath
    setupRewards(_rewardAmount)
  {
    // Move time forward but not past period finish
    vm.warp(block.timestamp + 7 days);

    // Should return current timestamp since we haven't reached periodFinish
    assertEq(rewardPool.lastTimeRewardApplicable(), block.timestamp);
  }

  function test_LastTimeRewardApplicable_AfterPeriodFinish(uint256 _rewardAmount)
    public
    happyPath
    setupRewards(_rewardAmount)
  {
    uint256 periodFinish = rewardPool.periodFinish();

    // Move time past period finish
    vm.warp(periodFinish + 1 days);

    // Should return periodFinish since we're past it
    assertEq(rewardPool.lastTimeRewardApplicable(), periodFinish);
  }

  function test_LastTimeRewardApplicable_NoRewardsNotified() public {
    // Without notifying rewards, periodFinish should be 0
    assertEq(rewardPool.periodFinish(), 0);
    assertEq(rewardPool.lastTimeRewardApplicable(), 0);
  }

  function test_LastTimeRewardApplicable_MultipleNotifications(uint256 _rewardAmount) public happyPath {
    // Setup initial rewards
    _rewardAmount = bound(_rewardAmount, 1e18, 100_000e18);

    // Mock reward token transfer to the pool
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    // First notification
    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 firstPeriodFinish = rewardPool.periodFinish();

    // Move time forward but not past first period finish
    vm.warp(block.timestamp + 7 days);

    // Second notification - should extend period finish
    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 secondPeriodFinish = rewardPool.periodFinish();

    // Verify period finish was extended
    assertGt(secondPeriodFinish, firstPeriodFinish);

    // Should return current timestamp since we haven't reached new period finish
    assertEq(rewardPool.lastTimeRewardApplicable(), block.timestamp);

    // Move past second period finish
    vm.warp(secondPeriodFinish + 1 days);

    // Should return second period finish
    assertEq(rewardPool.lastTimeRewardApplicable(), secondPeriodFinish);
  }
}

contract Unit_RewardPool_RewardPerToken is Base {
  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_RewardPerToken_NoStake(uint256 _rewardAmount) public happyPath {
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    rewardPool.notifyRewardAmount(_rewardAmount);
    assertEq(rewardPool.rewardPerToken(), 0);
  }

  function test_RewardPerToken_NoRewards(uint256 _stakeAmount) public happyPath {
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    // Should return 0 if there are no rewards, even with stake
    rewardPool.stake(_stakeAmount);

    assertEq(rewardPool.rewardPerToken(), 0);
  }

  function test_RewardPerToken_WithStakeAndRewards(uint256 _stakeAmount, uint256 _rewardAmount) public happyPath {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_stakeAmount);
    assertEq(rewardPool.totalStaked(), _stakeAmount);

    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 startTime = block.timestamp;

    // Move time forward
    vm.warp(block.timestamp + 7 days);

    // Calculate expected reward per token
    uint256 timeElapsed = block.timestamp - startTime;
    uint256 rewardRate = _rewardAmount / DURATION;
    uint256 expectedRewardPerToken =
      rewardPool.rewardPerTokenStored() + ((timeElapsed * rewardRate * 1e18) / _stakeAmount);

    assertEq(rewardPool.rewardPerToken(), expectedRewardPerToken);
  }

  function test_RewardPerToken_AfterPeriodFinish(uint256 _stakeAmount, uint256 _rewardAmount) public happyPath {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_stakeAmount);

    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 periodFinish = rewardPool.periodFinish();

    // Move time past period finish
    vm.warp(periodFinish + 7 days);

    // Calculate expected reward per token
    uint256 timeElapsed = DURATION; // Should use full duration since we're past periodFinish
    uint256 rewardRate = _rewardAmount / DURATION;
    uint256 expectedRewardPerToken =
      rewardPool.rewardPerTokenStored() + ((timeElapsed * rewardRate * 1e18) / _stakeAmount);

    assertEq(rewardPool.rewardPerToken(), expectedRewardPerToken);
  }

  function test_RewardPerToken_MultipleStakes(
    uint256 _initialStake,
    uint256 _additionalStake,
    uint256 _rewardAmount
  ) public happyPath {
    // Bound inputs to reasonable values
    _initialStake = bound(_initialStake, 1e18, 1_000_000e18);
    _additionalStake = bound(_additionalStake, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_initialStake);

    // Setup rewards
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    rewardPool.notifyRewardAmount(_rewardAmount);

    // Move time forward
    vm.warp(block.timestamp + 3 days);

    // Get reward per token before second stake
    // This will update rewardPerTokenStored
    uint256 rewardPerTokenBeforeSecondStake = rewardPool.rewardPerToken();

    // Add more stake
    rewardPool.stake(_additionalStake);
    uint256 secondStakeTime = block.timestamp;

    // Move time forward again
    vm.warp(block.timestamp + 4 days);

    // Calculate expected reward per token for phase 2 only
    uint256 rewardRate = _rewardAmount / DURATION;

    // Phase 2: Both stakes, starting from rewardPerTokenStored
    uint256 phase2Time = block.timestamp - secondStakeTime;
    uint256 phase2Reward = (phase2Time * rewardRate * 1e18) / (_initialStake + _additionalStake);

    uint256 expectedRewardPerToken = rewardPerTokenBeforeSecondStake + phase2Reward;

    assertEq(rewardPool.rewardPerToken(), expectedRewardPerToken);
  }
}

contract Unit_RewardPool_Earned is Base {
  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_Earned_NoStake(uint256 _rewardAmount) public happyPath {
    // Should return 0 if there's no stake, even with rewards
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    rewardPool.notifyRewardAmount(_rewardAmount);
    assertEq(rewardPool.earned(), 0);
  }

  function test_Earned_NoRewards(uint256 _stakeAmount) public happyPath {
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);

    // Should return 0 if there are no rewards, even with stake
    rewardPool.stake(_stakeAmount);
    assertEq(rewardPool.earned(), 0);
  }

  function test_Earned_WithStakeAndRewards(uint256 _stakeAmount, uint256 _rewardAmount) public happyPath {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_stakeAmount);

    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 startTime = block.timestamp;

    // Move time forward
    vm.warp(block.timestamp + 7 days);

    // Calculate expected earned amount
    uint256 timeElapsed = block.timestamp - startTime;
    uint256 rewardRate = _rewardAmount / DURATION;
    uint256 rewardPerToken = (timeElapsed * rewardRate * 1e18) / _stakeAmount;
    uint256 expectedEarned = (_stakeAmount * rewardPerToken) / 1e18;

    assertEq(rewardPool.earned(), expectedEarned);
  }

  function test_Earned_AfterPeriodFinish(uint256 _stakeAmount, uint256 _rewardAmount) public happyPath {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_stakeAmount);

    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 periodFinish = rewardPool.periodFinish();

    // Move time past period finish
    vm.warp(periodFinish + 7 days);

    // Calculate expected earned amount
    uint256 rewardRate = _rewardAmount / DURATION;
    uint256 rewardPerToken = (DURATION * rewardRate * 1e18) / _stakeAmount;
    uint256 expectedEarned = (_stakeAmount * rewardPerToken) / 1e18;

    assertEq(rewardPool.earned(), expectedEarned);
  }

  function test_Earned_MultipleStakesAndRewards(
    uint256 _initialStake,
    uint256 _additionalStake,
    uint256 _rewardAmount
  ) public happyPath {
    // Bound inputs to reasonable values
    _initialStake = bound(_initialStake, 1e18, 1_000_000e18);
    _additionalStake = bound(_additionalStake, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_initialStake);

    // Setup first rewards
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    rewardPool.notifyRewardAmount(_rewardAmount);

    // Move time forward
    vm.warp(block.timestamp + 3 days);

    // Get earned amount before second stake
    uint256 earnedBeforeSecondStake = rewardPool.earned();

    // Add more stake
    rewardPool.stake(_additionalStake);

    // Move time forward again
    vm.warp(block.timestamp + 4 days);

    // Final earned should be greater than initial earned
    uint256 finalEarned = rewardPool.earned();
    assertGt(finalEarned, earnedBeforeSecondStake);
  }

  function test_Earned_AfterWithdraw(uint256 _stakeAmount, uint256 _rewardAmount) public happyPath {
    // Bound inputs to reasonable values
    _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First stake
    rewardPool.stake(_stakeAmount);

    // Setup rewards
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
      abi.encode(true)
    );

    rewardPool.notifyRewardAmount(_rewardAmount);

    // Move time forward
    vm.warp(block.timestamp + 7 days);

    // Get earned before withdrawal
    uint256 earnedBeforeWithdraw = rewardPool.earned();

    // Mock the reward transfer that will happen during withdraw
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), earnedBeforeWithdraw),
      abi.encode(true)
    );

    // Withdraw all stake with getReward = false to keep rewards
    rewardPool.withdraw(_stakeAmount, false);

    // Earned amount should remain the same after withdrawal when not claiming rewards
    assertEq(rewardPool.earned(), earnedBeforeWithdraw);

    // Now test withdrawal with getReward = true
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), earnedBeforeWithdraw),
      abi.encode(true)
    );

    // Stake again to test withdrawal with reward claim
    rewardPool.stake(_stakeAmount);

    // Move time forward to accrue some rewards
    vm.warp(block.timestamp + 7 days);

    uint256 newEarnedAmount = rewardPool.earned();

    // Mock the reward transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), newEarnedAmount),
      abi.encode(true)
    );

    // Withdraw with getReward = true should reset earned to 0
    rewardPool.withdraw(_stakeAmount, true);
    assertEq(rewardPool.earned(), 0);
  }
}

contract Unit_RewardPool_QueueNewRewards is Base {
  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_QueueNewRewards_AfterPeriodFinish(uint256 _rewardsToQueue) public happyPath {
    vm.assume(_rewardsToQueue > 0 && _rewardsToQueue < type(uint256).max / 2);

    // Warp to after period finish
    vm.warp(block.timestamp + rewardPoolParams.duration + 1);

    // Queue new rewards
    rewardPool.queueNewRewards(_rewardsToQueue);

    // Check that rewards were immediately notified
    assertEq(rewardPool.queuedRewards(), 0);
    assertEq(rewardPool.rewardRate(), _rewardsToQueue / rewardPoolParams.duration);
    assertEq(rewardPool.historicalRewards(), _rewardsToQueue);
  }

  function test_QueueNewRewards_BelowRatio(uint256 _rewardsToQueue, uint256 _initialRewards) public happyPath {
    _rewardsToQueue = bound(_rewardsToQueue, 1e18, 1_000_000e18);
    _initialRewards = bound(_initialRewards, 1e18, 1_000_000e18);

    // First notify some initial rewards
    rewardPool.notifyRewardAmount(_initialRewards);

    // Calculate reward rate
    uint256 rewardRate = _initialRewards / rewardPoolParams.duration;

    // Warp to early in the period to ensure ratio is below threshold
    uint256 elapsedTime = rewardPoolParams.duration / 10; // 10% of duration
    vm.warp(block.timestamp + elapsedTime);

    // Calculate expected ratio
    uint256 currentAtNow = rewardRate * elapsedTime;
    uint256 totalRewards = _rewardsToQueue + rewardPool.queuedRewards();
    uint256 queuedRatio = (currentAtNow * 1000) / totalRewards;

    // Ensure ratio is below newRewardRatio
    vm.assume(queuedRatio < rewardPoolParams.newRewardRatio);

    // Queue new rewards
    rewardPool.queueNewRewards(_rewardsToQueue);

    // When ratio is below threshold, rewards should be immediately notified
    assertEq(rewardPool.queuedRewards(), 0);
    assertEq(rewardPool.historicalRewards(), _rewardsToQueue + _initialRewards);
  }

  function test_QueueNewRewards_AboveRatio(uint256 _rewardsToQueue, uint256 _initialRewards) public happyPath {
    _rewardsToQueue = bound(_rewardsToQueue, 1e18, 1_000_000e18);
    _initialRewards = bound(_initialRewards, 1e18, 1_000_000e18);

    // First notify some initial rewards
    rewardPool.notifyRewardAmount(_initialRewards);

    // Calculate reward rate
    uint256 rewardRate = _initialRewards / rewardPoolParams.duration;

    // Warp to near end of period to ensure ratio is above threshold
    uint256 elapsedTime = (rewardPoolParams.duration * 9) / 10; // 90% of duration
    vm.warp(block.timestamp + elapsedTime);

    // Calculate expected ratio
    uint256 currentAtNow = rewardRate * elapsedTime;
    uint256 totalRewards = _rewardsToQueue + rewardPool.queuedRewards();
    uint256 queuedRatio = (currentAtNow * 1000) / totalRewards;

    // Ensure ratio is above newRewardRatio
    vm.assume(queuedRatio >= rewardPoolParams.newRewardRatio);
    vm.assume(_rewardsToQueue < currentAtNow); // Ensure rewards are small enough to maintain high ratio

    // Queue new rewards
    rewardPool.queueNewRewards(_rewardsToQueue);

    // Check that rewards were queued instead of notified
    assertEq(rewardPool.queuedRewards(), _rewardsToQueue);
    assertEq(rewardPool.historicalRewards(), _initialRewards);
  }

  function test_QueueNewRewards_OnlyAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.queueNewRewards(100 ether);
  }

  function test_QueueNewRewards_AccumulateQueue(
    uint256 _firstQueue,
    uint256 _secondQueue,
    uint256 _initialRewards
  ) public happyPath {
    _firstQueue = bound(_firstQueue, 1e18, 1_000_000e18);
    _secondQueue = bound(_secondQueue, 1e18, 1_000_000e18);
    _initialRewards = bound(_initialRewards, 1e18, 1_000_000e18);

    // First notify some initial rewards
    rewardPool.notifyRewardAmount(_initialRewards);

    // Calculate reward rate and timing
    uint256 rewardRate = _initialRewards / rewardPoolParams.duration;
    uint256 elapsedTime = (rewardPoolParams.duration * 9) / 10; // 90% of duration

    // Warp to near end of period
    vm.warp(block.timestamp + elapsedTime);

    // Calculate expected ratio for first queue
    uint256 currentAtNow = rewardRate * elapsedTime;
    uint256 totalRewardsFirst = _firstQueue;
    uint256 queuedRatioFirst = (currentAtNow * 1000) / totalRewardsFirst;

    // Ensure ratio is above newRewardRatio for first queue
    vm.assume(queuedRatioFirst >= rewardPoolParams.newRewardRatio);
    vm.assume(_firstQueue < currentAtNow);

    // Queue first rewards
    rewardPool.queueNewRewards(_firstQueue);

    // Calculate expected ratio for second queue
    uint256 totalRewardsSecond = _firstQueue + _secondQueue;
    uint256 queuedRatioSecond = (currentAtNow * 1000) / totalRewardsSecond;

    // Ensure ratio is above newRewardRatio for second queue
    vm.assume(queuedRatioSecond >= rewardPoolParams.newRewardRatio);
    vm.assume(_secondQueue < currentAtNow);

    // Queue second rewards
    rewardPool.queueNewRewards(_secondQueue);

    // Check that both queued amounts are accumulated
    assertEq(rewardPool.queuedRewards(), _firstQueue + _secondQueue);
    assertEq(rewardPool.historicalRewards(), _initialRewards);
  }
}

contract Unit_RewardPool_NotifyRewardAmount is Base {
  event RewardPoolRewardAdded(uint256 _reward);

  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_NotifyRewardAmount_Basic(uint256 _rewardAmount) public happyPath {
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // Notify rewards
    rewardPool.notifyRewardAmount(_rewardAmount);

    // Check state updates
    assertEq(rewardPool.historicalRewards(), _rewardAmount);
    assertEq(rewardPool.rewardRate(), _rewardAmount / rewardPoolParams.duration);
    assertEq(rewardPool.currentRewards(), _rewardAmount);
    assertEq(rewardPool.lastUpdateTime(), block.timestamp);
    assertEq(rewardPool.periodFinish(), block.timestamp + rewardPoolParams.duration);
  }

  function test_NotifyRewardAmount_ZeroAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_InvalidRewardAmount.selector);
    rewardPool.notifyRewardAmount(0);
  }

  function test_NotifyRewardAmount_AfterPeriodFinish(uint256 _rewardAmount) public happyPath {
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    // First notification
    rewardPool.notifyRewardAmount(_rewardAmount);
    uint256 firstPeriodFinish = rewardPool.periodFinish();

    // Warp to after period finish
    vm.warp(firstPeriodFinish + 1);

    // Second notification
    rewardPool.notifyRewardAmount(_rewardAmount);

    // Check state updates
    assertEq(rewardPool.historicalRewards(), _rewardAmount * 2);
    assertEq(rewardPool.rewardRate(), _rewardAmount / rewardPoolParams.duration);
    assertEq(rewardPool.currentRewards(), _rewardAmount);
    assertEq(rewardPool.lastUpdateTime(), block.timestamp);
    assertEq(rewardPool.periodFinish(), block.timestamp + rewardPoolParams.duration);
  }

  function test_NotifyRewardAmount_DuringActivePeriod(uint256 _firstAmount, uint256 _secondAmount) public happyPath {
    _firstAmount = bound(_firstAmount, 1e18, 1_000_000e18);
    _secondAmount = bound(_secondAmount, 1e18, 1_000_000e18);

    // First notification
    rewardPool.notifyRewardAmount(_firstAmount);

    // Warp to middle of period
    vm.warp(block.timestamp + rewardPoolParams.duration / 2);

    // Calculate remaining rewards
    uint256 remaining = rewardPool.periodFinish() - block.timestamp;
    uint256 leftover = remaining * rewardPool.rewardRate();
    uint256 expectedReward = _secondAmount + leftover;

    // Second notification
    rewardPool.notifyRewardAmount(_secondAmount);

    // Check state updates
    assertEq(rewardPool.historicalRewards(), _firstAmount + _secondAmount);
    assertEq(rewardPool.rewardRate(), expectedReward / rewardPoolParams.duration);
    assertEq(rewardPool.currentRewards(), expectedReward);
    assertEq(rewardPool.lastUpdateTime(), block.timestamp);
    assertEq(rewardPool.periodFinish(), block.timestamp + rewardPoolParams.duration);
  }

  function test_NotifyRewardAmount_OnlyAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.notifyRewardAmount(100 ether);
  }

  function test_NotifyRewardAmount_EmitsEvent(uint256 _rewardAmount) public happyPath {
    _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

    vm.expectEmit();
    emit RewardPoolRewardAdded(_rewardAmount);

    rewardPool.notifyRewardAmount(_rewardAmount);
  }
}

contract Unit_RewardPool_EmergencyWithdraw is Base {
  event RewardPoolEmergencyWithdrawal(address indexed _account, uint256 _amount);

  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  function test_EmergencyWithdraw_Basic(uint256 _withdrawAmount) public happyPath {
    _withdrawAmount = bound(_withdrawAmount, 1e18, 1_000_000e18);
    address rescueReceiver = address(0xdead);

    // Mock successful transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, _withdrawAmount),
      abi.encode(true)
    );

    // Set up expectation before the call
    vm.expectCall(
      address(mockRewardToken), abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, _withdrawAmount)
    );

    // Perform emergency withdrawal
    rewardPool.emergencyWithdraw(rescueReceiver, _withdrawAmount);
  }

  function test_EmergencyWithdraw_ZeroAmount() public happyPath {
    vm.expectRevert(IRewardPool.RewardPool_WithdrawNullAmount.selector);
    rewardPool.emergencyWithdraw(address(0xdead), 0);
  }

  function test_EmergencyWithdraw_OnlyAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.emergencyWithdraw(address(0xdead), 100 ether);
  }

  function test_EmergencyWithdraw_EmitsEvent(uint256 _withdrawAmount) public happyPath {
    _withdrawAmount = bound(_withdrawAmount, 1e18, 1_000_000e18);
    address rescueReceiver = address(0xdead);

    // Mock successful transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, _withdrawAmount),
      abi.encode(true)
    );

    vm.expectEmit();
    emit RewardPoolEmergencyWithdrawal(address(mockStakingManager), _withdrawAmount);

    rewardPool.emergencyWithdraw(rescueReceiver, _withdrawAmount);
  }

  function test_EmergencyWithdraw_TransferFails(uint256 _withdrawAmount) public happyPath {
    _withdrawAmount = bound(_withdrawAmount, 1e18, 1_000_000e18);
    address rescueReceiver = address(0xdead);

    // Mock failed transfer
    vm.mockCall(
      address(mockRewardToken),
      abi.encodeWithSelector(IERC20.transfer.selector, rescueReceiver, _withdrawAmount),
      abi.encode(false)
    );

    vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(mockRewardToken)));
    rewardPool.emergencyWithdraw(rescueReceiver, _withdrawAmount);
  }
}

contract Unit_RewardPool_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  struct ModifyParametersScenario {
    address stakingManager;
    uint256 duration;
    uint256 newRewardRatio;
  }

  function test_ModifyParameters_Basic(ModifyParametersScenario memory _fuzz)
    public
    happyPath
    mockAsContract(_fuzz.stakingManager)
  {
    vm.assume(_fuzz.stakingManager != address(0));
    vm.assume(_fuzz.duration > 0);
    vm.assume(_fuzz.newRewardRatio > 0);
    vm.assume(_fuzz.stakingManager != address(mockStakingManager));

    rewardPool.modifyParameters('stakingManager', abi.encode(_fuzz.stakingManager));
    rewardPool.modifyParameters('duration', abi.encode(_fuzz.duration));
    rewardPool.modifyParameters('newRewardRatio', abi.encode(_fuzz.newRewardRatio));

    IRewardPool.RewardPoolParams memory _params = rewardPool.params();

    assertEq(_params.stakingManager, _fuzz.stakingManager);
    assertEq(_params.duration, _fuzz.duration);
    assertEq(_params.newRewardRatio, _fuzz.newRewardRatio);
  }

  function test_ModifyParameters_StakingManager(address _stakingManager)
    public
    happyPath
    mockAsContract(_stakingManager)
  {
    vm.assume(_stakingManager != address(0));
    vm.assume(_stakingManager != address(mockStakingManager));

    rewardPool.modifyParameters('stakingManager', abi.encode(_stakingManager));

    assertEq(rewardPool.params().stakingManager, _stakingManager);
  }

  function test_ModifyParameters_Duration(uint256 _duration) public happyPath {
    vm.assume(_duration > 0);

    rewardPool.modifyParameters('duration', abi.encode(_duration));

    assertEq(rewardPool.params().duration, _duration);
  }

  function test_ModifyParameters_NewRewardRatio(uint256 _newRewardRatio) public happyPath {
    vm.assume(_newRewardRatio > 0);

    rewardPool.modifyParameters('newRewardRatio', abi.encode(_newRewardRatio));

    assertEq(rewardPool.params().newRewardRatio, _newRewardRatio);
  }

  function test_Revert_ModifyParameters_UnrecognizedParam(bytes memory _data) public happyPath {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    rewardPool.modifyParameters('unrecognizedParam', _data);
  }

  function test_Revert_ModifyParameters_Unauthorized(bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardPool.modifyParameters('stakingManager', _data);
  }
}

contract Unit_RewardPool_UpdateReward is Base {
  function setUp() public override {
    super.setUp();
    // Set up initial state for rewards
    vm.startPrank(address(mockStakingManager));
    rewardPool.modifyParameters('duration', abi.encode(7 days));
    rewardPool.stake(1000 ether); // Add initial stake
    rewardPool.notifyRewardAmount(100 ether);
  }

  function test_UpdateReward_Basic() public {
    uint256 _initialRewardPerTokenStored = rewardPool.rewardPerTokenStored();
    uint256 _initialLastUpdateTime = rewardPool.lastUpdateTime();

    // Warp time to simulate rewards accumulation
    vm.warp(block.timestamp + 1 days);

    // Call helper function that just applies the modifier
    rewardPool.updateRewardHelper();

    // Check that values were updated
    assertGt(rewardPool.rewardPerTokenStored(), _initialRewardPerTokenStored);
    assertGt(rewardPool.lastUpdateTime(), _initialLastUpdateTime);
    assertEq(rewardPool.lastUpdateTime(), rewardPool.lastTimeRewardApplicable());
  }

  function test_UpdateReward_NoTimeElapsed() public {
    uint256 _initialRewardPerTokenStored = rewardPool.rewardPerTokenStored();
    uint256 _initialLastUpdateTime = rewardPool.lastUpdateTime();

    // Call helper function immediately
    rewardPool.updateRewardHelper();

    // Values should remain unchanged
    assertEq(rewardPool.rewardPerTokenStored(), _initialRewardPerTokenStored);
    assertEq(rewardPool.lastUpdateTime(), _initialLastUpdateTime);
  }

  function test_UpdateReward_StakingManager() public {
    vm.startPrank(address(mockStakingManager));

    uint256 _initialRewards = rewardPool.rewards();
    uint256 _initialRewardPerTokenPaid = rewardPool.rewardPerTokenPaid();

    // Warp time to simulate rewards accumulation
    vm.warp(block.timestamp + 1 days);

    rewardPool.updateRewardHelper();

    // Check staking manager specific updates
    assertGt(rewardPool.rewards(), _initialRewards);
    assertGt(rewardPool.rewardPerTokenPaid(), _initialRewardPerTokenPaid);
    assertEq(rewardPool.rewardPerTokenPaid(), rewardPool.rewardPerTokenStored());
  }

  function test_UpdateReward_AfterPeriodFinish() public {
    // Warp past the reward period
    vm.warp(block.timestamp + 8 days);

    uint256 _initialRewardPerTokenStored = rewardPool.rewardPerTokenStored();
    uint256 _initialLastUpdateTime = rewardPool.lastUpdateTime();

    rewardPool.updateRewardHelper();

    // Check that values were updated but capped at periodFinish
    assertGt(rewardPool.rewardPerTokenStored(), _initialRewardPerTokenStored);
    assertGt(rewardPool.lastUpdateTime(), _initialLastUpdateTime);
    assertEq(rewardPool.lastUpdateTime(), rewardPool.periodFinish());
  }
}

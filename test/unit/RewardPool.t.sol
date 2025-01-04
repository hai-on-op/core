// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {RewardPool, IRewardPool} from '@contracts/tokens/RewardPool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {VmSafe} from 'forge-std/Vm.sol';
import 'forge-std/console.sol';
import {console2} from 'forge-std/console2.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
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

    rewardPool = new RewardPool(address(mockRewardToken), address(mockStakingManager), DURATION, NEW_REWARD_RATIO);
    label(address(rewardPool), 'RewardPool');

    // rewardPool.addAuthorization(authorizedAccount);
    rewardPool.addAuthorization(address(mockStakingManager));
    rewardPool.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier setupRewards(uint256 _stakeAmount, uint256 _rewardAmount) {
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
    new RewardPool(address(0), address(mockStakingManager), DURATION, NEW_REWARD_RATIO);
  }

  function test_Revert_NullAddress_StakingManager() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new RewardPool(address(mockRewardToken), address(0), DURATION, NEW_REWARD_RATIO);
  }

  function test_Revert_NullAmount_Duration() public {
    vm.expectRevert(Assertions.NullAmount.selector);
    new RewardPool(address(mockRewardToken), address(mockStakingManager), 0, NEW_REWARD_RATIO);
  }

  function test_Revert_NullAmount_NewRewardRatio() public {
    vm.expectRevert(Assertions.NullAmount.selector);
    new RewardPool(address(mockRewardToken), address(mockStakingManager), DURATION, 0);
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

    assertEq(amountPaid, rewardPerTokenPaid * _stakeAmount / 1e18);
  }
}

contract Unit_RewardPool_GetReward is Base {
  event RewardPoolRewardPaid(address indexed _account, uint256 _reward);

  modifier happyPath() {
    vm.startPrank(address(mockStakingManager));
    _;
  }

  // function test_Revert_Unauthorized() public {
  //   vm.expectRevert(IAuthorizable.Unauthorized.selector);
  //   rewardPool.getReward();
  // }

  function test_GetReward_WithRewards(
    uint256 _stakeAmount,
    uint256 _rewardAmount
  ) public happyPath setupRewards(_stakeAmount, _rewardAmount) {
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

  // function test_GetReward_MultipleClaims(uint256 _stakeAmount, uint256 _rewardAmount) public {
  //   // Bound inputs to reasonable values
  //   _stakeAmount = bound(_stakeAmount, 1e18, 1_000_000e18);
  //   _rewardAmount = bound(_rewardAmount, 1e18, 1_000_000e18);

  //   vm.startPrank(address(mockStakingManager));

  //   // Setup initial stake and rewards
  //   rewardPool.stake(_stakeAmount);

  //   // Mock reward token transfer to the pool
  //   vm.mockCall(
  //     address(mockRewardToken),
  //     abi.encodeWithSelector(IERC20.transfer.selector, address(rewardPool), _rewardAmount),
  //     abi.encode(true)
  //   );

  //   vm.mockCall(
  //     address(mockRewardToken),
  //     abi.encodeWithSelector(IERC20.balanceOf.selector, address(rewardPool)),
  //     abi.encode(_rewardAmount)
  //   );

  //   rewardPool.notifyRewardAmount(_rewardAmount);

  //   // First claim after some time
  //   vm.warp(block.timestamp + 3 days);
  //   uint256 firstExpectedReward = rewardPool.earned();

  //   vm.mockCall(
  //     address(mockRewardToken),
  //     abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), firstExpectedReward),
  //     abi.encode(true)
  //   );

  //   rewardPool.getReward();

  //   // Second claim after more time
  //   vm.warp(block.timestamp + 4 days);
  //   uint256 secondExpectedReward = rewardPool.earned();

  //   vm.mockCall(
  //     address(mockRewardToken),
  //     abi.encodeWithSelector(IERC20.transfer.selector, address(mockStakingManager), secondExpectedReward),
  //     abi.encode(true)
  //   );

  //   rewardPool.getReward();

  //   // Verify final state
  //   assertEq(rewardPool.earned(), 0);
  //   assertEq(rewardPool.rewards(), 0);
  //   assertEq(rewardPool.rewardPerTokenPaid(), rewardPool.rewardPerToken());

  //   vm.stopPrank();
  // }
}

// contract Unit_RewardPool_NotifyReward is Base {
//   modifier happyPath() {
//     vm.startPrank(authorizedAccount);
//     _;
//   }

//   function test_NotifyReward(uint256 _reward) public happyPath {
//     vm.assume(_reward > 0);

//     rewardPool.notifyRewardAmount(_reward);

//     assertEq(rewardPool.historicalRewards(), _reward);
//     assertEq(rewardPool.rewardRate(), _reward / DURATION);
//   }

//   function test_Revert_NullAmount() public happyPath {
//     vm.expectRevert(IRewardPool.RewardPool_InvalidRewardAmount.selector);
//     rewardPool.notifyRewardAmount(0);
//   }

//   function test_Revert_Unauthorized() public {
//     vm.startPrank(user);
//     vm.expectRevert(IRewardPool.Unauthorized.selector);
//     rewardPool.notifyRewardAmount(1);
//   }
// }

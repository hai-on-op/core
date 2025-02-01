// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

/**
 * @title  IRewardPool
 * @notice Interface for the RewardPool contract which manages reward distribution
 */
interface IRewardPool is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when tokens are staked
   * @param _account The address that staked tokens
   * @param _amount Amount of tokens staked [wad]
   */
  event RewardPoolStaked(address indexed _account, uint256 _amount);

  /**
   * @notice Emitted when stake is increased
   * @param _account The address that increased stake
   * @param _amount Amount of tokens added to stake [wad]
   */
  event RewardPoolIncreaseStake(address indexed _account, uint256 _amount);

  /**
   * @notice Emitted when stake is decreased
   * @param _account The address that decreased stake
   * @param _amount Amount of tokens removed from stake [wad]
   */
  event RewardPoolDecreaseStake(address indexed _account, uint256 _amount);

  /**
   * @notice Emitted when tokens are withdrawn
   * @param _account The address that withdrew tokens
   * @param _amount Amount of tokens withdrawn [wad]
   */
  event RewardPoolWithdrawn(address indexed _account, uint256 _amount);

  /**
   * @notice Emitted when rewards are paid out
   * @param _account The address that received rewards
   * @param _reward Amount of reward tokens paid [wad]
   */
  event RewardPoolRewardPaid(address indexed _account, uint256 _reward);

  /**
   * @notice Emitted when new rewards are added
   * @param _reward Amount of reward tokens added [wad]
   */
  event RewardPoolRewardAdded(uint256 _reward);

  /**
   * @notice Emitted on emergency withdrawal
   * @param _account The address that performed the withdrawal
   * @param _amount Amount withdrawn [wad]
   */
  event RewardPoolEmergencyWithdrawal(address indexed _account, uint256 _amount);

  // --- Errors ---

  /// @notice Throws when reward token address is invalid
  error RewardPool_InvalidRewardToken();

  /// @notice Throws when attempting to stake zero tokens
  error RewardPool_StakeNullAmount();

  /// @notice Throws when attempting to increase stake by zero
  error RewardPool_IncreaseStakeNullAmount();

  /// @notice Throws when attempting to decrease stake by zero
  error RewardPool_DecreaseStakeNullAmount();

  /// @notice Throws when attempting to withdraw zero tokens
  error RewardPool_WithdrawNullAmount();

  /// @notice Throws when balance is insufficient for operation
  error RewardPool_InsufficientBalance();

  /// @notice Throws when reward amount is invalid
  error RewardPool_InvalidRewardAmount();

  // --- Structs ---

  struct RewardPoolParams {
    address stakingManager; // Address of the staking manager
    uint256 duration; // Duration of rewards distribution
    uint256 newRewardRatio; // Ratio for accepting new rewards
  }

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _rewardPoolParams RewardPool parameters struct
   */
  function params() external view returns (RewardPoolParams memory _rewardPoolParams);

  /**
   * @notice Getter for the contract parameters struct
   * @return _stakingManager Address of the staking manager
   * @return _duration Duration of rewards distribution
   * @return _newRewardRatio Ratio for accepting new rewards
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (address _stakingManager, uint256 _duration, uint256 _newRewardRatio);

  // --- Data ---

  /**
   * @notice Getter for the reward token
   * @return _rewardToken The reward token being distributed
   */
  function rewardToken() external view returns (IERC20 _rewardToken);

  /**
   * @notice Getter for the Total amount of tokens staked
   * @return _totalStakedAmt Total amount of tokens staked
   */
  function totalStaked() external view returns (uint256 _totalStakedAmt);

  /**
   * @notice Getter for the accumulated rewards per token
   * @return _rewardPerTokenStored accumulated rewards per token
   */
  function rewardPerTokenStored() external view returns (uint256 _rewardPerTokenStored);

  /**
   * @notice Getter for the timestamp when the current reward period finishes
   * @return _periodFinish timestamp when the current reward period finishes
   */
  function periodFinish() external view returns (uint256 _periodFinish);

  /**
   * @notice Getter for the current rate at which rewards are distributed
   * @return _rewardRate rate at which rewards are distributed
   */
  function rewardRate() external view returns (uint256 _rewardRate);

  /**
   * @notice Getter for the last time the rewards were updated
   * @return _lastUpdateTime last time the rewards were updated
   */
  function lastUpdateTime() external view returns (uint256 _lastUpdateTime);

  /**
   * @notice Getter for the amount of rewards queued for distribution
   * @return _queuedRewards amount of rewards queued for distribution
   */
  function queuedRewards() external view returns (uint256 _queuedRewards);

  /**
   * @notice Getter for the current rewards being distributed
   * @return _currentRewards current rewards being distributed
   */
  function currentRewards() external view returns (uint256 _currentRewards);

  /**
   * @notice Getter for the total amount of rewards added
   * @return _historicalRewards total amount of rewards added
   */
  function historicalRewards() external view returns (uint256 _historicalRewards);

  /**
   * @notice Getter for the amount of rewards paid out for each token so far
   * @return _rewardPerTokenPaid amount of rewards paid out for each token so far
   */
  function rewardPerTokenPaid() external view returns (uint256 _rewardPerTokenPaid);

  /**
   * @notice Getter for the amount of rewards earned but not paid out yet
   * @return _rewards amount of rewards earned but not paid out yet
   */
  function rewards() external view returns (uint256 _rewards);

  // --- Methods ---

  /**
   * @notice Getter for the last timestamp that rewards were applicable
   * @return _periodFinish last timestamp that rewards were applicable
   */
  function lastTimeRewardApplicable() external view returns (uint256 _periodFinish);

  /**
   * @notice Calculates the reward per token stored
   * @return _rewardPerToken reward per token stored
   */
  function rewardPerToken() external view returns (uint256 _rewardPerToken);

  /**
   * @notice Getter for the earned rewards for an account
   * @return _earned earned rewards for an account
   */
  function earned() external view returns (uint256 _earned);

  /// @notice Stake tokens in the pool
  function stake(uint256 _amount) external;

  /// @notice Increase staked amount
  function increaseStake(uint256 _amount) external;

  /// @notice Decrease staked amount
  function decreaseStake(uint256 _amount) external;

  /// @notice Withdraw staked tokens
  function withdraw(uint256 _amount, bool _claim) external;

  /// @notice Claim earned rewards
  function getReward() external;

  /// @notice Queue new rewards for distribution
  function queueNewRewards(uint256 _amount) external;

  /// @notice Notify reward amount for immediate distribution
  function notifyRewardAmount(uint256 _reward) external;

  /// @notice Emergency withdrawal of reward tokens
  function emergencyWithdraw(address _rescueReceiver, uint256 _wad) external;
}

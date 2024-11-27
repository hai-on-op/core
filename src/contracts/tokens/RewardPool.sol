// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

/**
 * @title  RewardPool
 * @notice This contract constitutes a reward pool for a given reward token
 */
contract RewardPool is Authorizable, Modifiable, IRewardPool {
  using Encoding for bytes;
  using Assertions for uint256;
  using Math for uint256;
  using SafeERC20 for IERC20;

  // --- Registry ---

  /// @inheritdoc IRewardPool
  IERC20 public rewardToken;

  // --- Params ---

  /// @inheritdoc IRewardPool
  // solhint-disable-next-line private-vars-leading-underscore
  RewardPoolParams public _params;

  /// @inheritdoc IRewardPool
  function params() external view returns (RewardPoolParams memory _rewardPoolParams) {
    return _params;
  }

  // --- Data ---

  uint256 private _totalStaked;

  /// @inheritdoc IRewardPool
  function totalStaked() external view returns (uint256) {
    return _totalStaked;
  }

  /// @inheritdoc IRewardPool
  uint256 public rewardPerTokenStored;
  /// @inheritdoc IRewardPool
  uint256 public periodFinish = 0;
  /// @inheritdoc IRewardPool
  uint256 public rewardRate = 0;
  /// @inheritdoc IRewardPool
  uint256 public lastUpdateTime;
  /// @inheritdoc IRewardPool
  uint256 public queuedRewards = 0;
  /// @inheritdoc IRewardPool
  uint256 public currentRewards = 0;
  /// @inheritdoc IRewardPool
  uint256 public historicalRewards = 0;
  /// @inheritdoc IRewardPool
  uint256 public rewardPerTokenPaid = 0;
  /// @inheritdoc IRewardPool
  uint256 public rewards = 0;

  // --- Init ---

  /**
   * @param _rewardToken Address of the reward token
   */
  constructor(address _rewardToken) Authorizable(msg.sender) validParams {
    if (_rewardToken == address(0)) revert RewardPool_InvalidRewardToken();
    rewardToken = IERC20(_rewardToken);
    _params.duration = 7 days;
    _params.newRewardRatio = 830;
  }

  // --- Methods ---

  /// @inheritdoc IRewardPool
  function lastTimeRewardApplicable() public view returns (uint256 _lastTime) {
    return Math.min(block.timestamp, periodFinish);
  }

  /// @inheritdoc IRewardPool
  function stake(uint256 _wad) external updateReward(msg.sender) isAuthorized {
    if (_wad == 0) revert RewardPool_StakeNullAmount();
    _totalStaked += _wad;
    emit RewardPool_Staked(msg.sender, _wad);
  }

  /// @inheritdoc IRewardPool
  function increaseStake(uint256 _wad) external isAuthorized {
    if (_wad == 0) revert RewardPool_IncreaseStakeNullAmount();
    _totalStaked += _wad;
    emit RewardPool_IncreaseStake(msg.sender, _wad);
  }

  /// @inheritdoc IRewardPool
  function decreaseStake(uint256 _wad) external isAuthorized {
    if (_wad == 0) revert RewardPool_DecreaseStakeNullAmount();
    if (_wad > _totalStaked) revert RewardPool_InsufficientBalance();
    _totalStaked -= _wad;
    emit RewardPool_DecreaseStake(msg.sender, _wad);
  }

  /// @inheritdoc IRewardPool
  function withdraw(uint256 _wad, bool _claim) external updateReward(msg.sender) isAuthorized {
    if (_wad == 0) revert RewardPool_WithdrawNullAmount();
    if (_wad > _totalStaked) revert RewardPool_InsufficientBalance();
    _totalStaked -= _wad;
    emit RewardPool_Withdrawn(msg.sender, _wad);
    if (_claim) {
      _getReward(msg.sender);
    }
  }

  /// @inheritdoc IRewardPool
  function getReward() external updateReward(msg.sender) isAuthorized {
    _getReward(msg.sender);
  }

  function _getReward(address _account) internal {
    uint256 _reward = earned();
    if (_reward > 0) {
      rewards = 0;
      rewardToken.safeTransfer(_account, _reward);
      emit RewardPool_RewardPaid(_account, _reward);
    }
  }

  /// @inheritdoc IRewardPool
  function rewardPerToken() public view returns (uint256) {
    if (_totalStaked == 0) return rewardPerTokenStored;
    uint256 _timeElapsed = lastTimeRewardApplicable() - lastUpdateTime;
    return rewardPerTokenStored + ((_timeElapsed * rewardRate * 1e18) / _totalStaked);
  }

  /// @inheritdoc IRewardPool
  function earned() public view returns (uint256) {
    return ((_totalStaked * (rewardPerToken() - rewardPerTokenPaid)) / 1e18) + rewards;
  }

  /// @inheritdoc IRewardPool
  function queueNewRewards(uint256 _rewardsToQueue) external isAuthorized {
    uint256 _totalRewards = _rewardsToQueue + queuedRewards;

    if (block.timestamp >= periodFinish) {
      notifyRewardAmount(_totalRewards);
      queuedRewards = 0;
      return;
    }

    uint256 _elapsedTime = block.timestamp - (periodFinish - _params.duration);
    uint256 _currentAtNow = rewardRate * _elapsedTime;
    uint256 _queuedRatio = (_currentAtNow * 1000) / _totalRewards;

    if (_queuedRatio < _params.newRewardRatio) {
      notifyRewardAmount(_totalRewards);
      queuedRewards = 0;
    } else {
      queuedRewards = _totalRewards;
    }
  }

  /// @inheritdoc IRewardPool
  function notifyRewardAmount(uint256 _reward) public updateReward(address(0)) isAuthorized {
    if (_reward == 0) revert RewardPool_InvalidRewardAmount();
    historicalRewards = historicalRewards + _reward;
    if (block.timestamp >= periodFinish) {
      rewardRate = _reward / _params.duration;
    } else {
      uint256 _remaining = periodFinish - block.timestamp;
      uint256 _leftover = _remaining * rewardRate;
      _reward = _reward + _leftover;
      rewardRate = _reward / _params.duration;
    }
    currentRewards = _reward;
    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp + _params.duration;
    emit RewardPool_RewardAdded(_reward);
  }

  /// @inheritdoc IRewardPool
  function emergencyWithdraw(address _rescueReceiver, uint256 _wad) external isAuthorized {
    if (_wad == 0) revert RewardPool_WithdrawNullAmount();
    IERC20(rewardToken).safeTransfer(_rescueReceiver, _wad);
    emit RewardPool_EmergencyWithdrawal(msg.sender, _wad);
  }

  // --- Modifiers ---

  modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (_account != address(0)) {
      rewards = earned();
      rewardPerTokenPaid = rewardPerTokenStored;
    }
    _;
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    if (_param == 'duration') _params.duration = _uint256;
    else if (_param == 'newRewardRatio') _params.newRewardRatio = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.duration.assertNonNull().assertGt(0);
    _params.newRewardRatio.assertNonNull().assertGt(0);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  IRewardPoolFactory
 * @notice Interface for the RewardPool factory contract
 * @dev    Handles deployment and tracking of RewardPool contracts
 */
interface IRewardPoolFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new RewardPool contract is deployed
   * @param _rewardPool Address of the deployed RewardPool contract
   * @param _rewardToken Address of the reward token
   * @param _stakingManager Address of the staking manager
   * @param _duration Duration of rewards distribution
   * @param _newRewardRatio Ratio for accepting new rewards
   */
  event DeployRewardPool(
    address indexed _rewardPool,
    address indexed _rewardToken,
    address indexed _stakingManager,
    uint256 _duration,
    uint256 _newRewardRatio
  );

  // --- Errors ---

  /// @notice Thrown when attempting to deploy with a null reward token address
  error RewardPoolFactory_NullRewardToken();

  /// @notice Thrown when attempting to deploy with a null staking manager address
  error RewardPoolFactory_NullStakingManager();

  // --- Methods ---

  /**
   * @notice Deploys a new RewardPool contract
   * @param _rewardToken Address of the reward token
   * @return _rewardPool Address of the deployed RewardPool contract
   * @param _stakingManager Address of the staking manager
   * @param _duration Duration of rewards distribution
   * @param _newRewardRatio Ratio for accepting new rewards
   * @dev Only callable by authorized addresses
   */
  function deployRewardPool(
    address _rewardToken,
    address _stakingManager,
    uint256 _duration,
    uint256 _newRewardRatio
  ) external returns (IRewardPool _rewardPool);

  // --- Views ---

  /**
   * @notice Returns the list of all deployed RewardPool contracts
   * @return _rewardPoolsList List of RewardPool contract addresses
   */
  function rewardPoolsList() external view returns (address[] memory _rewardPoolsList);
}

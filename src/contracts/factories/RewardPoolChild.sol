// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IRewardPoolChild} from '@interfaces/factories/IRewardPoolChild.sol';

import {RewardPool} from '@contracts/tokens/RewardPool.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  RewardPoolChild
 * @notice This contract inherits all the functionality of RewardPool to be factory deployed
 */
contract RewardPoolChild is RewardPool, FactoryChild, IRewardPoolChild {
  // --- Init ---

  /**
   * @param  _rewardToken Address of the reward token
   * @param _stakingManager Address of the staking manager
   * @param _duration Duration of rewards distribution
   * @param _newRewardRatio Ratio for accepting new rewards
   */
  constructor(
    address _rewardToken,
    address _stakingManager,
    uint256 _duration,
    uint256 _newRewardRatio,
    address _deployer
  ) RewardPool(_rewardToken, _stakingManager, _duration, _newRewardRatio, _deployer) {}
}

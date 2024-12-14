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
   */
  constructor(address _rewardToken) RewardPool(_rewardToken) {}
}

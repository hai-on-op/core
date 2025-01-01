// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {RewardPoolFactory, IRewardPoolFactory, EnumerableSet} from '@contracts/factories/RewardPoolFactory.sol';

contract RewardPoolFactoryForTest is RewardPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor() RewardPoolFactory() {}

  function addRewardPool(address _rewardPool) external {
    _rewardPools.add(_rewardPool);
  }
}

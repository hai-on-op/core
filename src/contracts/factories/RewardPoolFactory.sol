// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IRewardPoolFactory} from '@interfaces/factories/IRewardPoolFactory.sol';
import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';

import {RewardPoolChild} from '@contracts/factories/RewardPoolChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  RewardPoolFactory
 * @notice This contract is used to deploy RewardPool contracts
 * @dev    The deployed contracts are RewardPoolChild instances
 */
contract RewardPoolFactory is Authorizable, IRewardPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed RewardPool contracts
  EnumerableSet.AddressSet internal _rewardPools;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IRewardPoolFactory
  function deployRewardPool(
    address _rewardToken,
    address _stakingManager,
    uint256 _duration,
    uint256 _newRewardRatio
  ) external isAuthorized returns (IRewardPool _rewardPool) {
    if (_rewardToken == address(0)) {
      revert RewardPoolFactory_NullRewardToken();
    }

    if (_stakingManager == address(0)) {
      revert RewardPoolFactory_NullStakingManager();
    }

    _rewardPool = new RewardPoolChild(_rewardToken, _stakingManager, _duration, _newRewardRatio, msg.sender);

    _rewardPools.add(address(_rewardPool));

    emit DeployRewardPool(address(_rewardPool), _rewardToken, _stakingManager, _duration, _newRewardRatio);
  }

  /// @inheritdoc IRewardPoolFactory
  function rewardPoolsList() external view returns (address[] memory _rewardPoolsList) {
    return _rewardPools.values();
  }
}

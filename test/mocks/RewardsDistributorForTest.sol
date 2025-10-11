// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IRewardsDistributor} from '@interfaces/external/IRewardsDistributor.sol';

contract RewardsDistributorForTest is IRewardsDistributor {
  constructor() {}

  /// @inheritdoc IRewardsDistributor
  function claim(uint256 tokenId) external returns (uint256) {
    return 0;
  }

  /// @inheritdoc IRewardsDistributor
  function claimMany(uint256[] calldata tokenIds) external returns (bool) {
    return true;
  }

  /// @inheritdoc IRewardsDistributor
  function claimable(uint256 tokenId) external view returns (uint256) {
    return 0;
  }
}

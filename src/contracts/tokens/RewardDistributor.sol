// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardDistributor} from "@interfaces/tokens/IRewardDistributor.sol";
import {Authorizable} from "@contracts/utils/Authorizable.sol";

/**
 * @title  RewardDistributor
 * @notice This contract distributes rewards to users to claim every 24 hours
 */
contract RewardDistributor is Authorizable, IRewardDistributor {
    // --- Data ---

    /// @inheritdoc IRewardDistributor
    uint256 public epochCounter;
    /// @inheritdoc IRewardDistributor
    uint256 public epochDuration;
    /// @inheritdoc IRewardDistributor
    uint256 public lastUpdatedTime;
    /// @inheritdoc IRewardDistributor
    address public rootSetter;

    /// @inheritdoc IRewardDistributor
    mapping(address _token => bytes32 _root) public merkleRoots;
    /// @inheritdoc IRewardDistributor
    mapping(bytes32 _root => mapping(address _user => bool _hasClaimed))
        public isClaimed;
}

// rewardSetter
// merkleRoots
// merkleRootCounter
// duration
// lastSettedMerkleRoot

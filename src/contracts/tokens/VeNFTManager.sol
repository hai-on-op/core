// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IVeNFTManager} from '@interfaces/tokens/IVeNFTManager.sol';

import {IVoter} from '@interfaces/external/IVoter.sol';
import {IRootVotingRewardsFactory} from '@interfaces/external/IRootVotingRewardsFactory.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

/**
 * @title  VeNFTManager
 * @notice This contract is used to the protocol veNFTs
 */
contract VeNFTManager is Authorizable, Modifiable, IVeNFTManager {
  // --- Registry ---

  /// @inheritdoc IVeNFTManager
  IRootVotingRewardsFactory public rootVotingRewardsFactory;

  /// @inheritdoc IVeNFTManager
  IVoter public voter;

  // --- Data ---

  /// @inheritdoc IVeNFTManager
  address public secondaryManager;

  // --- Init ---

  /**
   * @param  _secondaryManager Address of the manager (EOA or contract)
   * @param  _voter Address of the voter contract
   * @param  _rootVotingRewardsFactory Address of the root voting rewards factory contract
   */
  constructor(
    address _secondaryManager,
    address _voter,
    address _rootVotingRewardsFactory
  ) Authorizable(msg.sender) validParams {
    if (_secondaryManager == address(0)) {
      revert VeNFTManager_NullSecondary();
    }
    if (_voter == address(0)) {
      revert VeNFTManager_NullVoter();
    }
    if (_rootVotingRewardsFactory == address(0)) {
      revert VeNFTManager_NullRootVotingRewardsFactory();
    }

    secondaryManager = _secondaryManager;
    voter = IVoter(_voter);
    rootVotingRewardsFactory = IRootVotingRewardsFactory(_rootVotingRewardsFactory);
  }

  /// @inheritdoc IVeNFTManager
  // Called by secondary to deposit veNFTs once they reach 500k VELO locked
  function depositVeNFT() external {
    // TODO: Implement
  }

  /// @inheritdoc IVeNFTManager
  // Called by tertiary to vote with veNFTs
  function vote() external {
    // TODO: Implement
  }

  /// @inheritdoc IVeNFTManager
  // Called by tertiary
  function claimBribes() external {
    // TODO: Implement
  }

  function claimVotingRewards() external {
    // TODO: Implement
  }

  function claimAndLockRebases() external {
    // TODO: Implement
  }

  function setSuperchainRecipient() external {
    // TODO: Implement
  }

  function setTertiary() external {
    // TODO: Implement
  }

  function setSecondary() external {
    // TODO: Implement
  }
}

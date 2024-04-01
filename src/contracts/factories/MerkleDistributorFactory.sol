// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributorFactory} from '@interfaces/factories/IMerkleDistributorFactory.sol';
import {IMerkleDistributor} from '@interfaces/tokens/IMerkleDistributor.sol';

import {MerkleDistributorChild} from '@contracts/factories/MerkleDistributorChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

/**
 * @title  MerkleDistributorFactory
 * @notice This contract is used to deploy MerkleDistributor contracts
 * @dev    The deployed contracts are MerkleDistributorChild instances
 */
contract MerkleDistributorFactory is Authorizable, IMerkleDistributorFactory {
  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  /// @inheritdoc IMerkleDistributorFactory
  function deployMerkleDistributor(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) external isAuthorized returns (IMerkleDistributor _merkleDistributor) {
    _merkleDistributor = new MerkleDistributorChild(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd);
    emit DeployMerkleDistributor(
      address(_merkleDistributor), _token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }
}

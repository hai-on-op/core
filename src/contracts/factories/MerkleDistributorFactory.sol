// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributorFactory} from '@interfaces/factories/IMerkleDistributorFactory.sol';
import {IMerkleDistributor} from '@interfaces/utils/IMerkleDistributor.sol';

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
    IMerkleDistributor.MerkleDistributorParams memory _merkleDistributorParams
  ) external isAuthorized returns (IMerkleDistributor _merkleDistributor) {
    _merkleDistributor = new MerkleDistributorChild(_token, _merkleDistributorParams);
    emit DeployMerkleDistributor(
      address(_merkleDistributor),
      _token,
      _merkleDistributorParams.root,
      _merkleDistributorParams.totalClaimable,
      _merkleDistributorParams.claimPeriodStart,
      _merkleDistributorParams.claimPeriodEnd
    );
  }
}

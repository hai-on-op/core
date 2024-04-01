// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributorChild} from '@interfaces/factories/IMerkleDistributorChild.sol';

import {MerkleDistributor} from '@contracts/tokens/MerkleDistributor.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  MerkleDistributorChild
 * @notice This contract inherits all the functionality of MerkleDistributor to be factory deployed
 */
contract MerkleDistributorChild is MerkleDistributor, FactoryChild, IMerkleDistributorChild {
  // --- Init ---

  /**
   *
   * @param _token Address of the ERC20 token to be distributed
   * @param _root Bytes32 representation of the merkle root
   * @param _totalClaimable Total amount of tokens to be distributed
   * @param _claimPeriodStart Timestamp when the claim period starts
   * @param _claimPeriodEnd Timestamp when the claim period ends
   */
  constructor(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) MerkleDistributor(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd) {}
}

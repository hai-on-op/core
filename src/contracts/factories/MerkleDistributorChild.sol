// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributorChild} from '@interfaces/factories/IMerkleDistributorChild.sol';

import {MerkleDistributor} from '@contracts/utils/MerkleDistributor.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  MerkleDistributorChild
 * @notice This contract inherits all the functionality of MerkleDistributor to be factory deployed
 */
contract MerkleDistributorChild is MerkleDistributor, FactoryChild, IMerkleDistributorChild {
  // --- Init ---

  /**
   *
   * @param  _token Address of the ERC20 token to be distributed
   * @param  _merkleDistributorParams MerkleDistributor valid parameters struct
   */
  constructor(
    address _token,
    MerkleDistributorParams memory _merkleDistributorParams
  ) MerkleDistributor(_token, _merkleDistributorParams) {}
}

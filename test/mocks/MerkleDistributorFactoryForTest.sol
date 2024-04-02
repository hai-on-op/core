// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {MerkleDistributorFactory, IMerkleDistributorFactory} from '@contracts/factories/MerkleDistributorFactory.sol';
import {IMerkleDistributor} from '@interfaces/tokens/IMerkleDistributor.sol';

contract MerkleDistributorFactoryForTest is MerkleDistributorFactory {
  constructor() MerkleDistributorFactory() {}
}

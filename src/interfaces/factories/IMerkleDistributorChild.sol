// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributor} from '@interfaces/tokens/IMerkleDistributor.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IMerkleDistributorChild is IMerkleDistributor, IFactoryChild {}

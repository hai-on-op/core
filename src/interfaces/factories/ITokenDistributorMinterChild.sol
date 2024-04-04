// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorMinter} from '@interfaces/tokens/ITokenDistributorMinter.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface ITokenDistributorMinterChild is ITokenDistributorMinter, IFactoryChild {}

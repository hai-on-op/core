// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorTransfer} from '@interfaces/tokens/ITokenDistributorTransfer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface ITokenDistributorTransferChild is ITokenDistributorTransfer, IFactoryChild {}

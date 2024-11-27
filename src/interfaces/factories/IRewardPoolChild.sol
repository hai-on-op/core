// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IRewardPoolChild is IRewardPool, IFactoryChild {}

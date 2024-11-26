// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IRewardPool} from "@interfaces/tokens/RewardPool.sol";

import {IFactoryChild} from "@interfaces/factories/FactoryChild.sol";

interface IRewardPoolChild is IRewardPool, IFactoryChild {}

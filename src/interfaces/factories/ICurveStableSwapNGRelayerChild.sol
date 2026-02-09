// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICurveStableSwapNGRelayer} from '@interfaces/oracles/ICurveStableSwapNGRelayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface ICurveStableSwapNGRelayerChild is ICurveStableSwapNGRelayer, IFactoryChild {}

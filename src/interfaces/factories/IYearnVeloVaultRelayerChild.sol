// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IYearnVeloVaultRelayer} from '@interfaces/oracles/IYearnVeloVaultRelayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IYearnVeloVaultRelayerChild is IYearnVeloVaultRelayer, IFactoryChild {}

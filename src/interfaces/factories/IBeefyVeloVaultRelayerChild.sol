// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBeefyVeloVaultRelayer} from '@interfaces/oracles/IBeefyVeloVaultRelayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IBeefyVeloVaultRelayerChild is IBeefyVeloVaultRelayer, IFactoryChild {}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBeefyVeloVaultRelayerChild} from '@interfaces/factories/IBeefyVeloVaultRelayerChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

import {BeefyVeloVaultRelayer} from '@contracts/oracles/BeefyVeloVaultRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  BeefyVeloVaultRelayerChild
 * @notice This contract inherits all the functionality of BeefyVeloVaultRelayer to be factory deployed
 */
contract BeefyVeloVaultRelayerChild is BeefyVeloVaultRelayer, FactoryChild, IBeefyVeloVaultRelayerChild {
  // --- Init ---

  /**
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   */
  constructor(
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) BeefyVeloVaultRelayer(_beefyVault, _veloPool, _veloLpOracle) {}
}

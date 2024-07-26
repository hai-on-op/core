// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBeefyVeloVaultRelayerChild} from '@interfaces/factories/IBeefyVeloVaultRelayerChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';

import {BeefyVeloVaultRelayer} from '@contracts/oracles/BeefyVeloVaultRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  BeefyVeloVaultRelayerChild
 * @notice This contract inherits all the functionality of BeefyVeloVaultRelayer to be factory deployed
 */
contract BeefyVeloVaultRelayerChild is BeefyVeloVaultRelayer, FactoryChild, IBeefyVeloVaultRelayerChild {
  // --- Init ---

  /**
   * @param  _token0priceSource Address of the price source for the first token in the velo pool
   * @param  _token1priceSource Address of the price source for the second token in the velo pool
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   */
  constructor(
    IBaseOracle _token0priceSource,
    IBaseOracle _token1priceSource,
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool
  ) BeefyVeloVaultRelayer(_token0priceSource, _token1priceSource, _beefyVault, _veloPool) {}
}

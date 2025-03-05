// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IYearnVeloVaultRelayerChild} from '@interfaces/factories/IYearnVeloVaultRelayerChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

import {YearnVeloVaultRelayer} from '@contracts/oracles/YearnVeloVaultRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  YearnVeloVaultRelayerChild
 * @notice This contract inherits all the functionality of YearnVeloVaultRelayer to be factory deployed
 */
contract YearnVeloVaultRelayerChild is YearnVeloVaultRelayer, FactoryChild, IYearnVeloVaultRelayerChild {
  // --- Init ---

  /**
   * @param  _yearnVault The address of the yearn vault contract
   * @param  _veloPool The address of the velo pool underlying the yearn vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   */
  constructor(
    IYearnVault _yearnVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) YearnVeloVaultRelayer(_yearnVault, _veloPool, _veloLpOracle) {}
}

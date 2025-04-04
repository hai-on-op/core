// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVeloVaultRelayer} from '@interfaces/oracles/IBeefyVeloVaultRelayer.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

import {Math, WAD} from '@libraries/Math.sol';

import {AbstractVeloVaultRelayer} from './AbstractVeloVaultRelayer.sol';

/**
 * @title  BeefyVeloVaultRelayer
 * @notice Deconstructs a Beefy Vault to it's Velodrome liquidity pool and that pool's constituent tokens to return a price feed
 * @dev  Requires an underlying Velodrome pool and price feeds for the pool's tokens
 */
contract BeefyVeloVaultRelayer is AbstractVeloVaultRelayer, IBeefyVeloVaultRelayer {
  using Math for uint256;

  // --- Registry ---
  /// @inheritdoc IBeefyVeloVaultRelayer
  IBeefyVaultV7 public beefyVault;

  // --- Init ---

  /**
   *
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   */
  constructor(
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) AbstractVeloVaultRelayer(_veloPool, _veloLpOracle, string(abi.encodePacked(_beefyVault.symbol(), ' / USD'))) {
    if (address(_beefyVault) == address(0)) {
      revert BeefyVeloVaultRelayer_NullBeefyVault();
    }

    beefyVault = _beefyVault;
  }

  function _getPricePerFullShare() internal view override returns (uint256 _pricePerFullShare) {
    return beefyVault.getPricePerFullShare();
  }
}

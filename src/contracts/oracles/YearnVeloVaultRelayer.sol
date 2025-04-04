// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IYearnVeloVaultRelayer} from '@interfaces/oracles/IYearnVeloVaultRelayer.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

import {Math, WAD} from '@libraries/Math.sol';

import {AbstractVeloVaultRelayer} from './AbstractVeloVaultRelayer.sol';

/**
 * @title  YearnVeloVaultRelayer
 * @notice Deconstructs a Yearn Vault to it's Velodrome liquidity pool and that pool's constituent tokens to return a price feed
 * @dev  Requires an underlying Velodrome pool and price feeds for the pool's tokens
 */
contract YearnVeloVaultRelayer is AbstractVeloVaultRelayer, IYearnVeloVaultRelayer {
  using Math for uint256;

  // --- Registry ---
  /// @inheritdoc IYearnVeloVaultRelayer
  IYearnVault public yearnVault;

  // --- Init ---

  /**
   *
   * @param  _yearnVault The address of the yearn vault contract
   * @param  _veloPool The address of the velo pool underlying the yearn vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   */
  constructor(
    IYearnVault _yearnVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) AbstractVeloVaultRelayer(_veloPool, _veloLpOracle, string(abi.encodePacked(_yearnVault.symbol(), ' / USD'))) {
    if (address(_yearnVault) == address(0)) {
      revert YearnVeloVaultRelayer_NullYearnVault();
    }

    yearnVault = _yearnVault;
  }

  function _getPricePerFullShare() internal view override returns (uint256 _pricePerFullShare) {
    return yearnVault.pricePerShare();
  }
}

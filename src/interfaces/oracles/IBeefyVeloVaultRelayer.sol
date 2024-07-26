// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';

interface IBeefyVeloVaultRelayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if either the provided token0 price source or the token1 price source are null
  error BeefyVeloVaultRelayer_NullPriceSource();

  /// @notice Throws if the provided beefy vault address is null
  error BeefyVeloVaultRelayer_NullBeefyVault();

  /// @notice Throws if the provided velo pool address is null
  error BeefyVeloVaultRelayer_NullVeloPool();

  /// @notice Throws if either of the provided price sources are invalid
  error BeefyVeloVaultRelayer_InvalidPriceSource();

  /**
   * @notice Address of the token0 price source that is used to calculate the price
   * @dev    Assumes that the price source is a valid IBaseOracle
   */
  function token0priceSource() external view returns (IBaseOracle _token0priceSource);

  /**
   * @notice Address of the token1 price source that is used to calculate the price
   * @dev    Assumes that the price source is a valid IBaseOracle
   */
  function token1priceSource() external view returns (IBaseOracle _token1priceSource);

  /**
   * @notice Address of the beefy vault
   * @dev    Assumes that the beefy vault is a valid IBeefyVaultV7
   */
  function beefyVault() external view returns (IBeefyVaultV7 _beefyVault);

  /**
   * @notice Address of the velo pool underlying the beefy vault
   * @dev    Assumes that the price source is a valid IVeloPool
   */
  function veloPool() external view returns (IVeloPool _veloPool);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

interface IAbstractVeloVaultRelayer is IBaseOracle {
  /**
   * @notice Emitted when the accepted vault price per full share is updated
   * @param _pricePerFullShare The new accepted price per full share [wad]
   */
  event UpdatePricePerFullShare(uint256 _pricePerFullShare);

  // --- Errors ---

  /// @notice Throws if the provided velo pool address is null
  error AbstractVeloVaultRelayer_NullVeloPool();

  /// @notice Throws if either of the provided velo lp oracle address is null
  error AbstractVeloVaultRelayer_NullVeloLpOracle();

  /// @notice Throws if the price is 0
  error AbstractVeloVaultRelayer_ZeroPrice();

  /// @notice Throws if the vault price per full share is 0
  error AbstractVeloVaultRelayer_InvalidPricePerFullShare();

  /**
   * @notice Address of the velo pool underlying the beefy vault
   * @dev    Assumes that the price source is a valid IVeloPool
   */
  function veloPool() external view returns (IVeloPool _veloPool);

  /**
   * @notice Address of the pessimistic velo lp oracle
   * @dev    Assumes that the price source is a valid IPessimisticVeloLpOracle
   */
  function veloLpOracle() external view returns (IPessimisticVeloLpOracle _veloPool);

  /// @notice Accepted vault price per full share used for collateral pricing [wad]
  function acceptedPricePerFullShare() external view returns (uint256 _acceptedPricePerFullShare);

  /// @notice Timestamp of the latest accepted price per full share update
  function lastPricePerFullShareUpdateTime() external view returns (uint256 _lastPricePerFullShareUpdateTime);

  /// @notice Updates the accepted vault price per full share, capping upward movement
  function updatePricePerFullShare() external returns (bool _updated);
}

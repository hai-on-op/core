// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

interface IYearnVeloVaultRelayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided yearn vault address is null
  error YearnVeloVaultRelayer_NullYearnVault();

  /// @notice Throws if the provided velo pool address is null
  error YearnVeloVaultRelayer_NullVeloPool();

  /// @notice Throws if either of the provided price sources are invalid
  error YearnVeloVaultRelayer_InvalidPriceSource();

  /// @notice Throws if either of the provided velo lp oracle address is null
  error YearnVeloVaultRelayer_NullVeloLpOracle();

  /**
   * @notice Address of the yearn vault
   * @dev    Assumes that the yearn vault is a valid IYearnVault
   */
  function yearnVault() external view returns (IYearnVault _yearnVault);

  /**
   * @notice Address of the velo pool underlying the yearn vault
   * @dev    Assumes that the price source is a valid IVeloPool
   */
  function veloPool() external view returns (IVeloPool _veloPool);

  /**
   * @notice Address of the pessimistic velo lp oracle
   * @dev    Assumes that the price source is a valid IPessimisticVeloLpOracle
   */
  function veloLpOracle() external view returns (IPessimisticVeloLpOracle _veloPool);
}

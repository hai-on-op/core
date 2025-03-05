// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAbstractVeloVaultRelayer} from '@interfaces/oracles/IAbstractVeloVaultRelayer.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';

interface IYearnVeloVaultRelayer is IAbstractVeloVaultRelayer {
  // --- Errors ---

  /// @notice Throws if the provided yearn vault address is null
  error YearnVeloVaultRelayer_NullYearnVault();

  /// @notice Throws if either of the provided price sources are invalid
  error YearnVeloVaultRelayer_InvalidPriceSource();

  /**
   * @notice Address of the yearn vault
   * @dev    Assumes that the yearn vault is a valid IYearnVault
   */
  function yearnVault() external view returns (IYearnVault _yearnVault);
}

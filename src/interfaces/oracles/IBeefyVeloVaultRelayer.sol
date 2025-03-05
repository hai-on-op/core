// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAbstractVeloVaultRelayer} from '@interfaces/oracles/IAbstractVeloVaultRelayer.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';

interface IBeefyVeloVaultRelayer is IAbstractVeloVaultRelayer {
  // --- Errors ---

  /// @notice Throws if the provided beefy vault address is null
  error BeefyVeloVaultRelayer_NullBeefyVault();

  /// @notice Throws if either of the provided price sources are invalid
  error BeefyVeloVaultRelayer_InvalidPriceSource();

  /**
   * @notice Address of the beefy vault
   * @dev    Assumes that the beefy vault is a valid IBeefyVaultV7
   */
  function beefyVault() external view returns (IBeefyVaultV7 _beefyVault);
}

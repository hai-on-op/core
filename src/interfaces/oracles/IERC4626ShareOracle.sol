// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

interface IERC4626ShareOracle is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided vault address is null
  error ERC4626ShareOracle_NullVault();

  /// @notice Throws if the provided asset oracle address is null
  error ERC4626ShareOracle_NullAssetOracle();

  // --- Registry ---

  /// @notice Address of the ERC4626 vault whose share price is being quoted
  function vault() external view returns (IERC4626 _vault);

  /// @notice Address of the oracle used to price the vault's underlying asset
  function assetOracle() external view returns (IBaseOracle _assetOracle);

  // --- Data ---

  /// @notice One full share unit, denominated in the vault share token decimals
  function shareUnit() external view returns (uint256 _shareUnit);

  /// @notice One full asset unit, denominated in the vault asset token decimals
  function assetUnit() external view returns (uint256 _assetUnit);
}

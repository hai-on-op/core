// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

interface IHaiVeloV2Oracle is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided price source address is null
  error HaiVeloV2Oracle_NullPriceSource();

  // --- Registry ---

  /**
   * @notice Address of the undelayed, 18-decimal AERO/USD price source
   * @dev    Assumes that the price source is a valid IBaseOracle that validates price freshness
   */
  function priceSource() external view returns (IBaseOracle _priceSource);
}

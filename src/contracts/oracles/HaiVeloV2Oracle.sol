// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IHaiVeloV2Oracle} from '@interfaces/oracles/IHaiVeloV2Oracle.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

/**
 * @title  HaiVeloV2Oracle
 * @notice Prices haiVELOV2 at 0.044 AERO per token, returning an 18-decimal USD price
 * @dev    Use the undelayed AERO/USD IBaseOracle source, which validates price freshness.
 *         Wrap this oracle in the existing DelayedOracle with a 3600-second delay for protocol use.
 */
contract HaiVeloV2Oracle is IHaiVeloV2Oracle {
  // --- Registry ---

  /// @inheritdoc IHaiVeloV2Oracle
  IBaseOracle public immutable priceSource;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol = 'haiVELOV2 / USD';

  // --- Init ---

  /// @param _priceSource The undelayed, 18-decimal AERO/USD price source
  constructor(IBaseOracle _priceSource) {
    if (address(_priceSource) == address(0)) revert HaiVeloV2Oracle_NullPriceSource();
    priceSource = _priceSource;
  }

  // --- Views ---

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return _getResultWithValidity();
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    bool _validity;
    (_result, _validity) = _getResultWithValidity();
    if (!_validity) revert InvalidPriceFeed();
  }

  // --- Internal ---

  function _getResultWithValidity() internal view returns (uint256 _result, bool _validity) {
    try priceSource.getResultWithValidity() returns (uint256 _aeroPrice, bool _aeroValidity) {
      if (!_aeroValidity) return (0, false);

      // Round down at the fixed migration rate without overflowing the intermediate product.
      _result = Math.mulDiv(_aeroPrice, 44, 1000);
      _validity = _result > 0;
    } catch {
      return (0, false);
    }
  }
}

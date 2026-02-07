// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';

interface ICurveStableSwapNGRelayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided pool address is null
  error CurveStableSwapNGRelayer_NullPool();

  /// @notice Throws if the provided oracle index is invalid for the pool
  error CurveStableSwapNGRelayer_InvalidOracleIndex();

  // --- Registry ---

  /// @notice Address of the Curve StableSwapNG pool used to consult the EMA oracle
  function pool() external view returns (ICurveStableSwapNG _pool);

  /// @notice Address of the base token used to consult the quote from
  function baseToken() external view returns (address _baseToken);

  /// @notice Address of the token used as a quote reference
  function quoteToken() external view returns (address _quoteToken);

  // --- Data ---

  /// @notice Index used for Curve's price_oracle(i) (prices coin i+1 vs coin0)
  function oracleIndex() external view returns (uint256 _oracleIndex);

  /// @notice Whether the oracle output is inverted (quote/base instead of base/quote)
  function inverted() external view returns (bool _inverted);
}

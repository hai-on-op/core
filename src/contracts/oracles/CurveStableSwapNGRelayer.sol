// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICurveStableSwapNGRelayer} from '@interfaces/oracles/ICurveStableSwapNGRelayer.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {Math, WAD} from '@libraries/Math.sol';

/**
 * @title  CurveStableSwapNGRelayer
 * @notice This contract consults a Curve StableSwap-NG EMA oracle and transforms the result into a standard IBaseOracle feed
 * @dev    The EMA oracle returns a 1e18 price for coin i+1 vs coin0 (price_oracle(i));
 *         this relayer can price any pair using coin0 as the common denominator
 */
contract CurveStableSwapNGRelayer is IBaseOracle, ICurveStableSwapNGRelayer {
  using Math for uint256;
  // --- Registry ---

  /// @inheritdoc ICurveStableSwapNGRelayer
  ICurveStableSwapNG public pool;
  /// @inheritdoc ICurveStableSwapNGRelayer
  address public baseToken;
  /// @inheritdoc ICurveStableSwapNGRelayer
  address public quoteToken;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc ICurveStableSwapNGRelayer
  uint256 public baseIndex;
  /// @inheritdoc ICurveStableSwapNGRelayer
  uint256 public quoteIndex;

  /// @inheritdoc ICurveStableSwapNGRelayer
  uint256 public baseRateMultiplier;
  /// @inheritdoc ICurveStableSwapNGRelayer
  uint256 public quoteRateMultiplier;

  // --- Init ---

  /**
   * @param  _pool The Curve StableSwapNG pool address
   * @param  _baseIndex Index of the base token in the pool (0 = coin0)
   * @param  _quoteIndex Index of the quote token in the pool (0 = coin0)
   */
  constructor(address _pool, uint256 _baseIndex, uint256 _quoteIndex) {
    if (_pool == address(0)) revert CurveStableSwapNGRelayer_NullPool();
    if (_baseIndex == _quoteIndex) {
      revert CurveStableSwapNGRelayer_InvalidOracleIndex();
    }

    pool = ICurveStableSwapNG(_pool);
    baseIndex = _baseIndex;
    quoteIndex = _quoteIndex;

    // price_oracle(i) prices coin i+1 vs coin0
    try pool.coins(_baseIndex) returns (address _baseToken) {
      baseToken = _baseToken;
    } catch {
      revert CurveStableSwapNGRelayer_InvalidOracleIndex();
    }
    try pool.coins(_quoteIndex) returns (address _quoteToken) {
      quoteToken = _quoteToken;
    } catch {
      revert CurveStableSwapNGRelayer_InvalidOracleIndex();
    }
    // Cache rate_multipliers (10**(36 - decimals)) to isolate oracle rates from stored_rates
    baseRateMultiplier = 10 ** (36 - IERC20Metadata(baseToken).decimals());
    quoteRateMultiplier = 10 ** (36 - IERC20Metadata(quoteToken).decimals());
    // Symbol follows the UniV3 relayer convention: base / quote (price is quote per base)
    string memory _baseSymbol = IERC20Metadata(baseToken).symbol();
    string memory _quoteSymbol = IERC20Metadata(quoteToken).symbol();
    symbol = string(abi.encodePacked(_baseSymbol, ' / ', _quoteSymbol));
  }

  // --- Views ---

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    uint256 _priceBase = baseIndex == 0 ? WAD : pool.price_oracle(baseIndex - 1);
    uint256 _priceQuote = quoteIndex == 0 ? WAD : pool.price_oracle(quoteIndex - 1);
    if (_priceBase == 0 || _priceQuote == 0) return (0, false);
    uint256 _price = _priceBase.wdiv(_priceQuote);
    _price = _adjustForOracleRates(_price);
    _result = _parseResult(_price);
    _validity = true;
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    uint256 _priceBase = baseIndex == 0 ? WAD : pool.price_oracle(baseIndex - 1);
    uint256 _priceQuote = quoteIndex == 0 ? WAD : pool.price_oracle(quoteIndex - 1);
    if (_priceBase == 0 || _priceQuote == 0) revert InvalidPriceFeed();
    uint256 _price = _priceBase.wdiv(_priceQuote);
    _price = _adjustForOracleRates(_price);
    _result = _parseResult(_price);
  }

  // --- Internal ---

  /**
   * @notice Adjusts the virtual-space price for token oracle rates
   * @dev    price_oracle operates in rate-adjusted virtual space (xp = balance * stored_rate).
   *         stored_rate = rate_multiplier * oracle_rate, where rate_multiplier = 10**(36-decimals).
   *         We divide out the rate_multipliers to isolate the oracle rate ratio:
   *         actual_price = virtual_price * (stored_rate[base] / rate_multiplier[base])
   *                                      / (stored_rate[quote] / rate_multiplier[quote])
   *         For plain tokens (no oracle), oracle_rate = 1e18, so the adjustment is a no-op.
   */
  function _adjustForOracleRates(uint256 _price) internal view returns (uint256) {
    uint256[] memory _rates = pool.stored_rates();
    uint256 _baseOracleRate = _rates[baseIndex] * WAD / baseRateMultiplier;
    uint256 _quoteOracleRate = _rates[quoteIndex] * WAD / quoteRateMultiplier;
    return _price.wmul(_baseOracleRate).wdiv(_quoteOracleRate);
  }

  /// @notice Parses the oracle result into 18 decimals format
  function _parseResult(uint256 _price) internal view returns (uint256 _result) {
    return _price;
  }
}

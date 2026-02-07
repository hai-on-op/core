// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICurveStableSwapNGRelayer} from '@interfaces/oracles/ICurveStableSwapNGRelayer.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {WAD} from '@libraries/Math.sol';

/**
 * @title  CurveStableSwapNGRelayer
 * @notice This contract consults a Curve StableSwap-NG EMA oracle and transforms the result into a standard IBaseOracle feed
 * @dev    The EMA oracle returns a 1e18 price for coin i+1 vs coin0 (price_oracle(i))
 */
contract CurveStableSwapNGRelayer is IBaseOracle, ICurveStableSwapNGRelayer {
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
  uint256 public oracleIndex;
  /// @inheritdoc ICurveStableSwapNGRelayer
  bool public inverted;

  // --- Init ---

  /**
   * @param  _pool The Curve StableSwapNG pool address
   * @param  _oracleIndex The index used for price_oracle(i) (prices coin i+1 vs coin0)
   * @param  _inverted Whether to invert the oracle output (quote/base instead of base/quote)
   */
  constructor(address _pool, uint256 _oracleIndex, bool _inverted) {
    if (_pool == address(0)) revert CurveStableSwapNGRelayer_NullPool();

    pool = ICurveStableSwapNG(_pool);
    oracleIndex = _oracleIndex;
    inverted = _inverted;

    // price_oracle(i) prices coin i+1 vs coin0
    quoteToken = pool.coins(0);
    try pool.coins(_oracleIndex + 1) returns (address _baseToken) {
      baseToken = _baseToken;
    } catch {
      revert CurveStableSwapNGRelayer_InvalidOracleIndex();
    }
    // Symbol follows the UniV3 relayer convention: base / quote (price is quote per base)
    string memory _baseSymbol = IERC20Metadata(baseToken).symbol();
    string memory _quoteSymbol = IERC20Metadata(quoteToken).symbol();
    if (inverted) {
      symbol = string(abi.encodePacked(_quoteSymbol, ' / ', _baseSymbol));
    } else {
      symbol = string(abi.encodePacked(_baseSymbol, ' / ', _quoteSymbol));
    }
  }

  // --- Views ---

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    uint256 _price = pool.price_oracle(oracleIndex);
    if (_price == 0) return (0, false);
    _result = _parseResult(_price);
    _validity = true;
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    uint256 _price = pool.price_oracle(oracleIndex);
    if (_price == 0) revert InvalidPriceFeed();
    _result = _parseResult(_price);
  }

  // --- Internal ---

  /// @notice Parses the oracle result into 18 decimals format (inverts if needed)
  function _parseResult(uint256 _price) internal view returns (uint256 _result) {
    if (!inverted) return _price;
    return (WAD * WAD) / _price;
  }
}

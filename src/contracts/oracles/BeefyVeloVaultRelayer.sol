// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVeloVaultRelayer} from '@interfaces/oracles/IBeefyVeloVaultRelayer.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';

import {Math, WAD} from '@libraries/Math.sol';

/**
 * @title  BeefyVeloVaultRelayer
 * @notice Deconstructs a Beefy Vault to it's Velodrome liquidity pool and that pool's constituent tokens to return a price feed
 * @dev    Requires an underlying Velodrome pool and price feeds for the pool's tokens
 */
contract BeefyVeloVaultRelayer is IBaseOracle, IBeefyVeloVaultRelayer {
  using Math for uint256;

  // --- Registry ---
  /// @inheritdoc IBeefyVeloVaultRelayer
  IBaseOracle public token0priceSource;

  /// @inheritdoc IBeefyVeloVaultRelayer
  IBaseOracle public token1priceSource;

  /// @inheritdoc IBeefyVeloVaultRelayer
  IBeefyVaultV7 public beefyVault;

  /// @inheritdoc IBeefyVeloVaultRelayer
  IVeloPool public veloPool;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  // --- Init ---

  /**
   *
   * @param  _token0priceSource Address of the price source for the first token in the velo pool
   * @param  _token1priceSource Address of the price source for the second token in the velo pool
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   */
  constructor(
    IBaseOracle _token0priceSource,
    IBaseOracle _token1priceSource,
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool
  ) {
    if (address(_token0priceSource) == address(0)) {
      revert BeefyVeloVaultRelayer_NullPriceSource();
    }
    if (address(_token1priceSource) == address(0)) {
      revert BeefyVeloVaultRelayer_NullPriceSource();
    }
    if (address(_beefyVault) == address(0)) {
      revert BeefyVeloVaultRelayer_NullBeefyVault();
    }
    if (address(_veloPool) == address(0)) {
      revert BeefyVeloVaultRelayer_NullVeloPool();
    }

    token0priceSource = _token0priceSource;
    token1priceSource = _token1priceSource;
    beefyVault = _beefyVault;
    veloPool = _veloPool;

    symbol = string(abi.encodePacked(_beefyVault.symbol(), ' / USD '));
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    (uint256 _token0priceSourceValue, bool _token0priceSourceValidity) = token0priceSource.getResultWithValidity();

    (uint256 _token1priceSourceValue, bool _token1priceSourceValidity) = token1priceSource.getResultWithValidity();

    uint256 _totalValue = _getCombinedPriceValue(_token0priceSourceValue, _token1priceSourceValue);

    _validity = _token0priceSourceValidity && _token1priceSourceValidity;

    return (_totalValue, _validity);
  }
  /// @inheritdoc IBaseOracle

  function read() external view returns (uint256 _result) {
    (uint256 _token0priceSourceValue, bool _token0priceSourceValidity) = token0priceSource.getResultWithValidity();

    (uint256 _token1priceSourceValue, bool _token1priceSourceValidity) = token1priceSource.getResultWithValidity();

    if (!_token0priceSourceValidity || !_token1priceSourceValidity) {
      revert BeefyVeloVaultRelayer_InvalidPriceSource();
    }

    uint256 _totalValue = _getCombinedPriceValue(_token0priceSourceValue, _token1priceSourceValue);

    return _totalValue;
  }

  /// @notice Returns the combined price of the two tokens in the velo pool
  function _getCombinedPriceValue(
    uint256 _token0priceSourceValue,
    uint256 _token1priceSourceValue
  ) internal view returns (uint256 _combinedPriceValue) {
    // 1 mooToken
    uint256 _mooTokenBalance = 1_000_000_000_000_000_000;

    // # of token0 in velo pool
    uint256 _reserve0 = veloPool.reserve0();
    // # of token in velo pool
    uint256 _reserve1 = veloPool.reserve1();

    // # of velo LP tokens in 1 mooToken
    uint256 _veloLpBalance = _mooTokenBalance.wmul(beefyVault.getPricePerFullShare());

    // % of total supply that 1 mooToken represents
    uint256 _lpFraction = _veloLpBalance.wdiv(veloPool.totalSupply());

    // # of token0 in 1 mooToken
    uint256 _token0Quantity = _lpFraction.wmul(_reserve0);

    // # of token1 in 1 mooToken
    uint256 _token1Quantity = _lpFraction.wmul(_reserve1);

    // price of all of token0 in 1 mooToken in USD
    uint256 _token0TotalValue = _token0Quantity.wmul(_token0priceSourceValue);

    // price of all of token1 in 1 mooToken in USD
    uint256 _token1TotalValue = _token1Quantity.wmul(_token1priceSourceValue);

    uint256 _totalValue = _token0TotalValue + _token1TotalValue;

    return _totalValue;
  }
}

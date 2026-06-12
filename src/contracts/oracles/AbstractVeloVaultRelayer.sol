// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAbstractVeloVaultRelayer} from '@interfaces/oracles/IAbstractVeloVaultRelayer.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

/**
 * @title  AbstractVeloVaultRelayer
 * @notice Abstract contract for Velo vault relayers (Beefy, Yearn, etc.)
 */
abstract contract AbstractVeloVaultRelayer is IAbstractVeloVaultRelayer {
  // --- Constants ---

  uint256 internal constant _BPS = 10_000;
  uint256 public constant PRICE_PER_FULL_SHARE_UPDATE_DELAY = 1 hours;
  uint256 public constant MAX_PRICE_PER_FULL_SHARE_INCREASE_BPS = 100;

  // --- Registry ---

  /// @inheritdoc IAbstractVeloVaultRelayer
  IVeloPool public veloPool;

  /// @inheritdoc IAbstractVeloVaultRelayer
  IPessimisticVeloLpOracle public veloLpOracle;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc IAbstractVeloVaultRelayer
  uint256 public acceptedPricePerFullShare;

  /// @inheritdoc IAbstractVeloVaultRelayer
  uint256 public lastPricePerFullShareUpdateTime;

  // --- Init ---

  /**
   *
   * @param _veloPool The address of the velo pool underlying the yearn vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   * @param _symbol The symbol of the oracle
   */
  constructor(IVeloPool _veloPool, IPessimisticVeloLpOracle _veloLpOracle, string memory _symbol) {
    if (address(_veloPool) == address(0)) {
      revert AbstractVeloVaultRelayer_NullVeloPool();
    }
    if (address(_veloLpOracle) == address(0)) {
      revert AbstractVeloVaultRelayer_NullVeloLpOracle();
    }

    veloPool = _veloPool;
    veloLpOracle = _veloLpOracle;

    symbol = _symbol;
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    try veloLpOracle.getCurrentPoolPrice(true) returns (uint256 _veloLpPrice) {
      if (_veloLpPrice == 0) return (0, false);

      _result = _calculatePriceValue(_veloLpPrice);
      _validity = _result > 0;
    } catch {
      return (0, false);
    }
  }
  /// @inheritdoc IBaseOracle

  function read() external view returns (uint256 _result) {
    return _getPriceValue(veloLpOracle.getCurrentPoolPrice(true));
  }

  /// @inheritdoc IAbstractVeloVaultRelayer
  function updatePricePerFullShare() external returns (bool _updated) {
    return _updatePricePerFullShare();
  }

  /// @inheritdoc IAbstractVeloVaultRelayer
  function livePricePerFullShare() external view returns (uint256 _pricePerFullShare) {
    return _getPricePerFullShare();
  }

  function _getPriceValue(uint256 _veloLpPrice) internal view returns (uint256 _combinedPriceValue) {
    uint256 _price = _calculatePriceValue(_veloLpPrice);

    if (_price == 0) {
      revert AbstractVeloVaultRelayer_ZeroPrice();
    }

    return _price;
  }

  function _calculatePriceValue(uint256 _veloLpPrice) internal view returns (uint256 _price) {
    // # of velo LP tokens in 1 yvToken. Use the lower of the cached and live price-per-full-share so vault
    // losses are reflected immediately, without waiting for an updatePricePerFullShare() call. The live read
    // is an external vault call wrapped in try/catch; on failure we fail closed (return 0) instead of falling
    // back to the cached value, which could otherwise re-enable a stale-high price.
    uint256 _veloLpBalance = acceptedPricePerFullShare;
    try this.livePricePerFullShare() returns (uint256 _livePricePerFullShare) {
      if (_livePricePerFullShare < _veloLpBalance) {
        _veloLpBalance = _livePricePerFullShare;
      }
    } catch {
      return 0;
    }

    if (_veloLpPrice != 0 && _veloLpBalance > type(uint256).max / _veloLpPrice) {
      return 0;
    }

    _price = (_veloLpBalance * _veloLpPrice) / 1e8;
  }

  function _initializePricePerFullShare() internal {
    uint256 _pricePerFullShare = _getPricePerFullShare();
    if (_pricePerFullShare == 0) {
      revert AbstractVeloVaultRelayer_InvalidPricePerFullShare();
    }

    acceptedPricePerFullShare = _pricePerFullShare;
    lastPricePerFullShareUpdateTime = block.timestamp;

    emit UpdatePricePerFullShare(_pricePerFullShare);
  }

  function _updatePricePerFullShare() internal returns (bool _updated) {
    uint256 _pricePerFullShare = _getPricePerFullShare();
    uint256 _acceptedPricePerFullShare = acceptedPricePerFullShare;

    if (_pricePerFullShare == 0) {
      acceptedPricePerFullShare = 0;
      lastPricePerFullShareUpdateTime = block.timestamp;

      emit UpdatePricePerFullShare(0);

      return true;
    }

    if (_acceptedPricePerFullShare == 0) {
      acceptedPricePerFullShare = _pricePerFullShare;
      lastPricePerFullShareUpdateTime = block.timestamp;

      emit UpdatePricePerFullShare(_pricePerFullShare);

      return true;
    }

    // No-op when the live price equals the accepted price: do not touch the update timestamp, otherwise a
    // permissionless no-op call during a flat-price window would defer the next allowed upward move by up to
    // PRICE_PER_FULL_SHARE_UPDATE_DELAY. Placed after the zero branches so their invalidation semantics hold.
    if (_pricePerFullShare == _acceptedPricePerFullShare) {
      return false;
    }

    if (_pricePerFullShare > _acceptedPricePerFullShare) {
      if (block.timestamp < lastPricePerFullShareUpdateTime + PRICE_PER_FULL_SHARE_UPDATE_DELAY) {
        return false;
      }

      uint256 _maxPricePerFullShare =
        (_acceptedPricePerFullShare * (_BPS + MAX_PRICE_PER_FULL_SHARE_INCREASE_BPS)) / _BPS;
      if (_pricePerFullShare > _maxPricePerFullShare) {
        _pricePerFullShare = _maxPricePerFullShare;
      }
    }

    acceptedPricePerFullShare = _pricePerFullShare;
    lastPricePerFullShareUpdateTime = block.timestamp;

    emit UpdatePricePerFullShare(_pricePerFullShare);

    return true;
  }

  /// @notice Virtual function to be implemented by child contracts
  function _getPricePerFullShare() internal view virtual returns (uint256 _pricePerFullShare);
}

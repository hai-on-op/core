// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAbstractVeloVaultRelayer} from '@interfaces/oracles/IAbstractVeloVaultRelayer.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';
import {Math, WAD} from '@libraries/Math.sol';

/**
 * @title  AbstractVeloVaultRelayer
 * @notice Abstract contract for Velo vault relayers (Beefy, Yearn, etc.)
 */
abstract contract AbstractVeloVaultRelayer is IAbstractVeloVaultRelayer {
  using Math for uint256;
  // --- Registry ---

  /// @inheritdoc IAbstractVeloVaultRelayer
  IVeloPool public veloPool;

  /// @inheritdoc IAbstractVeloVaultRelayer
  IPessimisticVeloLpOracle public veloLpOracle;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

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
  /// @notice This function always returns `_validity` as `true` since there are no conditions where the result would be invalid.
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    uint256 _totalValue = _getPriceValue();

    return (_totalValue, true);
  }
  /// @inheritdoc IBaseOracle

  function read() external view returns (uint256 _result) {
    return _getPriceValue();
  }

  function _getPriceValue() internal view returns (uint256 _combinedPriceValue) {
    // 1 yvToken or mooToken
    uint256 _baseTokenBalance = 1_000_000_000_000_000_000;

    // # of velo LP tokens in 1 yvToken
    uint256 _veloLpBalance = _baseTokenBalance.wmul(_getPricePerFullShare());

    // price of 1 velo LP token in chainlink price decimals (8)
    uint256 _veloLpPrice = veloLpOracle.getCurrentPoolPrice(true);

    uint256 _price = (_veloLpBalance * _veloLpPrice) / 1e8;

    if (_price == 0) {
      revert AbstractVeloVaultRelayer_ZeroPrice();
    }

    return _price;
  }

  /// @notice Virtual function to be implemented by child contracts
  function _getPricePerFullShare() internal view virtual returns (uint256 _pricePerFullShare);
}

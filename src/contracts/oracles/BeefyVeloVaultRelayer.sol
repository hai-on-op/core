// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVeloVaultRelayer} from '@interfaces/oracles/IBeefyVeloVaultRelayer.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

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
  IBeefyVaultV7 public beefyVault;

  /// @inheritdoc IBeefyVeloVaultRelayer
  IVeloPool public veloPool;

  /// @inheritdoc IBeefyVeloVaultRelayer
  IPessimisticVeloLpOracle public veloLpOracle;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  // --- Init ---

  /**
   *
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   * @param _veloLpOracle The address of the pessimistic velo lp oracle
   */
  constructor(IBeefyVaultV7 _beefyVault, IVeloPool _veloPool, IPessimisticVeloLpOracle _veloLpOracle) {
    if (address(_beefyVault) == address(0)) {
      revert BeefyVeloVaultRelayer_NullBeefyVault();
    }
    if (address(_veloPool) == address(0)) {
      revert BeefyVeloVaultRelayer_NullVeloPool();
    }
    if (address(_veloLpOracle) == address(0)) {
      revert BeefyVeloVaultRelayer_NullVeloLpOracle();
    }

    beefyVault = _beefyVault;
    veloPool = _veloPool;
    veloLpOracle = _veloLpOracle;

    symbol = string(abi.encodePacked(_beefyVault.symbol(), ' / USD'));
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

  /// @notice Returns the price of the moo token
  function _getPriceValue() internal view returns (uint256 _combinedPriceValue) {
    // 1 mooToken
    uint256 _mooTokenBalance = 1_000_000_000_000_000_000;

    // # of velo LP tokens in 1 mooToken
    uint256 _veloLpBalance = _mooTokenBalance.wmul(beefyVault.getPricePerFullShare());

    // price of 1 velo LP token in chainlink price decimals (8)
    uint256 _veloLpPrice = veloLpOracle.getCurrentPoolPrice(address(veloPool));

    return _veloLpBalance.wmul(_veloLpPrice);
  }
}

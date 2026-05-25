// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {Math as OZMath} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IERC4626ShareOracle} from '@interfaces/oracles/IERC4626ShareOracle.sol';

/**
 * @title  ERC4626ShareOracle
 * @notice Converts an ERC4626 share into an 18-decimal asset-denominated oracle price
 */
contract ERC4626ShareOracle is IERC4626ShareOracle {
  // --- Registry ---

  /// @inheritdoc IERC4626ShareOracle
  IERC4626 public immutable vault;
  /// @inheritdoc IERC4626ShareOracle
  IBaseOracle public immutable assetOracle;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;
  /// @inheritdoc IERC4626ShareOracle
  uint256 public immutable shareUnit;
  /// @inheritdoc IERC4626ShareOracle
  uint256 public immutable assetUnit;

  // --- Init ---

  constructor(IERC4626 _vault, IBaseOracle _assetOracle, string memory _symbol) {
    if (address(_vault) == address(0)) revert ERC4626ShareOracle_NullVault();
    if (address(_assetOracle) == address(0)) revert ERC4626ShareOracle_NullAssetOracle();

    vault = _vault;
    assetOracle = _assetOracle;
    symbol = _symbol;

    shareUnit = 10 ** IERC20Metadata(address(_vault)).decimals();
    assetUnit = 10 ** IERC20Metadata(_vault.asset()).decimals();
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    (uint256 _assetPrice, bool _assetValidity) = assetOracle.getResultWithValidity();
    if (!_assetValidity || _assetPrice == 0) return (0, false);

    uint256 _assetsPerShare = vault.convertToAssets(shareUnit);
    if (_assetsPerShare == 0) return (0, false);

    _result = OZMath.mulDiv(_assetPrice, _assetsPerShare, assetUnit);
    _validity = true;
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    uint256 _assetPrice = assetOracle.read();
    uint256 _assetsPerShare = vault.convertToAssets(shareUnit);
    if (_assetPrice == 0 || _assetsPerShare == 0) revert InvalidPriceFeed();

    _result = OZMath.mulDiv(_assetPrice, _assetsPerShare, assetUnit);
  }
}

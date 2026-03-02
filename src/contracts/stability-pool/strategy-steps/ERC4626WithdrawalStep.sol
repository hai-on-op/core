// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';

/**
 * @title ERC4626WithdrawalStep
 * @notice Redeems ERC4626 vault shares into the underlying asset token
 */
contract ERC4626WithdrawalStep is IStrategyStep {
  // --- Errors ---

  error ERC4626WithdrawalStep_InsufficientOutput();

  // --- Data ---

  struct Data {
    address vault;
    address vaultToken;
    address assetToken;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('ERC4626_WITHDRAW');

  // --- Methods ---

  /// @inheritdoc IStrategyStep
  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  /// @inheritdoc IStrategyStep
  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.vaultToken;
  }

  /// @inheritdoc IStrategyStep
  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.assetToken;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    _amountsOut[0] = IERC4626(_decoded.vault).previewRedeem(_amountIn);
  }

  /// @inheritdoc IStrategyStep
  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    uint256 _before = IERC20(_decoded.assetToken).balanceOf(address(this));
    IERC4626(_decoded.vault).redeem(_amountIn, address(this), address(this));
    uint256 _after = IERC20(_decoded.assetToken).balanceOf(address(this));

    _amountsOut[0] = _after - _before;
    if (_minOuts.length > 0 && _amountsOut[0] < _minOuts[0]) revert ERC4626WithdrawalStep_InsufficientOutput();
  }
}

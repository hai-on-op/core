// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IYearnVaultWithdraw} from '@interfaces/external/IStrategyStepExternal.sol';

/**
 * @title YearnVaultWithdrawalStep
 * @notice Withdraws Yearn vault shares into the underlying LP token
 */
contract YearnVaultWithdrawalStep is IStrategyStep {
  // --- Errors ---

  error YearnVaultWithdrawalStep_InsufficientOutput();

  // --- Data ---

  struct Data {
    address vault;
    address vaultToken;
    address lpToken;
    uint256 shareScale;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('YEARN_WITHDRAW');

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
    _outputTokens[0] = _decoded.lpToken;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    uint256 _scale = _decoded.shareScale == 0 ? 1e18 : _decoded.shareScale;
    _amountsOut[0] = (_amountIn * IYearnVaultWithdraw(_decoded.vault).pricePerShare()) / _scale;
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

    uint256 _before = IERC20(_decoded.lpToken).balanceOf(address(this));
    // slither-disable-next-line unused-return
    IYearnVaultWithdraw(_decoded.vault).withdraw(_amountIn);
    uint256 _after = IERC20(_decoded.lpToken).balanceOf(address(this));
    _amountsOut[0] = _after - _before;
    if (_minOuts.length > 0 && _amountsOut[0] < _minOuts[0]) revert YearnVaultWithdrawalStep_InsufficientOutput();
  }
}

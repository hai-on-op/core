// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {ICurvePool} from '@interfaces/external/IStrategyStepExternal.sol';

/**
 * @title CurveSwapStep
 * @notice Executes a single Curve pool token swap
 */
contract CurveSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Data ---

  struct Data {
    address pool;
    int128 i; // index of the input token
    int128 j; // index of the output token
    address tokenIn;
    address tokenOut;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('CURVE_SWAP');

  // --- Methods ---

  /// @inheritdoc IStrategyStep
  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  /// @inheritdoc IStrategyStep
  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.tokenIn;
  }

  /// @inheritdoc IStrategyStep
  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.tokenOut;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    _amountsOut[0] = ICurvePool(_decoded.pool).get_dy(_decoded.i, _decoded.j, _amountIn);
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

    uint256 _minOut = _minOuts.length > 0 ? _minOuts[0] : 0;
    IERC20(_decoded.tokenIn).forceApprove(_decoded.pool, _amountIn);
    _amountsOut[0] = ICurvePool(_decoded.pool).exchange(_decoded.i, _decoded.j, _amountIn, _minOut);
  }
}

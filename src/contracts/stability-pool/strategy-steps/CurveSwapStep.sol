// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Math as OZMath} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {ICurvePool} from '@interfaces/external/IStrategyStepExternal.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

/**
 * @title CurveSwapStep
 * @notice Executes a single Curve pool token swap
 */
contract CurveSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error CurveSwapStep_InvalidOracle();
  error CurveSwapStep_InvalidOraclePrice();
  error CurveSwapStep_InvalidOracleTolerance();
  error CurveSwapStep_OracleFloorNotMet();

  // --- Data ---

  struct Data {
    address pool;
    int128 i; // index of the input token
    int128 j; // index of the output token
    address tokenIn;
    address tokenOut;
    address tokenInOracle;
    address tokenOutOracle;
    uint16 oracleToleranceBps;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('CURVE_SWAP');
  uint256 internal constant _BPS = 10_000;

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
    if (_amountsOut[0] < _oracleMinOut(_decoded, _amountIn)) revert CurveSwapStep_OracleFloorNotMet();
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
    uint256 _oracleFloor = _oracleMinOut(_decoded, _amountIn);
    if (_oracleFloor > _minOut) _minOut = _oracleFloor;

    IERC20(_decoded.tokenIn).forceApprove(_decoded.pool, _amountIn);
    _amountsOut[0] = ICurvePool(_decoded.pool).exchange(_decoded.i, _decoded.j, _amountIn, _minOut);
  }

  // --- Internal Methods ---

  function _oracleMinOut(Data memory _decoded, uint256 _amountIn) internal view returns (uint256 _minOut) {
    if (_decoded.tokenInOracle == address(0) || _decoded.tokenOutOracle == address(0)) {
      revert CurveSwapStep_InvalidOracle();
    }
    if (_decoded.oracleToleranceBps > _BPS) revert CurveSwapStep_InvalidOracleTolerance();

    (uint256 _tokenInPrice, bool _validTokenInPrice) = IBaseOracle(_decoded.tokenInOracle).getResultWithValidity();
    (uint256 _tokenOutPrice, bool _validTokenOutPrice) = IBaseOracle(_decoded.tokenOutOracle).getResultWithValidity();
    if (!_validTokenInPrice || !_validTokenOutPrice || _tokenInPrice == 0 || _tokenOutPrice == 0) {
      revert CurveSwapStep_InvalidOraclePrice();
    }

    uint256 _tokenInUnit = 10 ** IERC20Metadata(_decoded.tokenIn).decimals();
    uint256 _tokenOutUnit = 10 ** IERC20Metadata(_decoded.tokenOut).decimals();
    uint256 _valueWad = OZMath.mulDiv(_amountIn, _tokenInPrice, _tokenInUnit);
    uint256 _fairOut = OZMath.mulDiv(_valueWad, _tokenOutUnit, _tokenOutPrice);
    _minOut = OZMath.mulDiv(_fairOut, _BPS - _decoded.oracleToleranceBps, _BPS);
  }
}

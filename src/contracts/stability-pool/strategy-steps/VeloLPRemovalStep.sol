// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVelodromeRouterV2, IVeloPairLike} from '@interfaces/external/IStrategyStepExternal.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {FixedPointMathLib} from '@libraries/FixedPointMathLib.sol';
import {WAD} from '@libraries/Math.sol';

/**
 * @title VeloLPRemovalStep
 * @notice Removes Velodrome LP liquidity and returns both underlying tokens
 */
contract VeloLPRemovalStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error VeloLPRemovalStep_InvalidOracle();
  error VeloLPRemovalStep_InvalidOraclePrice();
  error VeloLPRemovalStep_InvalidOracleTolerance();
  error VeloLPRemovalStep_OracleFloorNotMet();
  error VeloLPRemovalStep_UnsupportedOracleFloor();

  // --- Data ---

  struct Data {
    address router;
    address lpToken;
    address tokenA;
    address tokenB;
    bool stable;
    uint256 deadlineBuffer;
    bool useOracleFloor;
    address tokenAOracle;
    address tokenBOracle;
    uint16 oracleToleranceBps;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_LP_REMOVE');
  uint256 internal constant _DEADLINE_OFFSET = 1;
  uint256 internal constant _BPS = 10_000;

  // --- Methods ---

  /// @inheritdoc IStrategyStep
  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  /// @inheritdoc IStrategyStep
  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.lpToken;
  }

  /// @inheritdoc IStrategyStep
  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](2);
    _outputTokens[0] = _decoded.tokenA;
    _outputTokens[1] = _decoded.tokenB;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](2);
    if (_amountIn == 0) return _amountsOut;

    IVeloPairLike _pair = IVeloPairLike(_decoded.lpToken);
    // slither-disable-next-line unused-return
    (uint256 _reserve0, uint256 _reserve1,) = _pair.getReserves();
    uint256 _totalSupply = _pair.totalSupply();
    if (_totalSupply == 0) return _amountsOut;

    address _token0 = _pair.token0();
    if (_token0 == _decoded.tokenA) {
      _amountsOut[0] = (_reserve0 * _amountIn) / _totalSupply;
      _amountsOut[1] = (_reserve1 * _amountIn) / _totalSupply;
    } else {
      _amountsOut[0] = (_reserve1 * _amountIn) / _totalSupply;
      _amountsOut[1] = (_reserve0 * _amountIn) / _totalSupply;
    }
    (uint256 _minA, uint256 _minB) = _oracleMinOut(_decoded, _amountIn);
    if (_amountsOut[0] < _minA || _amountsOut[1] < _minB) revert VeloLPRemovalStep_OracleFloorNotMet();
  }

  /// @inheritdoc IStrategyStep
  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](2);
    if (_amountIn == 0) return _amountsOut;

    uint256 _minA = _minOuts.length > 0 ? _minOuts[0] : 0;
    uint256 _minB = _minOuts.length > 1 ? _minOuts[1] : 0;
    (uint256 _oracleMinA, uint256 _oracleMinB) = _oracleMinOut(_decoded, _amountIn);
    if (_oracleMinA > _minA) _minA = _oracleMinA;
    if (_oracleMinB > _minB) _minB = _oracleMinB;

    IERC20(_decoded.lpToken).forceApprove(_decoded.router, _amountIn);
    (_amountsOut[0], _amountsOut[1]) = IVelodromeRouterV2(_decoded.router).removeLiquidity(
      _decoded.tokenA,
      _decoded.tokenB,
      _decoded.stable,
      _amountIn,
      _minA,
      _minB,
      address(this),
      block.timestamp + _DEADLINE_OFFSET
    );
  }

  // --- Internal Methods ---

  function _oracleMinOut(Data memory _decoded, uint256 _amountIn) internal view returns (uint256 _minA, uint256 _minB) {
    if (!_decoded.useOracleFloor) return (0, 0);
    if (_decoded.stable) revert VeloLPRemovalStep_UnsupportedOracleFloor();
    _validateOracleFloorConfig(_decoded);

    (uint256 _fairReserveA, uint256 _fairReserveB, uint256 _totalSupply) = _fairLpReserves(_decoded);
    if (_totalSupply == 0) return (0, 0);

    _minA = FixedPointMathLib.mulDivDown(_fairReserveA, _amountIn, _totalSupply);
    _minB = FixedPointMathLib.mulDivDown(_fairReserveB, _amountIn, _totalSupply);
    _minA = FixedPointMathLib.mulDivDown(_minA, _BPS - _decoded.oracleToleranceBps, _BPS);
    _minB = FixedPointMathLib.mulDivDown(_minB, _BPS - _decoded.oracleToleranceBps, _BPS);
  }

  function _validateOracleFloorConfig(Data memory _decoded) internal pure {
    if (_decoded.tokenAOracle == address(0) || _decoded.tokenBOracle == address(0)) {
      revert VeloLPRemovalStep_InvalidOracle();
    }
    if (_decoded.oracleToleranceBps > _BPS) revert VeloLPRemovalStep_InvalidOracleTolerance();
  }

  function _oraclePrices(Data memory _decoded) internal view returns (uint256 _tokenAPrice, uint256 _tokenBPrice) {
    bool _validTokenAPrice;
    bool _validTokenBPrice;
    (_tokenAPrice, _validTokenAPrice) = IBaseOracle(_decoded.tokenAOracle).getResultWithValidity();
    (_tokenBPrice, _validTokenBPrice) = IBaseOracle(_decoded.tokenBOracle).getResultWithValidity();
    if (!_validTokenAPrice || !_validTokenBPrice || _tokenAPrice == 0 || _tokenBPrice == 0) {
      revert VeloLPRemovalStep_InvalidOraclePrice();
    }
  }

  function _lpReserves(Data memory _decoded)
    internal
    view
    returns (uint256 _reserveA, uint256 _reserveB, uint256 _totalSupply)
  {
    IVeloPairLike _pair = IVeloPairLike(_decoded.lpToken);
    // slither-disable-next-line unused-return
    (uint256 _reserve0, uint256 _reserve1,) = _pair.getReserves();
    _totalSupply = _pair.totalSupply();

    address _token0 = _pair.token0();
    (_reserveA, _reserveB) = _token0 == _decoded.tokenA ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
  }

  function _fairLpReserves(Data memory _decoded)
    internal
    view
    returns (uint256 _fairReserveA, uint256 _fairReserveB, uint256 _totalSupply)
  {
    (uint256 _tokenAPrice, uint256 _tokenBPrice) = _oraclePrices(_decoded);
    (uint256 _reserveA, uint256 _reserveB, uint256 _lpTotalSupply) = _lpReserves(_decoded);
    if (_lpTotalSupply == 0) return (0, 0, 0);
    _totalSupply = _lpTotalSupply;

    uint256 _tokenAUnit = 10 ** IERC20Metadata(_decoded.tokenA).decimals();
    uint256 _tokenBUnit = 10 ** IERC20Metadata(_decoded.tokenB).decimals();
    uint256 _reserveA18 = FixedPointMathLib.mulDivDown(_reserveA, WAD, _tokenAUnit);
    uint256 _reserveB18 = FixedPointMathLib.mulDivDown(_reserveB, WAD, _tokenBUnit);
    uint256 _reserveProduct = _reserveA18 * _reserveB18;

    uint256 _fairReserveA18 =
      FixedPointMathLib.sqrt(FixedPointMathLib.mulDivDown(_reserveProduct, _tokenBPrice, _tokenAPrice));
    uint256 _fairReserveB18 =
      FixedPointMathLib.sqrt(FixedPointMathLib.mulDivDown(_reserveProduct, _tokenAPrice, _tokenBPrice));

    _fairReserveA = FixedPointMathLib.mulDivDown(_fairReserveA18, _tokenAUnit, WAD);
    _fairReserveB = FixedPointMathLib.mulDivDown(_fairReserveB18, _tokenBUnit, WAD);
  }
}

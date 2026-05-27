// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVeloCLRouter} from '@interfaces/external/IStrategyStepExternal.sol';
import {IVeloCLPoolLike} from '@interfaces/external/IVeloCLPoolLike.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {LiquidityMath} from '@libraries/LiquidityMath.sol';
import {FixedPointMathLib} from '@libraries/FixedPointMathLib.sol';
import {BitMath} from '@uniswap/v3-core/contracts/libraries/BitMath.sol';
import {SwapMath} from '@uniswap/v3-core/contracts/libraries/SwapMath.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

/**
 * @title VeloCLSwapStepViewQuoter
 * @notice Executes Velodrome Slipstream swaps and previews output using view-safe CL math
 */
contract VeloCLSwapStepViewQuoter is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error VeloCLSwapStepViewQuoter_InvalidTickSpacing();
  error VeloCLSwapStepViewQuoter_PoolNotFound();
  error VeloCLSwapStepViewQuoter_InvalidPoolTokens();
  error VeloCLSwapStepViewQuoter_InvalidAmountIn();
  error VeloCLSwapStepViewQuoter_InvalidFeePips();
  error VeloCLSwapStepViewQuoter_InvalidSqrtPriceLimitX96();
  error VeloCLSwapStepViewQuoter_QuoteLoopExceeded();
  error VeloCLSwapStepViewQuoter_InvalidMaxQuoteSteps();
  error VeloCLSwapStepViewQuoter_InvalidOracle();
  error VeloCLSwapStepViewQuoter_InvalidOraclePrice();
  error VeloCLSwapStepViewQuoter_InvalidOracleTolerance();
  error VeloCLSwapStepViewQuoter_OracleFloorNotMet();

  // --- Data ---

  struct Data {
    address router;
    address pool;
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    uint160 sqrtPriceLimitX96;
    uint256 deadlineBuffer;
    bool useOracleFloor;
    address tokenInOracle;
    address tokenOutOracle;
    uint16 oracleToleranceBps;
  }

  struct QuoteState {
    uint160 sqrtPriceX96;
    int24 tick;
    uint128 liquidity;
    int256 amountRemaining;
    uint256 amountOut;
  }

  struct QuoteStep {
    uint160 sqrtPriceStartX96;
    int24 nextTick;
    bool initialized;
    uint160 sqrtPriceNextX96;
    uint160 sqrtPriceTargetX96;
    uint160 sqrtPriceAfterX96;
    uint256 amountIn;
    uint256 amountOut;
    uint256 feeAmount;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_CL_SWAP');
  uint256 internal constant _BPS = 10_000;
  uint256 public immutable maxQuoteSteps;

  constructor(uint256 _maxQuoteSteps) {
    if (_maxQuoteSteps == 0) revert VeloCLSwapStepViewQuoter_InvalidMaxQuoteSteps();
    maxQuoteSteps = _maxQuoteSteps;
  }

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
    return _previewQuote(_decoded, _amountIn);
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

    IERC20(_decoded.tokenIn).forceApprove(_decoded.router, _amountIn);
    IVeloCLRouter.ExactInputSingleParams memory _params = IVeloCLRouter.ExactInputSingleParams({
      tokenIn: _decoded.tokenIn,
      tokenOut: _decoded.tokenOut,
      tickSpacing: _decoded.tickSpacing,
      recipient: address(this),
      deadline: block.timestamp + _decoded.deadlineBuffer,
      amountIn: _amountIn,
      amountOutMinimum: _minOut,
      sqrtPriceLimitX96: _decoded.sqrtPriceLimitX96
    });
    _amountsOut[0] = IVeloCLRouter(_decoded.router).exactInputSingle(_params);
    IERC20(_decoded.tokenIn).forceApprove(_decoded.router, 0);
  }

  // --- Internal Methods ---

  /// @notice Decodes and validates step config before running view quote math
  function _previewQuote(Data memory _decoded, uint256 _amountIn) internal view returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;
    if (_amountIn > uint256(type(int256).max)) revert VeloCLSwapStepViewQuoter_InvalidAmountIn();
    if (_decoded.tickSpacing <= 0) revert VeloCLSwapStepViewQuoter_InvalidTickSpacing();
    if (_decoded.pool == address(0)) revert VeloCLSwapStepViewQuoter_PoolNotFound();

    uint24 _feePips = IVeloCLPoolLike(_decoded.pool).fee();
    if (_feePips == 0 || _feePips >= 1e6) revert VeloCLSwapStepViewQuoter_InvalidFeePips();

    bool _zeroForOne = _validatePoolTokensAndDirection(_decoded.pool, _decoded.tokenIn, _decoded.tokenOut);
    _validateTickSpacing(_decoded.pool, _decoded.tickSpacing);

    _amountsOut[0] = _quoteExactInputSingleView(
      _decoded.pool, _zeroForOne, _decoded.tickSpacing, _feePips, _amountIn, _decoded.sqrtPriceLimitX96
    );
    if (_amountsOut[0] < _oracleMinOut(_decoded, _amountIn)) revert VeloCLSwapStepViewQuoter_OracleFloorNotMet();
  }

  function _oracleMinOut(Data memory _decoded, uint256 _amountIn) internal view returns (uint256 _minOut) {
    if (!_decoded.useOracleFloor) return 0;

    if (_decoded.tokenInOracle == address(0) || _decoded.tokenOutOracle == address(0)) {
      revert VeloCLSwapStepViewQuoter_InvalidOracle();
    }
    if (_decoded.oracleToleranceBps > _BPS) revert VeloCLSwapStepViewQuoter_InvalidOracleTolerance();

    (uint256 _tokenInPrice, bool _validTokenInPrice) = IBaseOracle(_decoded.tokenInOracle).getResultWithValidity();
    (uint256 _tokenOutPrice, bool _validTokenOutPrice) = IBaseOracle(_decoded.tokenOutOracle).getResultWithValidity();
    if (!_validTokenInPrice || !_validTokenOutPrice || _tokenInPrice == 0 || _tokenOutPrice == 0) {
      revert VeloCLSwapStepViewQuoter_InvalidOraclePrice();
    }

    uint256 _tokenInUnit = 10 ** IERC20Metadata(_decoded.tokenIn).decimals();
    uint256 _tokenOutUnit = 10 ** IERC20Metadata(_decoded.tokenOut).decimals();
    uint256 _valueWad = FixedPointMathLib.mulDivDown(_amountIn, _tokenInPrice, _tokenInUnit);
    uint256 _fairOut = FixedPointMathLib.mulDivDown(_valueWad, _tokenOutUnit, _tokenOutPrice);
    _minOut = FixedPointMathLib.mulDivDown(_fairOut, _BPS - _decoded.oracleToleranceBps, _BPS);
  }

  /**
   * @notice Simulates an exact-input swap through Slipstream pool state
   * @dev Mirrors CL swap traversal using tick bitmap and net-liquidity updates
   */
  function _quoteExactInputSingleView(
    address _pool,
    bool _zeroForOne,
    int24 _tickSpacing,
    uint24 _feePips,
    uint256 _amountIn,
    uint160 _sqrtPriceLimitX96
  ) internal view returns (uint256 _amountOut) {
    QuoteState memory _state;
    // slither-disable-next-line unused-return
    (_state.sqrtPriceX96, _state.tick,,,,) = IVeloCLPoolLike(_pool).slot0();
    _state.liquidity = IVeloCLPoolLike(_pool).liquidity();

    uint160 _limit = _sqrtPriceLimitX96;
    if (_limit == 0) {
      _limit = _zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
    } else {
      if (_zeroForOne) {
        if (_limit >= _state.sqrtPriceX96 || _limit <= TickMath.MIN_SQRT_RATIO) {
          revert VeloCLSwapStepViewQuoter_InvalidSqrtPriceLimitX96();
        }
      } else {
        if (_limit <= _state.sqrtPriceX96 || _limit >= TickMath.MAX_SQRT_RATIO) {
          revert VeloCLSwapStepViewQuoter_InvalidSqrtPriceLimitX96();
        }
      }
    }

    _state.amountRemaining = int256(_amountIn);
    for (uint256 _i = 0; _i < maxQuoteSteps && _state.amountRemaining > 0 && _state.sqrtPriceX96 != _limit; ++_i) {
      QuoteStep memory _step;
      _step.sqrtPriceStartX96 = _state.sqrtPriceX96;

      (_step.nextTick, _step.initialized) =
        _nextInitializedTickWithinOneWord(_pool, _state.tick, _tickSpacing, _zeroForOne);
      if (_step.nextTick < TickMath.MIN_TICK) {
        _step.nextTick = TickMath.MIN_TICK;
      } else if (_step.nextTick > TickMath.MAX_TICK) {
        _step.nextTick = TickMath.MAX_TICK;
      }

      _step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(_step.nextTick);
      _step.sqrtPriceTargetX96 = _zeroForOne
        ? (_step.sqrtPriceNextX96 < _limit ? _limit : _step.sqrtPriceNextX96)
        : (_step.sqrtPriceNextX96 > _limit ? _limit : _step.sqrtPriceNextX96);

      (_step.sqrtPriceAfterX96, _step.amountIn, _step.amountOut, _step.feeAmount) = SwapMath.computeSwapStep(
        _state.sqrtPriceX96, _step.sqrtPriceTargetX96, _state.liquidity, _state.amountRemaining, _feePips
      );

      _state.sqrtPriceX96 = _step.sqrtPriceAfterX96;
      uint256 _stepTotalIn = _step.amountIn + _step.feeAmount;
      if (_stepTotalIn > uint256(type(int256).max)) revert VeloCLSwapStepViewQuoter_InvalidAmountIn();
      _state.amountRemaining -= int256(_stepTotalIn);
      _state.amountOut += _step.amountOut;

      if (_state.sqrtPriceX96 == _step.sqrtPriceNextX96) {
        if (_step.initialized) {
          // slither-disable-next-line unused-return
          (, int128 _liquidityNet,,,,,,,,) = IVeloCLPoolLike(_pool).ticks(_step.nextTick);
          if (_zeroForOne) _liquidityNet = -_liquidityNet;
          _state.liquidity = LiquidityMath.addDelta(_state.liquidity, _liquidityNet);
        }
        _state.tick =
          _zeroForOne ? (_step.nextTick == TickMath.MIN_TICK ? TickMath.MIN_TICK : _step.nextTick - 1) : _step.nextTick;
      } else if (_state.sqrtPriceX96 != _step.sqrtPriceStartX96) {
        _state.tick = TickMath.getTickAtSqrtRatio(_state.sqrtPriceX96);
      }
    }

    if (_state.amountRemaining > 0 && _state.sqrtPriceX96 != _limit) {
      revert VeloCLSwapStepViewQuoter_QuoteLoopExceeded();
    }
    _amountOut = _state.amountOut;
  }

  /// @notice Verifies configured tick spacing matches the target pool
  function _validateTickSpacing(address _pool, int24 _tickSpacing) internal view {
    int24 _poolTickSpacing = IVeloCLPoolLike(_pool).tickSpacing();
    if (_poolTickSpacing != _tickSpacing) revert VeloCLSwapStepViewQuoter_InvalidTickSpacing();
  }

  /// @notice Validates token pairing against the pool and returns the swap direction
  function _validatePoolTokensAndDirection(
    address _pool,
    address _tokenIn,
    address _tokenOut
  ) internal view returns (bool _zeroForOne) {
    address _token0 = IVeloCLPoolLike(_pool).token0();
    address _token1 = IVeloCLPoolLike(_pool).token1();

    if (_tokenIn == _token0 && _tokenOut == _token1) return true;
    if (_tokenIn == _token1 && _tokenOut == _token0) return false;
    revert VeloCLSwapStepViewQuoter_InvalidPoolTokens();
  }

  /// @notice Maps a compressed tick to its bitmap word and bit position
  function _position(int24 _tick) internal pure returns (int16 _wordPos, uint8 _bitPos) {
    _wordPos = int16(_tick >> 8);
    assembly {
      _bitPos := and(_tick, 0xFF)
    }
  }

  /// @notice Returns next initialized tick within the current bitmap word
  function _nextInitializedTickWithinOneWord(
    address _pool,
    int24 _tick,
    int24 _tickSpacing,
    bool _lte
  ) internal view returns (int24 _next, bool _initialized) {
    unchecked {
      int24 _compressed = _tick / _tickSpacing;
      if (_tick < 0 && _tick % _tickSpacing != 0) _compressed--;

      if (_lte) {
        (int16 _wordPos, uint8 _bitPos) = _position(_compressed);
        uint256 _mask = (1 << _bitPos) - 1 + (1 << _bitPos);
        uint256 _masked = IVeloCLPoolLike(_pool).tickBitmap(_wordPos) & _mask;
        _initialized = _masked != 0;
        _next = _initialized
          ? (_compressed - int24(uint24(_bitPos - BitMath.mostSignificantBit(_masked)))) * _tickSpacing
          : (_compressed - int24(uint24(_bitPos))) * _tickSpacing;
      } else {
        (int16 _wordPos, uint8 _bitPos) = _position(_compressed + 1);
        uint256 _mask = ~((1 << _bitPos) - 1);
        uint256 _masked = IVeloCLPoolLike(_pool).tickBitmap(_wordPos) & _mask;
        _initialized = _masked != 0;
        _next = _initialized
          ? (_compressed + 1 + int24(uint24(BitMath.leastSignificantBit(_masked) - _bitPos))) * _tickSpacing
          : (_compressed + 1 + int24(uint24(type(uint8).max - _bitPos))) * _tickSpacing;
      }
    }
  }
}

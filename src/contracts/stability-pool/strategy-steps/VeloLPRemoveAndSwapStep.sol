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
 * @title VeloLPRemoveAndSwapStep
 * @notice Removes Velodrome LP liquidity and swaps tokenB to tokenA for single-token output
 */
contract VeloLPRemoveAndSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error VeloLPRemoveAndSwapStep_InsufficientOutput();
  error VeloLPRemoveAndSwapStep_InvalidOracle();
  error VeloLPRemoveAndSwapStep_InvalidOraclePrice();
  error VeloLPRemoveAndSwapStep_InvalidOracleTolerance();
  error VeloLPRemoveAndSwapStep_InvalidPairTokens();
  error VeloLPRemoveAndSwapStep_OracleFloorNotMet();
  error VeloLPRemoveAndSwapStep_UnsupportedOracleFloor();

  // --- Data ---

  struct Data {
    address router;
    address factory;
    address lpToken;
    address tokenA;
    address tokenB;
    bool stableLp;
    bool stableSwap;
    uint256 deadlineBuffer;
    bool useOracleFloor;
    address tokenAOracle;
    address tokenBOracle;
    uint16 oracleToleranceBps;
  }

  struct OraclePrices {
    uint256 tokenAPrice;
    uint256 tokenBPrice;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_LP_REMOVE_SWAP');
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
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.tokenA;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    (uint256 _reserveA, uint256 _reserveB, uint256 _totalSupply) = _lpReserves(_decoded);
    if (_totalSupply == 0) return _amountsOut;

    uint256 _amountA = FixedPointMathLib.mulDivDown(_reserveA, _amountIn, _totalSupply);
    uint256 _amountB = FixedPointMathLib.mulDivDown(_reserveB, _amountIn, _totalSupply);

    if (_amountB > 0) {
      IVelodromeRouterV2.Route[] memory _routes = new IVelodromeRouterV2.Route[](1);
      _routes[0] = IVelodromeRouterV2.Route({
        from: _decoded.tokenB,
        to: _decoded.tokenA,
        stable: _decoded.stableSwap,
        factory: _decoded.factory
      });
      uint256[] memory _amounts = IVelodromeRouterV2(_decoded.router).getAmountsOut(_amountB, _routes);
      // Removing LP first shrinks the pool before this swap executes. Discount the quoted swap leg by the
      // removed LP share squared, which is exact for same-pair volatile pools without fees and conservative
      // for the stable remove-and-swap routes configured in this repo.
      uint256 _lpShareWad = FixedPointMathLib.mulDivDown(_amountIn, WAD, _totalSupply);
      uint256 _swapHaircutWad = WAD - FixedPointMathLib.mulDivDown(_lpShareWad, _lpShareWad, WAD);
      _amountA += FixedPointMathLib.mulDivDown(_amounts[_amounts.length - 1], _swapHaircutWad, WAD);
    }
    _amountsOut[0] = _amountA;
    if (_amountA < _oracleMinOut(_decoded, _amountIn)) revert VeloLPRemoveAndSwapStep_OracleFloorNotMet();
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

    IERC20(_decoded.lpToken).forceApprove(_decoded.router, _amountIn);
    (uint256 _amountA, uint256 _amountB) = IVelodromeRouterV2(_decoded.router).removeLiquidity(
      _decoded.tokenA,
      _decoded.tokenB,
      _decoded.stableLp,
      _amountIn,
      0,
      0,
      address(this),
      block.timestamp + _DEADLINE_OFFSET
    );

    if (_amountB > 0) {
      IERC20(_decoded.tokenB).forceApprove(_decoded.router, _amountB);
      IVelodromeRouterV2.Route[] memory _routes = new IVelodromeRouterV2.Route[](1);
      _routes[0] = IVelodromeRouterV2.Route({
        from: _decoded.tokenB,
        to: _decoded.tokenA,
        stable: _decoded.stableSwap,
        factory: _decoded.factory
      });
      uint256[] memory _swapAmounts = IVelodromeRouterV2(_decoded.router).swapExactTokensForTokens(
        _amountB, 0, _routes, address(this), block.timestamp + _DEADLINE_OFFSET
      );
      _amountA += _swapAmounts[_swapAmounts.length - 1];
    }

    if (_amountA < _minOut) revert VeloLPRemoveAndSwapStep_InsufficientOutput();
    _amountsOut[0] = _amountA;
  }

  // --- Internal Methods ---

  function _oracleMinOut(Data memory _decoded, uint256 _amountIn) internal view returns (uint256 _minOut) {
    if (!_decoded.useOracleFloor) return 0;
    if (_decoded.stableLp) revert VeloLPRemoveAndSwapStep_UnsupportedOracleFloor();
    _validateOracleFloorConfig(_decoded);

    OraclePrices memory _prices = _oraclePrices(_decoded);
    (uint256 _fairReserveA, uint256 _fairReserveB, uint256 _totalSupply) = _fairLpReserves(_decoded, _prices);
    if (_totalSupply == 0) return 0;

    uint256 _fairAmountA = FixedPointMathLib.mulDivDown(_fairReserveA, _amountIn, _totalSupply);
    uint256 _fairAmountB = FixedPointMathLib.mulDivDown(_fairReserveB, _amountIn, _totalSupply);
    uint256 _fairSwapOutA = _convertTokenBToTokenA(_decoded, _fairAmountB, _prices);

    _minOut = FixedPointMathLib.mulDivDown(_fairAmountA + _fairSwapOutA, _BPS - _decoded.oracleToleranceBps, _BPS);
  }

  function _validateOracleFloorConfig(Data memory _decoded) internal pure {
    if (_decoded.tokenAOracle == address(0) || _decoded.tokenBOracle == address(0)) {
      revert VeloLPRemoveAndSwapStep_InvalidOracle();
    }
    if (_decoded.oracleToleranceBps > _BPS) revert VeloLPRemoveAndSwapStep_InvalidOracleTolerance();
  }

  function _oraclePrices(Data memory _decoded) internal view returns (OraclePrices memory _prices) {
    bool _validTokenAPrice;
    bool _validTokenBPrice;
    (_prices.tokenAPrice, _validTokenAPrice) = IBaseOracle(_decoded.tokenAOracle).getResultWithValidity();
    (_prices.tokenBPrice, _validTokenBPrice) = IBaseOracle(_decoded.tokenBOracle).getResultWithValidity();
    if (!_validTokenAPrice || !_validTokenBPrice || _prices.tokenAPrice == 0 || _prices.tokenBPrice == 0) {
      revert VeloLPRemoveAndSwapStep_InvalidOraclePrice();
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
    address _token1 = _pair.token1();
    if (_token0 == _decoded.tokenA && _token1 == _decoded.tokenB) {
      (_reserveA, _reserveB) = (_reserve0, _reserve1);
    } else if (_token0 == _decoded.tokenB && _token1 == _decoded.tokenA) {
      (_reserveA, _reserveB) = (_reserve1, _reserve0);
    } else {
      revert VeloLPRemoveAndSwapStep_InvalidPairTokens();
    }
  }

  function _fairLpReserves(
    Data memory _decoded,
    OraclePrices memory _prices
  ) internal view returns (uint256 _fairReserveA, uint256 _fairReserveB, uint256 _totalSupply) {
    uint256 _reserveA;
    uint256 _reserveB;
    (_reserveA, _reserveB, _totalSupply) = _lpReserves(_decoded);
    if (_totalSupply == 0) return (0, 0, 0);

    uint256 _reserveProduct = _toWad(_reserveA, _decoded.tokenA) * _toWad(_reserveB, _decoded.tokenB);
    _fairReserveA = _fromWad(_fairReserve18(_reserveProduct, _prices.tokenBPrice, _prices.tokenAPrice), _decoded.tokenA);
    _fairReserveB = _fromWad(_fairReserve18(_reserveProduct, _prices.tokenAPrice, _prices.tokenBPrice), _decoded.tokenB);
  }

  function _convertTokenBToTokenA(
    Data memory _decoded,
    uint256 _amountB,
    OraclePrices memory _prices
  ) internal view returns (uint256 _amountA) {
    uint256 _valueWad = FixedPointMathLib.mulDivDown(_amountB, _prices.tokenBPrice, _tokenUnit(_decoded.tokenB));
    _amountA = FixedPointMathLib.mulDivDown(_valueWad, _tokenUnit(_decoded.tokenA), _prices.tokenAPrice);
  }

  function _fairReserve18(
    uint256 _reserveProduct,
    uint256 _priceNumerator,
    uint256 _priceDenominator
  ) internal pure returns (uint256 _fairReserve) {
    _fairReserve =
      FixedPointMathLib.sqrt(FixedPointMathLib.mulDivDown(_reserveProduct, _priceNumerator, _priceDenominator));
  }

  function _toWad(uint256 _amount, address _token) internal view returns (uint256 _wadAmount) {
    _wadAmount = FixedPointMathLib.mulDivDown(_amount, WAD, _tokenUnit(_token));
  }

  function _fromWad(uint256 _wadAmount, address _token) internal view returns (uint256 _amount) {
    _amount = FixedPointMathLib.mulDivDown(_wadAmount, _tokenUnit(_token), WAD);
  }

  function _tokenUnit(address _token) internal view returns (uint256 _unit) {
    _unit = 10 ** IERC20Metadata(_token).decimals();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVelodromeRouterV2, IVeloPairLike} from '@interfaces/external/IStrategyStepExternal.sol';

/**
 * @title VeloLPRemoveAndSwapStep
 * @notice Removes Velodrome LP liquidity and swaps tokenB to tokenA for single-token output
 */
contract VeloLPRemoveAndSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error VeloLPRemoveAndSwapStep_InsufficientOutput();

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
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_LP_REMOVE_SWAP');

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

    IVeloPairLike _pair = IVeloPairLike(_decoded.lpToken);
    // slither-disable-next-line unused-return
    (uint256 _reserve0, uint256 _reserve1,) = _pair.getReserves();
    uint256 _totalSupply = _pair.totalSupply();
    if (_totalSupply == 0) return _amountsOut;

    uint256 _amountA;
    uint256 _amountB;
    if (_pair.token0() == _decoded.tokenA) {
      _amountA = (_reserve0 * _amountIn) / _totalSupply;
      _amountB = (_reserve1 * _amountIn) / _totalSupply;
    } else {
      _amountA = (_reserve1 * _amountIn) / _totalSupply;
      _amountB = (_reserve0 * _amountIn) / _totalSupply;
    }

    if (_amountB > 0) {
      IVelodromeRouterV2.Route[] memory _routes = new IVelodromeRouterV2.Route[](1);
      _routes[0] = IVelodromeRouterV2.Route({
        from: _decoded.tokenB,
        to: _decoded.tokenA,
        stable: _decoded.stableSwap,
        factory: _decoded.factory
      });
      uint256[] memory _amounts = IVelodromeRouterV2(_decoded.router).getAmountsOut(_amountB, _routes);
      _amountA += _amounts[_amounts.length - 1];
    }
    _amountsOut[0] = _amountA;
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

    IERC20(_decoded.lpToken).forceApprove(_decoded.router, _amountIn);
    (uint256 _amountA, uint256 _amountB) = IVelodromeRouterV2(_decoded.router).removeLiquidity(
      _decoded.tokenA,
      _decoded.tokenB,
      _decoded.stableLp,
      _amountIn,
      0,
      0,
      address(this),
      block.timestamp + _decoded.deadlineBuffer
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
        _amountB, 0, _routes, address(this), block.timestamp + _decoded.deadlineBuffer
      );
      _amountA += _swapAmounts[_swapAmounts.length - 1];
    }

    if (_minOuts.length > 0 && _amountA < _minOuts[0]) revert VeloLPRemoveAndSwapStep_InsufficientOutput();
    _amountsOut[0] = _amountA;
  }
}

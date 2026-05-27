// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVelodromeRouterV2} from '@interfaces/external/IStrategyStepExternal.sol';

/**
 * @title VeloSwapStep
 * @notice Executes a single-hop Velodrome V2 token swap
 */
contract VeloSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Data ---

  struct Data {
    address router;
    address factory;
    address tokenIn;
    address tokenOut;
    bool stable;
    uint256 deadlineBuffer;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_SWAP');
  uint256 internal constant _DEADLINE_OFFSET = 1;

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

    IVelodromeRouterV2.Route[] memory _routes = new IVelodromeRouterV2.Route[](1);
    _routes[0] = IVelodromeRouterV2.Route({
      from: _decoded.tokenIn,
      to: _decoded.tokenOut,
      stable: _decoded.stable,
      factory: _decoded.factory
    });
    uint256[] memory _amounts = IVelodromeRouterV2(_decoded.router).getAmountsOut(_amountIn, _routes);
    _amountsOut[0] = _amounts[_amounts.length - 1];
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
    IERC20(_decoded.tokenIn).forceApprove(_decoded.router, _amountIn);

    IVelodromeRouterV2.Route[] memory _routes = new IVelodromeRouterV2.Route[](1);
    _routes[0] = IVelodromeRouterV2.Route({
      from: _decoded.tokenIn,
      to: _decoded.tokenOut,
      stable: _decoded.stable,
      factory: _decoded.factory
    });
    uint256[] memory _rawAmounts = IVelodromeRouterV2(_decoded.router).swapExactTokensForTokens(
      _amountIn, _minOut, _routes, address(this), block.timestamp + _DEADLINE_OFFSET
    );
    _amountsOut[0] = _rawAmounts[_rawAmounts.length - 1];
  }
}

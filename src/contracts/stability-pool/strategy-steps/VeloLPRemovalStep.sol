// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVelodromeRouterV2, IVeloPairLike} from '@interfaces/external/IStrategyStepExternal.sol';

/**
 * @title VeloLPRemovalStep
 * @notice Removes Velodrome LP liquidity and returns both underlying tokens
 */
contract VeloLPRemovalStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Data ---

  struct Data {
    address router;
    address lpToken;
    address tokenA;
    address tokenB;
    bool stable;
    uint256 deadlineBuffer;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_LP_REMOVE');

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
    IERC20(_decoded.lpToken).forceApprove(_decoded.router, _amountIn);
    (_amountsOut[0], _amountsOut[1]) = IVelodromeRouterV2(_decoded.router).removeLiquidity(
      _decoded.tokenA,
      _decoded.tokenB,
      _decoded.stable,
      _amountIn,
      _minA,
      _minB,
      address(this),
      block.timestamp + _decoded.deadlineBuffer
    );
  }
}

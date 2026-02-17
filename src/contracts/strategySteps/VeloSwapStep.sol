// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVelodromeRouterV2} from '@interfaces/external/IStrategyStepExternal.sol';

contract VeloSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  struct Data {
    address router;
    address tokenIn;
    address tokenOut;
    bool stable;
    uint256 deadlineBuffer;
  }

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_SWAP');

  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.tokenIn;
  }

  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.tokenOut;
  }

  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    (uint256 _amountOut,) =
      IVelodromeRouterV2(_decoded.router).getAmountOut(_amountIn, _decoded.tokenIn, _decoded.tokenOut);
    _amountsOut[0] = _amountOut;
  }

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

    uint256[] memory _rawAmounts = IVelodromeRouterV2(_decoded.router).swapExactTokensForTokensSimple(
      _amountIn,
      _minOut,
      _decoded.tokenIn,
      _decoded.tokenOut,
      _decoded.stable,
      address(this),
      block.timestamp + _decoded.deadlineBuffer
    );
    _amountsOut[0] = _rawAmounts[_rawAmounts.length - 1];
  }
}

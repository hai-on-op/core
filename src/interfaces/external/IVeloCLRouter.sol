// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IVeloCLRouter {
  struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }

  function exactInputSingle(ExactInputSingleParams calldata _params) external payable returns (uint256 _amountOut);
}

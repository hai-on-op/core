// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IVelodromeRouterV2 {
  struct Route {
    address from;
    address to;
    bool stable;
    address factory;
  }

  function getAmountsOut(uint256 _amountIn, Route[] calldata _routes) external view returns (uint256[] memory _amounts);

  function swapExactTokensForTokens(
    uint256 _amountIn,
    uint256 _amountOutMin,
    Route[] calldata _routes,
    address _to,
    uint256 _deadline
  ) external returns (uint256[] memory _amounts);

  function removeLiquidity(
    address _tokenA,
    address _tokenB,
    bool _stable,
    uint256 _liquidity,
    uint256 _amountAMin,
    uint256 _amountBMin,
    address _to,
    uint256 _deadline
  ) external returns (uint256 _amountA, uint256 _amountB);
}

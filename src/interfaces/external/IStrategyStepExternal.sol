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

interface ICurvePool {
  // solhint-disable-next-line func-name-mixedcase
  function get_dy(int128 _i, int128 _j, uint256 _dx) external view returns (uint256 _dy);
  function exchange(int128 _i, int128 _j, uint256 _dx, uint256 _minDy) external returns (uint256 _dy);
}

interface IBalancerVault {
  enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
  }

  struct BatchSwapStep {
    bytes32 poolId;
    uint256 assetInIndex;
    uint256 assetOutIndex;
    uint256 amount;
    bytes userData;
  }

  struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
  }

  struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
  }

  function queryBatchSwap(
    SwapKind _kind,
    BatchSwapStep[] calldata _swaps,
    address[] calldata _assets,
    FundManagement calldata _funds
  ) external view returns (int256[] memory _assetDeltas);

  function swap(
    SingleSwap calldata _singleSwap,
    FundManagement calldata _funds,
    uint256 _limit,
    uint256 _deadline
  ) external payable returns (uint256 _amountCalculated);
}

interface IBeefyVaultWithdraw {
  function getPricePerFullShare() external view returns (uint256 _pricePerFullShare);
  function withdraw(uint256 _shares) external;
}

interface IYearnVaultWithdraw {
  function pricePerShare() external view returns (uint256 _pricePerShare);
  function withdraw(uint256 _shares) external returns (uint256 _withdrawn);
}

interface IVeloPairLike {
  function token0() external view returns (address _token0);
  function token1() external view returns (address _token1);
  function totalSupply() external view returns (uint256 _totalSupply);
  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _timestampLast);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IBalancerV3RouterStableMath {
  function swapSingleTokenExactIn(
    address _pool,
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _exactAmountIn,
    uint256 _minAmountOut,
    uint256 _deadline,
    bytes calldata _userData
  ) external returns (uint256 _amountOut);

  function getVault() external view returns (address _vault);
}

interface IBalancerV3VaultStableMath {
  function getPoolTokenCountAndIndexOfToken(
    address _pool,
    IERC20 _token
  ) external view returns (uint256 _tokenCount, uint256 _index);

  function getPoolTokenRates(address _pool)
    external
    view
    returns (uint256[] memory _decimalScalingFactors, uint256[] memory _tokenRates);

  function getCurrentLiveBalances(address _pool) external view returns (uint256[] memory _balancesLiveScaled18);

  function getStaticSwapFeePercentage(address _pool) external view returns (uint256 _swapFeePercentage);
}

interface IBalancerV3VaultHooksConfig {
  function getHooksConfig(address _pool)
    external
    view
    returns (
      bool _enableHookAdjustedAmounts,
      bool _shouldCallBeforeInitialize,
      bool _shouldCallAfterInitialize,
      bool _shouldCallComputeDynamicSwapFee,
      bool _shouldCallBeforeSwap,
      bool _shouldCallAfterSwap,
      bool _shouldCallBeforeAddLiquidity,
      bool _shouldCallAfterAddLiquidity,
      bool _shouldCallBeforeRemoveLiquidity,
      bool _shouldCallAfterRemoveLiquidity,
      address _hooksContract
    );
}

interface IBalancerV3StablePoolLike {
  struct PoolSwapParams {
    uint8 kind;
    uint256 amountGivenScaled18;
    uint256[] balancesScaled18;
    uint256 indexIn;
    uint256 indexOut;
    address router;
    bytes userData;
  }

  function onSwap(PoolSwapParams memory _request) external view returns (uint256 _amountCalculatedScaled18);
}

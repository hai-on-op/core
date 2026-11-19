// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

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

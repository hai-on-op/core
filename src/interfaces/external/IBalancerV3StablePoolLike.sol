// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

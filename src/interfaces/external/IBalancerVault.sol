// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

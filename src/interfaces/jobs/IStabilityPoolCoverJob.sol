// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IStabilityPoolCoverJob is IAuthorizable, IModifiable, IJob {
  // --- Errors ---

  /// @notice Throws when coverAndRepayDebt does not yield a positive profit
  error StabilityPoolCoverJob_NonPositiveProfit();
  /// @notice Throws when coverAndRepayDebt profit does not cover the keeper reward
  error StabilityPoolCoverJob_InsufficientNetProfit();

  // --- Data ---

  /// @notice Whether the cover job should be worked
  function shouldWork() external view returns (bool _shouldWork);

  // --- Registry ---

  /// @notice Address of the StabilityPool contract
  function stabilityPool() external view returns (IStabilityPool _stabilityPool);

  // --- Job ---

  /**
   * @notice Rewarded method to cover and repay debt through the stability pool
   * @param  _auctionHouse Address of the collateral auction house
   * @param  _auctionId Id of the collateral auction
   * @param  _bidAmount Amount of HAI to bid in the auction [wad]
   * @param  _collateralType Bytes32 representation of the collateral type
   * @return _profit Net profit in HAI (positive) or loss (negative) [wad]
   */
  function workCoverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) external returns (int256 _profit);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IStabilityPoolSweepJob is IAuthorizable, IModifiable, IJob {
  // --- Errors ---

  /// @notice Throws when sweeping internal coin exits zero HAI
  error StabilityPoolSweepJob_NullSweepAmount();

  // --- Data ---

  /// @notice Whether the sweep job should be worked
  function shouldWork() external view returns (bool _shouldWork);

  // --- Registry ---

  /// @notice Address of the StabilityPool contract
  function stabilityPool() external view returns (IStabilityPool _stabilityPool);

  // --- Job ---

  /**
   * @notice Rewarded method to sweep internal SAFEEngine coin into external HAI
   * @return _exitedWad Amount of internal coin exited [wad]
   */
  function workSweepInternalCoin() external returns (uint256 _exitedWad);
}

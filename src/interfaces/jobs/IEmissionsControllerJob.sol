// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IEmissionsController} from '@interfaces/IEmissionsController.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IEmissionsControllerJob is IAuthorizable, IModifiable, IJob {
  // --- Data ---

  /// @notice Whether the emissions update-split job should be worked
  function shouldWork() external view returns (bool _shouldWork);

  // --- Registry ---

  /// @notice Address of the EmissionsController contract
  function emissionsController() external view returns (IEmissionsController _emissionsController);

  // --- Job ---

  /// @notice Rewarded method to update the emissions reward split
  function workUpdateRewardSplit() external;
}

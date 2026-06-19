// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IEmissionsControllerJob} from '@interfaces/jobs/IEmissionsControllerJob.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  EmissionsControllerJob
 * @notice This contract contains a rewarded method to run EmissionsController updateRewardSplit
 */
contract EmissionsControllerJob is Authorizable, Modifiable, Job, IEmissionsControllerJob {
  using Encoding for bytes;
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc IEmissionsControllerJob
  bool public shouldWork;

  // --- Registry ---

  /// @inheritdoc IEmissionsControllerJob
  IEmissionsController public emissionsController;

  // --- Init ---

  /**
   * @param  _emissionsController Address of the EmissionsController contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(
    address _emissionsController,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) validParams {
    emissionsController = IEmissionsController(_emissionsController);

    shouldWork = true;
  }

  // --- Job ---

  /// @inheritdoc IEmissionsControllerJob
  function workUpdateRewardSplit() external reward {
    if (!shouldWork) revert NotWorkable();
    emissionsController.updateRewardSplit();
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override(Job, Modifiable) {
    if (_param == 'emissionsController') emissionsController = IEmissionsController(_data.toAddress());
    else if (_param == 'shouldWork') shouldWork = _data.toBool();
    else Job._modifyParameters(_param, _data);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override(Job, Modifiable) {
    address(emissionsController).assertHasCode();
    Job._validateParameters();
  }
}

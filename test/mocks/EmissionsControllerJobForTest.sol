// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {EmissionsControllerJob} from '@contracts/jobs/EmissionsControllerJob.sol';
import {IEmissionsControllerJob} from '@interfaces/jobs/IEmissionsControllerJob.sol';

contract EmissionsControllerJobForTest is EmissionsControllerJob {
  constructor(
    address _emissionsController,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) EmissionsControllerJob(_emissionsController, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWork(bool _shouldWork) external {
    shouldWork = _shouldWork;
  }
}

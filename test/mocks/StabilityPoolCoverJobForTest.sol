// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StabilityPoolCoverJob} from '@contracts/jobs/StabilityPoolCoverJob.sol';
import {IStabilityPoolCoverJob} from '@interfaces/jobs/IStabilityPoolCoverJob.sol';

contract StabilityPoolCoverJobForTest is StabilityPoolCoverJob {
  constructor(
    address _stabilityPool,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) StabilityPoolCoverJob(_stabilityPool, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWork(bool _shouldWork) external {
    shouldWork = _shouldWork;
  }
}

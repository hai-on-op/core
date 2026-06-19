// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StabilityPoolSweepJob} from '@contracts/jobs/StabilityPoolSweepJob.sol';
import {IStabilityPoolSweepJob} from '@interfaces/jobs/IStabilityPoolSweepJob.sol';

contract StabilityPoolSweepJobForTest is StabilityPoolSweepJob {
  constructor(
    address _stabilityPool,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) StabilityPoolSweepJob(_stabilityPool, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWork(bool _shouldWork) external {
    shouldWork = _shouldWork;
  }
}

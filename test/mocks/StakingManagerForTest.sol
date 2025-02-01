// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StakingManager, IStakingManager} from '@contracts/tokens/StakingManager.sol';

contract StakingManagerForTest is StakingManager {
  constructor(
    address _protocolToken,
    address _stakingToken,
    uint256 _cooldownPeriod
  ) StakingManager(_protocolToken, _stakingToken, _cooldownPeriod) {}

  function checkpointAndClaim(address[2] memory _accounts) external {
    _checkpointAndClaim(_accounts);
  }
}

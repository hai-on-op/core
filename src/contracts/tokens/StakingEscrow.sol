// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

/// @notice Holds one staker's KITE and delegates its voting power to that staker.
contract StakingEscrow {
  constructor(address _staker) {
    IProtocolToken _kite = IStakingManager(msg.sender).protocolToken();
    _kite.delegate(_staker);
    _kite.approve(msg.sender, type(uint256).max);
  }
}

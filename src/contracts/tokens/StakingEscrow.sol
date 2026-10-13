// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

/// @notice Isolated KITE custody with delegation controlled by the staking manager.
contract StakingEscrow {
  address private immutable _MANAGER;
  IProtocolToken private immutable _KITE;

  constructor(address _staker) {
    _MANAGER = msg.sender;
    _KITE = IStakingManager(msg.sender).protocolToken();
    _KITE.delegate(_staker);
    _KITE.approve(msg.sender, type(uint256).max);
  }

  function delegate(address _delegatee) external {
    require(msg.sender == _MANAGER);
    _KITE.delegate(_delegatee);
  }
}

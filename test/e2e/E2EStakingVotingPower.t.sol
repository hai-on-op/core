// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {StakingToken} from '@contracts/tokens/StakingToken.sol';
import {StakingManager} from '@contracts/tokens/StakingManager.sol';

contract E2EStakingVotingPower is Test {
  function test_StakingPreservesVotingPower() public {
    ProtocolToken _kite = new ProtocolToken('KITE', 'KITE');
    StakingToken _stKite = new StakingToken('Staked KITE', 'stKITE', address(_kite));
    StakingManager _manager = new StakingManager(address(_kite), address(_stKite), 7 days);
    _stKite.modifyParameters('stakingManager', abi.encode(address(_manager)));
    _stKite.addAuthorization(address(_manager));
    _kite.unpause();
    _kite.mint(address(this), 100 ether);
    _kite.delegate(address(this));
    _kite.approve(address(_manager), 100 ether);
    assertEq(_kite.getVotes(address(this)), 100 ether);

    _manager.stake(address(this), 40 ether);
    address _escrow = _manager.stakingEscrows(address(this));
    assertEq(_kite.delegates(_escrow), address(this));
    assertEq(_kite.getVotes(address(this)), 100 ether);
    _manager.stake(address(this), 60 ether);
    assertEq(_manager.stakingEscrows(address(this)), _escrow);
    assertEq(_kite.balanceOf(_escrow), 100 ether);
    assertEq(_kite.getVotes(address(this)), 100 ether);
    assertEq(_stKite.balanceOf(address(this)), 100 ether);
    assertEq(_kite.balanceOf(address(_manager)), 0);

    _manager.initiateWithdrawal(20 ether);
    assertEq(_kite.delegates(address(_manager)), address(0));
    assertEq(_kite.getVotes(address(this)), 80 ether);
    _manager.cancelWithdrawal();
    assertEq(_kite.getVotes(address(this)), 100 ether);
    _manager.initiateWithdrawal(100 ether);
    assertEq(_kite.getVotes(address(this)), 0);
    vm.warp(block.timestamp + 7 days);
    _stKite.approve(address(_manager), 100 ether);
    _manager.withdraw();
    assertEq(_kite.balanceOf(address(this)), 100 ether);
    assertEq(_kite.getVotes(address(this)), 100 ether);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet} from '@script/Deploy.s.sol';
import {Governor, IGovernor} from '@openzeppelin/contracts/governance/Governor.sol';
import {TimelockController} from '@openzeppelin/contracts/governance/TimelockController.sol';

abstract contract E2EGovernorTest is HaiTest, Deploy {
  address whale = address(0x420);
  address random = address(0x42069);

  function test_proposal_lifecycle() public {
    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    string memory description;

    targets[0] = address(protocolToken);
    callDatas[0] = abi.encodeWithSignature('unpause()');
    values[0] = 0;
    description = 'Unpause the protocol';

    vm.startPrank(whale);
    uint256 _proposalId = haiGovernor.propose(targets, values, callDatas, description);

    vm.expectRevert();
    protocolToken.transfer(address(0x69), 1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector, _proposalId, IGovernor.ProposalState.Pending, 0x2
      )
    );
    haiGovernor.castVote(_proposalId, 1);

    vm.warp(block.timestamp + _governorParams.votingDelay + 1);
    haiGovernor.castVote(_proposalId, 1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector, _proposalId, IGovernor.ProposalState.Active, 0x10
      )
    );
    haiGovernor.queue(targets, values, callDatas, keccak256(bytes(description)));

    vm.warp(block.timestamp + _governorParams.votingPeriod + 1);
    haiGovernor.queue(targets, values, callDatas, keccak256(bytes(description)));

    vm.expectRevert();
    // abi.encodeWithSelector(TimelockController.TimelockUnexpectedOperationState.selector, PROPOSAL_HASH, 0x2)
    haiGovernor.execute(targets, values, callDatas, keccak256(bytes(description)));

    vm.warp(block.timestamp + _governorParams.timelockMinDelay + 1);
    haiGovernor.execute(targets, values, callDatas, keccak256(bytes(description)));

    protocolToken.transfer(random, 1);
  }

  function test_proposal_cancel() public {
    address[] memory targets = new address[](1);
    bytes[] memory callDatas = new bytes[](1);
    uint256[] memory values = new uint256[](1);
    string memory description;

    targets[0] = address(protocolToken);
    callDatas[0] = abi.encodeWithSignature('unpause()');
    values[0] = 0;
    description = 'Unpause the protocol';

    vm.prank(whale);
    haiGovernor.propose(targets, values, callDatas, description);

    vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorOnlyProposer.selector, random));
    vm.prank(random);
    haiGovernor.cancel(targets, values, callDatas, keccak256(bytes(description)));

    vm.prank(whale);
    haiGovernor.cancel(targets, values, callDatas, keccak256(bytes(description)));
  }
}

contract E2EGovernorMainnetTest is DeployMainnet, E2EGovernorTest {
  // uint256 FORK_BLOCK = 112_420_000;
  uint256 FORK_BLOCK = 122_704_223;
  // uint256 FORK_BLOCK = 122_485_854;
  // uint256 FORK_BLOCK = 121_985_899;
  // uint256 FORK_BLOCK = 121_735_935;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    super.setUp();
    run();

    vm.prank(address(timelock));
    protocolToken.mint(whale, 1_000_000e18);
    vm.prank(whale);
    protocolToken.delegate(whale);
    vm.warp(block.timestamp + 1);
  }

  function setupEnvironment() public override(Deploy, DeployMainnet) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(Deploy, DeployMainnet) {
    super.setupPostEnvironment();
  }
}

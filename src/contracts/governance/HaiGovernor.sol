// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IHaiGovernor} from '@interfaces/governance/IHaiGovernor.sol';

import {Governor} from '@openzeppelin/contracts/governance/Governor.sol';
import {GovernorSettings} from '@openzeppelin/contracts/governance/extensions/GovernorSettings.sol';
import {GovernorCountingSimple} from '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import {GovernorVotes, IVotes, Time} from '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';
import {GovernorVotesQuorumFraction} from
  '@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol';
import {GovernorPreventLateQuorum} from '@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol';
import {
  GovernorTimelockControl,
  TimelockController
} from '@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol';

/**
 * @title  HaiGovernor
 * @notice This contract implements OpenZeppelin's Governor contract overriding the clock to use block.timestamp
 */
contract HaiGovernor is
  Governor,
  GovernorSettings,
  GovernorCountingSimple,
  GovernorVotes,
  GovernorVotesQuorumFraction,
  GovernorPreventLateQuorum,
  GovernorTimelockControl
{
  constructor(
    IVotes _token,
    string memory _governorName,
    IHaiGovernor.HaiGovernorParams memory _params
  )
    Governor(_governorName)
    GovernorSettings(_params.votingDelay, _params.votingPeriod, _params.proposalThreshold)
    GovernorVotes(_token)
    GovernorVotesQuorumFraction(_params.quorumNumeratorValue)
    GovernorPreventLateQuorum(_params.quorumVoteExtension)
    GovernorTimelockControl(
      new TimelockController(_params.timelockMinDelay, new address[](0), new address[](0), address(this))
    )
  {
    TimelockController _timelock = TimelockController(payable(timelock()));
    _timelock.grantRole(keccak256('PROPOSER_ROLE'), address(this));
    _timelock.grantRole(keccak256('CANCELLER_ROLE'), address(this));
    _timelock.grantRole(keccak256('EXECUTOR_ROLE'), address(this));
  }

  /**
   * Set the clock to block timestamp, as opposed to the default block number
   */
  function clock() public view override(Governor, GovernorVotes) returns (uint48 _timestamp) {
    return Time.timestamp();
  }

  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual override(Governor, GovernorVotes) returns (string memory _mode) {
    return 'mode=timestamp';
  }

  /**
   * The following functions are overrides required by Solidity
   */
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256 _proposalId) {
    return super._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address _addy) {
    return super._executor();
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48 _scheduledTime) {
    return super._queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function proposalNeedsQueuing(uint256 _proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns (bool _needsQueuing)
  {
    return super.proposalNeedsQueuing(_proposalId);
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256 _threshold) {
    return super.proposalThreshold();
  }

  function state(uint256 _proposalId)
    public
    view
    override(Governor, GovernorTimelockControl)
    returns (ProposalState _state)
  {
    return super.state(_proposalId);
  }

  function _castVote(
    uint256 _proposalId,
    address _account,
    uint8 _support,
    string memory _reason,
    bytes memory _params
  ) internal override(Governor, GovernorPreventLateQuorum) returns (uint256 _voteId) {
    return super._castVote(_proposalId, _account, _support, _reason, _params);
  }

  function proposalDeadline(uint256 _proposalId)
    public
    view
    override(Governor, GovernorPreventLateQuorum)
    returns (uint256 _deadline)
  {
    return super.proposalDeadline(_proposalId);
  }
}

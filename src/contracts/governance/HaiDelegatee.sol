// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Ownable} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IGovernor} from '@openzeppelin/contracts/governance/IGovernor.sol';
import {IHaiDelegatee} from '@interfaces/governance/IHaiDelegatee.sol';

/**
 * @title  HaiDelegatee
 * @notice This contract is used to proxy the voting power delegated to it to a delegatee
 * @dev    Compatible with OpenZeppelin's Governor contract
 */
contract HaiDelegatee is IHaiDelegatee, Ownable {
  /// @inheritdoc IHaiDelegatee
  address public delegatee;

  constructor(address _owner) Ownable(_owner) {}

  /// @inheritdoc IHaiDelegatee
  function setDelegatee(address _delegatee) external onlyOwner {
    delegatee = _delegatee;
    emit DelegateeSet(_delegatee);
  }

  /// @inheritdoc IHaiDelegatee
  function castVote(
    IGovernor _governor,
    uint256 proposalId,
    uint8 support
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVote(proposalId, support);
  }

  /// @inheritdoc IHaiDelegatee
  function castVoteWithReason(
    IGovernor _governor,
    uint256 proposalId,
    uint8 support,
    string memory reason
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVoteWithReason(proposalId, support, reason);
  }

  /// @inheritdoc IHaiDelegatee
  function castVoteWithReasonAndParams(
    IGovernor _governor,
    uint256 proposalId,
    uint8 support,
    string memory reason,
    bytes memory params
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVoteWithReasonAndParams(proposalId, support, reason, params);
  }

  modifier onlyDelegatee() {
    if (msg.sender != delegatee) revert OnlyDelegatee();
    _;
  }
}

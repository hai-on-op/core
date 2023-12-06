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
    uint256 _proposalId,
    uint8 _support
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVote(_proposalId, _support);
  }

  /// @inheritdoc IHaiDelegatee
  function castVoteWithReason(
    IGovernor _governor,
    uint256 _proposalId,
    uint8 _support,
    string memory _reason
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVoteWithReason(_proposalId, _support, _reason);
  }

  /// @inheritdoc IHaiDelegatee
  function castVoteWithReasonAndParams(
    IGovernor _governor,
    uint256 _proposalId,
    uint8 _support,
    string memory _reason,
    bytes memory _params
  ) public onlyDelegatee returns (uint256 _weight) {
    return _governor.castVoteWithReasonAndParams(_proposalId, _support, _reason, _params);
  }

  modifier onlyDelegatee() {
    if (msg.sender != delegatee) revert OnlyDelegatee();
    _;
  }
}

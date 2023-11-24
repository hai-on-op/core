// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IGovernor} from '@openzeppelin/contracts/governance/IGovernor.sol';

interface IHaiDelegatee {
  // --- Events ---

  /**
   * @notice Emitted when the delegatee of the contract is set
   * @param _delegatee The address of the new delegatee
   */
  event DelegateeSet(address _delegatee);

  // --- Errors ---

  /// @notice Throws if called by any account other than the delegatee
  error OnlyDelegatee();

  // --- Getters ---

  /**
   * @notice Get the address of the delegatee of the contract
   * @return _delegatee The address of the delegatee
   */
  function delegatee() external view returns (address _delegatee);

  // --- Methods ---

  /**
   * @notice Set the delegatee of the contract
   * @param _delegatee The address of the new delegatee
   */
  function setDelegatee(address _delegatee) external;

  /**
   * @notice Cast a vote using the voting power delegated to this contract
   * @param _governor The governor contract to vote on
   * @param _proposalId The id of the proposal
   * @param _support The vote type
   * @return _weight The weight of the vote
   */
  function castVote(IGovernor _governor, uint256 _proposalId, uint8 _support) external returns (uint256 _weight);

  /**
   * @notice Cast a vote with reason using the voting power delegated to this contract
   * @param _governor The governor contract to vote on
   * @param _proposalId The id of the proposal
   * @param _support The vote type
   * @param _reason The reason for the vote
   * @return _weight The weight of the vote
   */
  function castVoteWithReason(
    IGovernor _governor,
    uint256 _proposalId,
    uint8 _support,
    string memory _reason
  ) external returns (uint256 _weight);

  /**
   * @notice Cast a vote with reason and params using the voting power delegated to this contract
   * @param _governor The governor contract to vote on
   * @param _proposalId The id of the proposal
   * @param _support The vote type
   * @param _reason The reason for the vote
   * @param _params The params for the vote
   */
  function castVoteWithReasonAndParams(
    IGovernor _governor,
    uint256 _proposalId,
    uint8 _support,
    string memory _reason,
    bytes memory _params
  ) external returns (uint256 _weight);
}

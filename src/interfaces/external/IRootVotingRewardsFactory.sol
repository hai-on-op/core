// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IRootVotingRewardsFactory {
  event RecipientSet(address indexed _caller, uint256 indexed _chainid, address indexed _recipient);

  /// @notice Returns the recipient of the rewards for a given user and chain
  /// @param _owner Address of the owner
  /// @param _chainid Chain id
  /// @return Address of the recipient
  function recipient(address _owner, uint256 _chainid) external view returns (address);

  /// @notice Sets the recipient of the rewards for a given user and chain
  /// @param _chainid Chain id
  /// @param _recipient Address of the recipient
  function setRecipient(uint256 _chainid, address _recipient) external;
}

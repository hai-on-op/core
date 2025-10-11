// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVoter {
  /// @notice Claim bribes for a given NFT.
  /// @dev Utility to help batch bribe claims.
  /// @param _bribes  Array of BribeVotingReward contracts to collect from.
  /// @param _tokens  Array of tokens that are used as bribes.
  /// @param _tokenId Id of veNFT that you wish to claim bribes for.
  function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external;

  /// @notice Called by users to vote for pools. Votes distributed proportionally based on weights.
  ///         Can only vote or deposit into a managed NFT once per epoch.
  ///         Can only vote for gauges that have not been killed.
  /// @dev Weights are distributed proportional to the sum of the weights in the array.
  ///      Throws if length of _poolVote and _weights do not match.
  /// @param _tokenId     Id of veNFT you are voting with.
  /// @param _poolVote    Array of pools you are voting for.
  /// @param _weights     Weights of pools.
  function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;

  /// @notice Claim fees for a given NFT.
  /// @dev Utility to help batch fee claims.
  /// @param _fees    Array of FeesVotingReward contracts to collect from.
  /// @param _tokens  Array of tokens that are used as fees.
  /// @param _tokenId Id of veNFT that you wish to claim fees for.
  function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external;
}

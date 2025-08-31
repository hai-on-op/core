// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVoter {
  /// @notice Claim bribes for a given NFT.
  /// @dev Utility to help batch bribe claims.
  /// @param _bribes  Array of BribeVotingReward contracts to collect from.
  /// @param _tokens  Array of tokens that are used as bribes.
  /// @param _tokenId Id of veNFT that you wish to claim bribes for.
  function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external;
}

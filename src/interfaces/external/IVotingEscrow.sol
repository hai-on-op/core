// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';

interface IVotingEscrow is IERC721 {
  /// @notice Get the voting power for _tokenId at the current timestamp
  /// @dev Returns 0 if called in the same block as a transfer.
  /// @param _tokenId .
  /// @return Voting power
  function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
}

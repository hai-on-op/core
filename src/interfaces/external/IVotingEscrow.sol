// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {IERC721, IERC721Metadata} from '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import {IERC4906} from '@openzeppelin/contracts/interfaces/IERC4906.sol';

struct LockedBalance {
  int128 amount;
  uint256 end;
  bool isPermanent;
}

interface IVotingEscrow is IERC721 {
  /// @notice Get the locked balance for _tokenId
  /// @param _tokenId .
  /// @return Locked balance
  function locked(uint256 _tokenId) external view returns (LockedBalance memory);

  /// @notice Set the locked balance for _tokenId
  /// @param _tokenId .
  /// @param _amount .
  /// @param _end .
  /// @param _isPermanent .
  function setLockedBalance(uint256 _tokenId, int128 _amount, uint256 _end, bool _isPermanent) external;
}

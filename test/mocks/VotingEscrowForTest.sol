// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IVotingEscrow, LockedBalance} from '@interfaces/external/IVotingEscrow.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

import {IERC721, IERC721Metadata} from '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import {IERC6372} from '@openzeppelin/contracts/interfaces/IERC6372.sol';
import {ERC2771Context} from '@openzeppelin/contracts/metatx/ERC2771Context.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

contract VotingEscrowForTest is ERC721, IVotingEscrow {
  mapping(uint256 => LockedBalance) public mockLockedBalances;
  uint256 public nextTokenId;

  constructor() ERC721('Voting Escrow For Test', 'veTest') {}

  function mint(address to) public returns (uint256) {
    uint256 tokenId = nextTokenId++;
    _mint(to, tokenId);
    return tokenId;
  }

  /// @inheritdoc IVotingEscrow
  function locked(uint256 _tokenId) external view override returns (LockedBalance memory) {
    return mockLockedBalances[_tokenId];
  }

  /// @inheritdoc IVotingEscrow
  function setLockedBalance(uint256 _tokenId, int128 _amount, uint256 _end, bool _isPermanent) external {
    mockLockedBalances[_tokenId] = LockedBalance({amount: _amount, end: _end, isPermanent: _isPermanent});
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
    return interfaceId == type(IVotingEscrow).interfaceId || super.supportsInterface(interfaceId);
  }
}

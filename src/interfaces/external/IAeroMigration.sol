// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @notice Minimal interfaces for the verified Aero V3 deployment.
 * @dev Source: dromos-labs/metadex-public commit 8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf.
 *      ABI checked against the deployed Base VotingEscrow and root Voter.
 */
interface IAeroVotingEscrow is IERC721 {
  struct StakedBalance {
    uint128 amount;
    uint48 end;
    bool isPermanent;
  }

  function TOKEN() external view returns (address);
  function VOTER() external view returns (address);
  function staked(uint256 _tokenId) external view returns (StakedBalance memory);
  function createStake(uint128 _value, uint48 _stakingWeeks, bool _isPermanent) external returns (uint256);
}

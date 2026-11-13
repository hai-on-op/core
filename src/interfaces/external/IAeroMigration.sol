// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title  AeroVotingEscrow
 * @notice Interface for the sAERO positions used as wrapped token backing
 * @dev    Source: dromos-labs/metadex-public commit 8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf
 */
interface IAeroVotingEscrow is IERC721 {
  // --- Structs ---

  struct StakedBalance {
    // Amount of underlying AERO in the position [wad]
    uint128 amount;
    // Timestamp when staking ends, or zero for a permanent position
    uint48 end;
    // Whether the position is permanently staked
    bool isPermanent;
  }

  // --- Registry ---

  /// @notice Address of the underlying AERO token
  /// @return _token The AERO token address
  // solhint-disable-next-line func-name-mixedcase
  function TOKEN() external view returns (address _token);

  /// @notice Address of the root voter
  /// @return _voter The root voter address
  // solhint-disable-next-line func-name-mixedcase
  function VOTER() external view returns (address _voter);

  // --- Data ---

  /// @notice Staked balance of an sAERO position
  /// @param _tokenId ID of the sAERO NFT
  /// @return _stakedBalance The position principal, staking end, and permanent status
  function staked(uint256 _tokenId) external view returns (StakedBalance memory _stakedBalance);

  // --- Methods ---

  /**
   * @notice Stake AERO and create an sAERO position
   * @param _value Amount of AERO to stake [wad]
   * @param _stakingWeeks Number of weeks to stake
   * @param _isPermanent Whether the position is permanently staked
   * @return _tokenId ID of the new sAERO NFT
   */
  function createStake(uint128 _value, uint48 _stakingWeeks, bool _isPermanent) external returns (uint256 _tokenId);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IMerkleDistributor is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a user claims tokens
   * @param  _user Address of the user that claimed
   * @param  _amount Amount of tokens claimed
   */
  event Claimed(address _user, uint256 _amount);

  /**
   * @notice Emitted when the distributor is swept (after the claim period has ended)
   * @param  _sweepReceiver Address that received the swept tokens
   * @param  _amount Amount of tokens swept
   */
  event Swept(address _sweepReceiver, uint256 _amount);

  // --- Errors ---

  /// @notice Throws when trying to sweep before the claim period has ended
  error MerkleDistributor_ClaimPeriodNotEnded();
  /// @notice Throws when trying to claim but the claim is not valid
  error MerkleDistributor_ClaimInvalid();

  // --- Data ---

  /// @notice Address of the ERC20 token to be distributed
  function token() external view returns (address _token);
  /// @notice The merkle root of the token distribution
  function root() external view returns (bytes32 _root);
  /// @notice Total amount of tokens to be distributed
  function totalClaimable() external view returns (uint256 _totalClaimable);
  /// @notice Timestamp when the claim period starts
  function claimPeriodStart() external view returns (uint256 _claimPeriodStart);
  /// @notice Timestamp when the claim period ends
  function claimPeriodEnd() external view returns (uint256 _claimPeriodEnd);

  // --- Methods ---

  /**
   * @notice Checks if a user can claim tokens
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _user Address of the user to check
   * @param  _amount Amount of tokens to check
   * @return _claimable Whether the user can claim the amount with the proof provided
   */
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable);

  /**
   * @notice Claims tokens from the distributor
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _amount Amount of tokens to claim
   */
  function claim(bytes32[] calldata _proof, uint256 _amount) external;

  /**
   * @notice Mapping containing the users that have already claimed
   * @param  _user Address of the user to check
   * @return _claimed Boolean indicating if the user has claimed
   */
  function claimed(address _user) external view returns (bool _claimed);

  /**
   * @notice Withdraws tokens from the distributor to a given address after the claim period has ended
   * @param  _sweepReceiver Address to send the tokens to
   */
  function sweep(address _sweepReceiver) external;
}

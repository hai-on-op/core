// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IRewardDistributor is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when a reward is claimed
   * @param  _account Address of the account that claimed the reward
   * @param  _rewardToken Address of the reward token
   * @param  _wad Amount of reward tokens claimed
   */
  event RewardDistributorRewardClaimed(address indexed _account, address indexed _rewardToken, uint256 _wad);

  /**
   * @notice Emitted when a merkle root is updated
   * @param  _rewardToken Address of the reward token
   * @param  _merkleRoot Merkle root for the token
   * @param  _epochCounter Counter of the current epoch
   */
  event RewardDistributorMerkleRootUpdated(address indexed _rewardToken, bytes32 _merkleRoot, uint256 _epochCounter);

  /**
   * @notice Emitted when a reward is emergency withdrawn
   * @param  _rescueReceiver Address of the account that received the reward
   * @param  _rewardToken Address of the reward token
   * @param  _wad Amount of reward tokens withdrawn
   */
  event RewardDistributorEmergencyWithdrawal(
    address indexed _rescueReceiver, address indexed _rewardToken, uint256 _wad
  );

  // --- Errors ---

  /// @notice Throws when trying to update the merkle roots before the end of the current epoch
  error RewardDistributor_TooSoonEpochNotElapsed();

  /// @notice Throws when trying to update the merkle roots but not the root setter
  error RewardDistributor_NotRootSetter();

  /// @notice Throws when the array lengths don't match
  error RewardDistributor_ArrayLengthsMustMatch();

  /// @notice Throws when the token address is invalid
  error RewardDistributor_InvalidTokenAddress();

  /// @notice Throws when the amount is invalid
  error RewardDistributor_InvalidAmount();

  /// @notice Throws when the merkle root is invalid
  error RewardDistributor_InvalidMerkleRoot();

  /// @notice Throws when the reward has already been claimed
  error RewardDistributor_AlreadyClaimed();

  /// @notice Throws when the merkle proof is invalid
  error RewardDistributor_InvalidMerkleProof();

  // --- Data ---

  /**
   * @notice Counter of the current epoch
   * @return _epochCounter Counter of the current epoch
   */
  function epochCounter() external view returns (uint256 _epochCounter);

  /**
   * @notice Duration of each epoch
   * @return _epochDuration Duration of each epoch
   */
  function epochDuration() external view returns (uint256 _epochDuration);

  /**
   * @notice Timestamp of the last time the merkle roots were updated
   * @return _lastUpdatedTime Timestamp of the last time the merkle roots were updated
   */
  function lastUpdatedTime() external view returns (uint256 _lastUpdatedTime);

  /**
   * @notice Address of the account that can set the merkle root
   * @return _rootSetter Address of the account that can set the merkle root
   */
  function rootSetter() external view returns (address _rootSetter);

  /**
   * @notice Mapping of the merkle root for each token
   * @param _token Address of the token
   * @return _root Merkle root for the token
   */
  function merkleRoots(address _token) external view returns (bytes32 _root);

  /**
   * @notice Mapping of whether a user has claimed rewards for a given merkle root
   * @param _merkleRoot The merkle root
   * @param _account Address of the account
   * @return _isClaimed Whether the account has claimed rewards for this merkle root
   */
  function isClaimed(bytes32 _merkleRoot, address _account) external view returns (bool _isClaimed);

  // --- Methods ---

  /**
   * @notice Unpause the claim functionality
   * @dev    Only authorized addresses can unpause the claim functionality
   */
  function unpause() external;

  /**
   * @notice Pause the claim functionality
   * @dev    Only authorized addresses can pause the claim functionality
   */
  function pause() external;

  /**
   * @notice Updates the merkle root(s) for a token
   * @param _tokens Addresses of the token(s)
   * @param _merkleRoots Merkle root(s) for the token(s)
   */
  function updateMerkleRoots(address[] calldata _tokens, bytes32[] calldata _merkleRoots) external;

  /**
   * @notice Claims a reward
   * @param _token Address of the token
   * @param _wad Amount of reward tokens to claim
   * @param _merkleProof Merkle proof for the reward
   */
  function claim(address _token, uint256 _wad, bytes32[] calldata _merkleProof) external;

  /**
   * @notice Claims multiple rewards
   * @param _tokens Addresses of the token(s)
   * @param _wads Amounts of reward tokens to claim
   * @param _merkleProofs Merkle proofs for the rewards
   */
  function multiClaim(
    address[] calldata _tokens,
    uint256[] calldata _wads,
    bytes32[][] calldata _merkleProofs
  ) external;

  /**
   * @notice Emergency withdraw a reward token
   * @param _rescueReceiver Address of the account that received the reward
   * @param _token Address of the token
   * @param _wad Amount of reward tokens to withdraw
   */
  function emergencyWidthdraw(address _rescueReceiver, address _token, uint256 _wad) external;
}

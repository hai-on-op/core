// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';

import {IRewardDistributor} from '@interfaces/tokens/IRewardDistributor.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
/**
 * @title  RewardDistributor
 * @notice This contract distributes rewards to users to claim every 24 hours
 */

contract RewardDistributor is Authorizable, Modifiable, Pausable, IRewardDistributor {
  using Encoding for bytes;

  // --- Data ---

  /// @inheritdoc IRewardDistributor
  uint256 public epochCounter;
  /// @inheritdoc IRewardDistributor
  uint256 public epochDuration;
  /// @inheritdoc IRewardDistributor
  uint256 public lastUpdatedTime;
  /// @inheritdoc IRewardDistributor
  address public rootSetter;

  /// @inheritdoc IRewardDistributor
  mapping(address _token => bytes32 _root) public merkleRoots;
  /// @inheritdoc IRewardDistributor
  mapping(bytes32 _root => mapping(address _account => bool _hasClaimed)) public isClaimed;

  // --- Init ---
  constructor(uint256 _epochDuration, address _rootSetter) Authorizable(msg.sender) {
    epochDuration = _epochDuration;
    epochCounter = 0;
    rootSetter = _rootSetter;
  }

  // --- Methods ---

  /// @inheritdoc IRewardDistributor
  function pause() external isAuthorized {
    _pause();
  }

  /// @inheritdoc IRewardDistributor
  function unpause() external isAuthorized {
    _unpause();
  }

  /// @inheritdoc IRewardDistributor
  function updateMerkleRoots(address[] calldata _tokens, bytes32[] calldata _merkleRoots) external {
    if (block.timestamp - lastUpdatedTime < epochDuration) {
      revert RewardDistributor_TooSoonEpochNotElapsed();
    }
    if (msg.sender != rootSetter) revert RewardDistributor_NotRootSetter();
    if (_tokens.length != _merkleRoots.length) {
      revert RewardDistributor_ArrayLengthsMustMatch();
    }

    for (uint256 _i = 0; _i < _tokens.length; _i++) {
      if (_tokens[_i] == address(0)) {
        revert RewardDistributor_InvalidTokenAddress();
      }
      if (_merkleRoots[_i] == bytes32(0)) {
        revert RewardDistributor_InvalidMerkleRoot();
      }
      merkleRoots[_tokens[_i]] = _merkleRoots[_i];
      emit RewardDistributorMerkleRootUpdated(_tokens[_i], _merkleRoots[_i], epochCounter);
    }
    lastUpdatedTime = block.timestamp;
    epochCounter++;
  }

  /// @inheritdoc IRewardDistributor
  function claim(address _token, uint256 _wad, bytes32[] calldata _merkleProof) external whenNotPaused {
    _claim(_token, _wad, _merkleProof);
  }

  /// @inheritdoc IRewardDistributor
  function multiClaim(
    address[] calldata _tokens,
    uint256[] calldata _wads,
    bytes32[][] calldata _merkleProofs
  ) external whenNotPaused {
    if (_tokens.length != _wads.length || _wads.length != _merkleProofs.length) {
      revert RewardDistributor_ArrayLengthsMustMatch();
    }

    for (uint256 _i = 0; _i < _tokens.length; _i++) {
      _claim(_tokens[_i], _wads[_i], _merkleProofs[_i]);
    }
  }

  /// @inheritdoc IRewardDistributor
  function emergencyWidthdraw(address _rescueReceiver, address _token, uint256 _wad) external isAuthorized {
    if (_token == address(0)) {
      revert RewardDistributor_InvalidTokenAddress();
    }
    if (_wad == 0) revert RewardDistributor_InvalidAmount();
    IERC20(_token).transfer(_rescueReceiver, _wad);
    emit RewardDistributorEmergencyWithdrawal(_rescueReceiver, _token, _wad);
  }

  function _claim(address _token, uint256 _wad, bytes32[] calldata _merkleProof) internal {
    if (isClaimed[merkleRoots[_token]][msg.sender]) {
      revert RewardDistributor_AlreadyClaimed();
    }

    bytes32 _leaf = keccak256(bytes.concat(keccak256(abi.encode(address(msg.sender), _wad))));

    if (MerkleProof.verify(_merkleProof, merkleRoots[_token], _leaf)) {
      isClaimed[merkleRoots[_token]][msg.sender] = true;
      IERC20(_token).transfer(msg.sender, _wad);
      emit RewardDistributorRewardClaimed(msg.sender, _token, _wad);
    } else {
      revert RewardDistributor_InvalidMerkleProof();
    }
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    address _address = _data.toAddress();

    if (_param == 'epochDuration') epochDuration = _uint256;
    else if (_param == 'rootSetter') rootSetter = _address;
    else revert UnrecognizedParam();
  }
}

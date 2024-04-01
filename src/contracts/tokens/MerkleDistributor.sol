// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributor} from '@interfaces/tokens/IMerkleDistributor.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

/**
 * @title  MerkleDistributor
 * @notice This contract allows users to claim tokens from a merkle tree proof
 */
contract MerkleDistributor is Authorizable, IMerkleDistributor {
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

  /// @inheritdoc IMerkleDistributor
  address public token;
  /// @inheritdoc IMerkleDistributor
  bytes32 public root;
  /// @inheritdoc IMerkleDistributor
  uint256 public totalClaimable;
  /// @inheritdoc IMerkleDistributor
  uint256 public claimPeriodStart;
  /// @inheritdoc IMerkleDistributor
  uint256 public claimPeriodEnd;
  /// @inheritdoc IMerkleDistributor
  mapping(address _user => bool _hasClaimed) public claimed;

  // --- Init ---

  /**
   * @param _token Address of the ERC20 token to be distributed
   * @param _root Bytes32 representation of the merkle root
   * @param _totalClaimable Total amount of tokens to be distributed
   * @param _claimPeriodStart Timestamp when the claim period starts
   * @param _claimPeriodEnd Timestamp when the claim period ends
   */
  constructor(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) Authorizable(msg.sender) {
    // TODO: fix assertion
    // token = IERC20(_token.assertHasCode());
    token = _token;
    root = _root;
    totalClaimable = _totalClaimable.assertNonNull();
    claimPeriodStart = _claimPeriodStart.assertGt(block.timestamp);
    claimPeriodEnd = _claimPeriodEnd.assertGt(claimPeriodStart);
  }

  /// @inheritdoc IMerkleDistributor
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable) {
    return _canClaim(_proof, _user, _amount);
  }

  /// @inheritdoc IMerkleDistributor
  function claim(bytes32[] calldata _proof, uint256 _amount) external {
    _claim(_proof, _amount);
  }

  /// @inheritdoc IMerkleDistributor
  // function sweep(address _sweepReceiver) external override isAuthorized {
  function sweep(address _sweepReceiver) external override isAuthorized {
    if (block.timestamp <= claimPeriodEnd) {
      revert MerkleDistributor_ClaimPeriodNotEnded();
    }

    uint256 _totalClaimable = totalClaimable.assertNonNull();
    delete totalClaimable;

    IERC20(token).transfer(_sweepReceiver, _totalClaimable);

    emit Swept({_sweepReceiver: _sweepReceiver, _amount: _totalClaimable});
  }

  function _canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) internal view returns (bool _claimable) {
    _claimable =
      block.timestamp >= claimPeriodStart && block.timestamp <= claimPeriodEnd && _amount > 0 && !claimed[_user];

    if (_claimable) {
      _claimable = MerkleProof.verify(_proof, root, keccak256(bytes.concat(keccak256(abi.encode(_user, _amount)))));
    }
  }

  function _claim(bytes32[] calldata _proof, uint256 _amount) internal {
    if (!_canClaim(_proof, msg.sender, _amount)) {
      revert MerkleDistributor_ClaimInvalid();
    }

    claimed[msg.sender] = true;
    totalClaimable -= _amount;

    IERC20(token).transfer(msg.sender, _amount);

    emit Claimed({_user: msg.sender, _amount: _amount});
  }
}

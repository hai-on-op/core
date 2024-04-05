// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributor} from '@interfaces/tokens/ITokenDistributor.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

/**
 * @title  TokenDistributor
 * @notice This contract allows users to claim tokens from a merkle tree proof
 */
abstract contract TokenDistributor is Authorizable, ITokenDistributor {
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

  address token;
  /// @inheritdoc ITokenDistributor
  bytes32 public root;
  /// @inheritdoc ITokenDistributor
  uint256 public totalClaimable;
  /// @inheritdoc ITokenDistributor
  uint256 public claimPeriodStart;
  /// @inheritdoc ITokenDistributor
  uint256 public claimPeriodEnd;
  /// @inheritdoc ITokenDistributor
  mapping(address _user => bool _hasClaimed) public claimed;

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
    token = _token.assertHasCode();
    root = _root;
    totalClaimable = _totalClaimable.assertNonNull();
    claimPeriodStart = _claimPeriodStart.assertGt(block.timestamp);
    claimPeriodEnd = _claimPeriodEnd.assertGt(claimPeriodStart);
  }

  /// @inheritdoc ITokenDistributor
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable) {
    return _canClaim(_proof, _user, _amount);
  }

  function _canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) internal view returns (bool _claimable) {
    _claimable =
      block.timestamp >= claimPeriodStart && block.timestamp <= claimPeriodEnd && _amount > 0 && !claimed[_user];

    if (_claimable) {
      _claimable = MerkleProof.verify(_proof, root, keccak256(bytes.concat(keccak256(abi.encode(_user, _amount)))));
    }
  }

  /// @inheritdoc ITokenDistributor
  function sweep(address _sweepReceiver) public override isAuthorized {
    if (block.timestamp <= claimPeriodEnd) {
      revert TokenDistributor_ClaimPeriodNotEnded();
    }

    uint256 _totalClaimable = totalClaimable.assertNonNull();
    delete totalClaimable;

    // token.mint(_sweepReceiver, _totalClaimable);

    emit Swept({_sweepReceiver: _sweepReceiver, _amount: _totalClaimable});
  }

  /// @inheritdoc ITokenDistributor
  function claim(bytes32[] calldata _proof, uint256 _amount) external {
    _claim(_proof, _amount);
  }

  function _claim(bytes32[] calldata _proof, uint256 _amount) internal {
    if (!_canClaim(_proof, msg.sender, _amount)) {
      revert TokenDistributor_ClaimInvalid();
    }

    claimed[msg.sender] = true;
    totalClaimable -= _amount;

    // token.mint(msg.sender, _amount);

    emit Claimed({_user: msg.sender, _amount: _amount});
  }

  function _distribute(address _to, uint256 _amount) internal virtual;
}

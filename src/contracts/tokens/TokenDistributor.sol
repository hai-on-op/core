// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ITokenDistributor} from '@interfaces/tokens/ITokenDistributor.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';

import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';
import {MerkleProof} from '@openzeppelin/utils/cryptography/MerkleProof.sol';

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';

/**
 * @title  TokenDistributor
 * @notice This contract allows users to claim tokens from a merkle tree proof
 */
contract TokenDistributor is Authorizable, ITokenDistributor {
  using SafeERC20 for ERC20Votes;
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

  /// @inheritdoc ITokenDistributor
  bytes32 public root;
  /// @inheritdoc ITokenDistributor
  ERC20Votes public token;
  /// @inheritdoc ITokenDistributor
  uint256 public totalClaimable;
  /// @inheritdoc ITokenDistributor
  uint256 public claimPeriodStart;
  /// @inheritdoc ITokenDistributor
  uint256 public claimPeriodEnd;
  /// @inheritdoc ITokenDistributor
  mapping(address _user => bool _hasClaimed) public claimed;

  /**
   * @param  _root Bytes32 representation of the merkle root
   * @param  _token Address of the ERC20 token to be distributed
   * @param  _totalClaimable Total amount of tokens to be distributed
   * @param  _claimPeriodStart Timestamp when the claim period starts
   * @param  _claimPeriodEnd Timestamp when the claim period ends
   * @param  _delegateTo Address to delegate the token votes to before they are claimed
   */
  constructor(
    bytes32 _root,
    ERC20Votes _token,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd,
    address _delegateTo
  ) Authorizable(msg.sender) {
    root = _root;
    token = ERC20Votes(address(_token).assertNonNull());
    totalClaimable = _totalClaimable.assertNonNull();
    claimPeriodStart = _claimPeriodStart.assertGt(block.timestamp);
    claimPeriodEnd = _claimPeriodEnd.assertGt(claimPeriodStart);

    token.delegate(_delegateTo.assertNonNull());
  }

  /// @inheritdoc ITokenDistributor
  function canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) external view returns (bool _claimable) {
    return _canClaim(_proof, _user, _amount);
  }

  /// @inheritdoc ITokenDistributor
  function claim(bytes32[] calldata _proof, uint256 _amount) external {
    _claim(_proof, _amount);
  }

  /// @inheritdoc ITokenDistributor
  function claimAndDelegate(
    bytes32[] calldata _proof,
    uint256 _amount,
    address _delegatee,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    _claim(_proof, _amount);
    token.delegateBySig(_delegatee, token.nonces(msg.sender), _expiry, _v, _r, _s);
  }

  /// @inheritdoc ITokenDistributor
  function sweep(address _sweepReceiver) external override isAuthorized {
    if (block.timestamp <= claimPeriodEnd) revert TokenDistributor_ClaimPeriodNotEnded();
    uint256 _balance = token.balanceOf(address(this)).assertGt(0);

    token.safeTransfer(_sweepReceiver, _balance);

    emit Swept({_sweepReceiver: _sweepReceiver, _amount: _balance});
  }

  function _canClaim(bytes32[] calldata _proof, address _user, uint256 _amount) internal view returns (bool _claimable) {
    _claimable = _claimPeriodActive() && _amount > 0 && !claimed[_user] && _merkleVerified(_proof, _user, _amount);
  }

  function _claim(bytes32[] calldata _proof, uint256 _amount) internal {
    _validateClaim(_proof, _amount);

    claimed[msg.sender] = true;
    totalClaimable -= _amount;

    token.safeTransfer(msg.sender, _amount);

    emit Claimed({_user: msg.sender, _amount: _amount});
  }

  function _validateClaim(bytes32[] calldata _proof, uint256 _amount) internal view {
    if (block.timestamp < claimPeriodStart) revert TokenDistributor_ClaimPeriodNotStarted();
    if (block.timestamp > claimPeriodEnd) revert TokenDistributor_ClaimPeriodEnded();
    if (_amount == 0) revert TokenDistributor_ZeroAmount();
    if (claimed[msg.sender]) revert TokenDistributor_AlreadyClaimed();
    if (!_merkleVerified(_proof, msg.sender, _amount)) revert TokenDistributor_FailedMerkleProofVerify();
  }

  function _claimPeriodActive() internal view returns (bool _active) {
    _active = block.timestamp >= claimPeriodStart && block.timestamp <= claimPeriodEnd;
  }

  function _merkleVerified(
    bytes32[] calldata _proof,
    address _user,
    uint256 _amount
  ) internal view returns (bool _valid) {
    _valid = MerkleProof.verify(_proof, root, keccak256(bytes.concat(keccak256(abi.encode(_user, _amount)))));
  }
}

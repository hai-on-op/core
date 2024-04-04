// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

// import {ITokenDistributor} from "@interfaces/tokens/ITokenDistributor.sol";
import {ITokenDistributorTransfer} from '@interfaces/tokens/ITokenDistributorTransfer.sol';
import {TokenDistributor, ITokenDistributor} from '@contracts/tokens/TokenDistributor.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Assertions} from '@libraries/Assertions.sol';

contract TokenDistributorTransfer is TokenDistributor, ITokenDistributorTransfer {
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

  /// @inheritdoc ITokenDistributorTransfer
  IERC20 public token;

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
  ) TokenDistributor(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd) {
    token = IERC20(_token.assertHasCode());
  }

  /// @inheritdoc ITokenDistributor
  function sweep(address _sweepReceiver) external override isAuthorized {
    if (block.timestamp <= claimPeriodEnd) {
      revert TokenDistributor_ClaimPeriodNotEnded();
    }

    uint256 _totalClaimable = totalClaimable.assertNonNull();
    delete totalClaimable;

    // IERC20(token).transfer(_sweepReceiver, IERC20(token).balanceOf(address(this)));
    token.transfer(_sweepReceiver, token.balanceOf(address(this)));
    // token.transfer(_sweepReceiver, _totalClaimable);

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

    // IERC20(token).transfer(msg.sender, _amount);
    token.transfer(msg.sender, _amount);

    emit Claimed({_user: msg.sender, _amount: _amount});
  }
}

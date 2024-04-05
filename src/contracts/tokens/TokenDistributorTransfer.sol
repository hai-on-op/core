// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

// import {ITokenDistributor} from "@interfaces/tokens/ITokenDistributor.sol";
import {ITokenDistributorTransfer} from '@interfaces/tokens/ITokenDistributorTransfer.sol';
import {TokenDistributor, ITokenDistributor} from '@contracts/tokens/TokenDistributor.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Assertions} from '@libraries/Assertions.sol';

contract TokenDistributorTransfer is TokenDistributor /*, ITokenDistributorTransfer */ {
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

  /// @inheritdoc ITokenDistributorTransfer

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
  ) TokenDistributor(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd) {}

  /// @inheritdoc ITokenDistributor
  // NOTE: is already authorized in super.sweep
  function sweep(address _sweepReceiver) public override /* isAuthorized */ {
    totalClaimable = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(_sweepReceiver, totalClaimable);

    super.sweep(_sweepReceiver);
  }

  function _distribute(address _user, uint256 _amount) internal override {
    IERC20(token).transfer(_user, _amount);
  }
}

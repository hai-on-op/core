// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorMinter} from '@interfaces/tokens/ITokenDistributorMinter.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {TokenDistributor, ITokenDistributor} from '@contracts/tokens/TokenDistributor.sol';

import {Assertions} from '@libraries/Assertions.sol';

contract TokenDistributorMinter is TokenDistributor /*, ITokenDistributorMinter */ {
  using Assertions for address;
  using Assertions for uint256;

  // --- Data ---

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

  ///// @inheritdoc ITokenDistributorMinter
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
    IProtocolToken(token).delegateBySig(_delegatee, IProtocolToken(token).nonces(msg.sender), _expiry, _v, _r, _s);
  }

  function _distribute(address _user, uint256 _amount) internal override {
    IProtocolToken(token).mint(_user, _amount);
  }
}

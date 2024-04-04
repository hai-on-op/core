// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorMinterChild} from '@interfaces/factories/ITokenDistributorMinterChild.sol';
import {TokenDistributorMinter} from '@contracts/tokens/TokenDistributorMinter.sol';
import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  TokenDistributorMinterChild
 * @notice This contract inherits all the functionality of TokenDistributorMinter to be factory deployed
 */
contract TokenDistributorMinterChild is TokenDistributorMinter, FactoryChild, ITokenDistributorMinterChild {
  // --- Init ---

  /**
   *
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
  ) TokenDistributorMinter(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd) {}
}

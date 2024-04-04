// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorTransferChild} from '@interfaces/factories/ITokenDistributorTransferChild.sol';
import {TokenDistributorTransfer} from '@contracts/tokens/TokenDistributorTransfer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  TokenDistributorTransferChild
 * @notice This contract inherits all the functionality of TokenDistributorTransfer to be factory deployed
 */
contract TokenDistributorTransferChild is TokenDistributorTransfer, FactoryChild, ITokenDistributorTransferChild {
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
  ) TokenDistributorTransfer(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd) {}
}

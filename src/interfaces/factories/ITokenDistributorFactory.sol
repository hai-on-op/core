// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorMinter} from '@interfaces/tokens/ITokenDistributorMinter.sol';
import {ITokenDistributorTransfer} from '@interfaces/tokens/ITokenDistributorTransfer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ITokenDistributorFactory is IAuthorizable {
  enum TokenDistributorType {
    MINTER,
    TRANSFER
  }

  // --- Events ---

  /**
   * @notice Emitted when a new MerkleDistributor contract is deployed
   * @param _tokenDistributor Address of the deployed TokenDistributor contract
   * @param _type Type of the deployed TokenDistributor contract
   * @param _token Address of the ERC20 token to be distributed
   * @param _root The merkle root of the token distribution
   * @param _totalClaimable Total amount of tokens to be distributed
   * @param _claimPeriodStart Timestamp when the claim period starts
   * @param _claimPeriodEnd Timestamp when the claim period ends
   */
  event DeployTokenDistributor(
    address indexed _tokenDistributor,
    TokenDistributorType _type,
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  );

  // --- Methods ---

  /**
   * @notice Deploys a TokenDistributorMinterChild contract
   * @param  _token Address of the ERC20 token to be distributed
   * @param  _root Bytes32 representation of the merkle root
   * @param  _totalClaimable Total amount of tokens to be distributed
   * @param  _claimPeriodStart Timestamp when the claim period starts
   * @param  _claimPeriodEnd Timestamp when the claim period ends
   * @return _tokenDistributorMinter Address of the deployed TokenDistributorMinterChild contract
   */
  function deployTokenDistributorMinter(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) external returns (ITokenDistributorMinter _tokenDistributorMinter);

  /**
   * @notice Deploys a TokenDistributorTransferChild contract
   * @param  _token Address of the ERC20 token to be distributed
   * @param  _root Bytes32 representation of the merkle root
   * @param  _totalClaimable Total amount of tokens to be distributed
   * @param  _claimPeriodStart Timestamp when the claim period starts
   * @param  _claimPeriodEnd Timestamp when the claim period ends
   * @return _tokenDistributorTransfer Address of the deployed TokenDistributorTransferChild contract
   */
  function deployTokenDistributorTransfer(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) external returns (ITokenDistributorTransfer _tokenDistributorTransfer);
}

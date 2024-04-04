// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributorFactory} from '@interfaces/factories/ITokenDistributorFactory.sol';
import {ITokenDistributorMinter} from '@interfaces/tokens/ITokenDistributorMinter.sol';
import {ITokenDistributorTransfer} from '@interfaces/tokens/ITokenDistributorTransfer.sol';

import {TokenDistributorMinterChild} from '@contracts/factories/TokenDistributorMinterChild.sol';
import {TokenDistributorTransferChild} from '@contracts/factories/TokenDistributorTransferChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

/**
 * @title  TokenDistributorFactory
 * @notice This contract is used to deploy TokenDistributorMinter and TokenDistributorTransfer contracts
 * @dev    The deployed contracts are TokenDistributorMinterChild or TokenDistributorTransferChild instances
 */
contract TokenDistributorFactory is Authorizable, ITokenDistributorFactory {
  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  /// @inheritdoc ITokenDistributorFactory
  function deployTokenDistributorMinter(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) external isAuthorized returns (ITokenDistributorMinter _tokenDistributorMinter) {
    _tokenDistributorMinter =
      new TokenDistributorMinterChild(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd);
    emit DeployTokenDistributor(
      address(_tokenDistributorMinter),
      TokenDistributorType.MINTER,
      _token,
      _root,
      _totalClaimable,
      _claimPeriodStart,
      _claimPeriodEnd
    );
  }

  /// @inheritdoc ITokenDistributorFactory
  function deployTokenDistributorTransfer(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) external isAuthorized returns (ITokenDistributorTransfer _tokenDistributorTransfer) {
    _tokenDistributorTransfer =
      new TokenDistributorTransferChild(_token, _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd);
    emit DeployTokenDistributor(
      address(_tokenDistributorTransfer),
      TokenDistributorType.TRANSFER,
      _token,
      _root,
      _totalClaimable,
      _claimPeriodStart,
      _claimPeriodEnd
    );
  }
}

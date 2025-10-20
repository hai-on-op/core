// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ISystemStakingToken} from '@interfaces/tokens/ISystemStakingToken.sol';

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

/**
 * @title  StabilityPool
 * @notice This contract is used to manage the stability pool
 */
contract StabilityPool is Authorizable, IStabilityPool {
  // --- Registry ---

  /// @inheritdoc IStabilityPool
  IProtocolToken public protocolToken;

  /// @inheritdoc IStabilityPool
  ISystemCoin public systemCoin;

  /// @inheritdoc IStabilityPool
  ISystemStakingToken public systemStakingToken;

  // --- Data ---

  /// @inheritdoc IStabilityPool
  mapping(address => uint256) public deposits;

  /// @inheritdoc IStabilityPool
  uint256 public totalDeposits;

  uint256 public totalDepositsRaw;

  /// @inheritdoc IStakingManager
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(address _account => PendingWithdrawal) public _pendingWithdrawals;

  /// @inheritdoc IStakingManager
  function pendingWithdrawals(address _account) external view returns (PendingWithdrawal memory _pendingWithdrawal) {
    return _pendingWithdrawals[_account];
  }

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IStabilityPool
  function deposit(address _account, uint256 _wad) external {}
}

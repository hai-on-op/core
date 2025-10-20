// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ISystemStakingToken} from '@interfaces/tokens/ISystemStakingToken.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IStabilityPool is IAuthorizable, IModifiable {
  // --- Events ---

  // --- Errors ---

  // --- Data Structures ---

  struct PendingWithdrawal {
    // Amount of tokens withdrawal was initiated for
    uint256 amount;
    // Timestamp of when withdrawal was initiated
    uint256 timestamp;
  }

  // --- Registry ---

  /// @notice Address of the protocol token
  function protocolToken() external view returns (IProtocolToken _protocolToken);

  /// @notice Address of the system coin
  function systemCoin() external view returns (ISystemCoin _systemCoin);

  /// @notice Address of the system staking token
  function systemStakingToken() external view returns (ISystemStakingToken _systemStakingToken);

  // --- Data ---

  /**
   * @notice The cooldown period for a withdrawal
   * @return _cooldownPeriod The cooldown period for a withdrawal
   */
  function cooldownPeriod() external view returns (uint256 _cooldownPeriod);

  /// @notice The total amount of staked tokens (not including pending withdrawals)
  function totalDeposits() external view returns (uint256 _totalDeposits);

  /// @notice The total amount of deposits in the contract
  function totalDepositsRaw() external view returns (uint256 _totalDepositsRaw);

  /**
   * @notice Returns the reward integral for a specific reward type and user
   * @param  _account Address of the user
   * @return _rewardIntegral The reward integral for the user
   */
  function rewardIntegralFor(address _account) external view returns (uint256 _rewardIntegral);

  /**
   * @notice Returns the claimable reward for a specific user
   * @param  _account Address of the user
   * @return _claimableReward The claimable reward for the user
   */
  function claimableReward(address _account) external view returns (uint256 _claimableReward);

  /**
   * @notice A mapping storing user's deposits
   * @param  _account Address of the user
   * @return _deposit User's deposit [wad]
   */
  function deposits(address _account) external view returns (uint256 _deposit);

  /**
   * @notice Data of a pending withdrawal
   * @param  _account Address of the user
   * @return _pendingWithdrawal PendingWithdrawal type data struct
   */
  function pendingWithdrawals(address _account) external view returns (PendingWithdrawal memory _pendingWithdrawal);

  /**
   * @notice Unpacked data of a pending withdrawal
   * @param _account Address of the user that initiated the withdrawal
   * @return _amount Amount of tokens withdrawal was initiated for
   * @return _timestamp Timestamp of when withdrawal was initiated
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _pendingWithdrawals(address _account) external view returns (uint256 _amount, uint256 _timestamp);

  // --- Methods ---

  /**
   * @notice Deposit system coin tokens into the stability pool
   * @param _account Address of the account that is depositing
   * @param _wad Amount of system coin being deposited [wad]
   */
  function deposit(address _account, uint256 _wad) external;

  /**
   * @notice Initiates a pending withdrawal
   * @param _wad Amount of $KITE being withdrawn [wad]
   */
  function initiateWithdrawal(uint256 _wad) external;

  /**
   * @notice Cancels a pending withdrawal
   */
  function cancelWithdrawal() external;

  /**
   * @notice Completes a pending withdrawal
   */
  function withdraw() external;
}

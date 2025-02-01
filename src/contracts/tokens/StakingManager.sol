// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IStakingToken} from '@interfaces/tokens/IStakingToken.sol';

import {IRewardPool} from '@interfaces/tokens/IRewardPool.sol';

import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

/**
 * @title  StakingManager
 * @notice This contract is used to manage staking positions
 *         and to distribute staking rewards
 */
contract StakingManager is Authorizable, Modifiable, IStakingManager {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;
  using SafeERC20 for IProtocolToken;
  using SafeERC20 for IERC20;

  // --- Registry ---

  /// @inheritdoc IStakingManager
  IProtocolToken public protocolToken;

  /// @inheritdoc IStakingManager
  IStakingToken public stakingToken;

  // --- Params ---

  /// @inheritdoc IStakingManager
  // solhint-disable-next-line private-vars-leading-underscore
  StakingManagerParams public _params;

  /// @inheritdoc IStakingManager
  function params() external view returns (StakingManagerParams memory _stakingManagerParams) {
    return _params;
  }

  // --- Data ---

  /// @inheritdoc IStakingManager
  mapping(address => uint256) public stakedBalances;

  /// @inheritdoc IStakingManager
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(address _account => PendingWithdrawal) public _pendingWithdrawals;

  /// @inheritdoc IStakingManager
  function pendingWithdrawals(address _account) external view returns (PendingWithdrawal memory _pendingWithdrawal) {
    return _pendingWithdrawals[_account];
  }

  /// @inheritdoc IStakingManager
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 _id => RewardType) public _rewardTypes;

  /// @inheritdoc IStakingManager
  function rewardTypes(uint256 _id) external view returns (RewardTypeInfo memory _rewardTypeInfo) {
    RewardType storage _rewardType = _rewardTypes[_id];
    return RewardTypeInfo({
      rewardToken: _rewardType.rewardToken,
      rewardPool: _rewardType.rewardPool,
      isActive: _rewardType.isActive,
      rewardIntegral: _rewardType.rewardIntegral,
      rewardRemaining: _rewardType.rewardRemaining
    });
  }

  /// @inheritdoc IStakingManager
  function rewardIntegralFor(uint256 _id, address _user) external view returns (uint256 _rewardIntegral) {
    return _rewardTypes[_id].rewardIntegralFor[_user];
  }

  /// @inheritdoc IStakingManager
  function claimableReward(uint256 _id, address _user) external view returns (uint256 _claimableReward) {
    return _rewardTypes[_id].claimableReward[_user];
  }

  /// @inheritdoc IStakingManager
  uint256 public rewards;

  // --- Init ---

  /**
   * @param  _protocolToken Address of the ProtocolToken contract
   * @param  _stakingToken Address of the StakingToken contract
   * @param  _cooldownPeriod Address of the StakingToken contract
   */
  constructor(
    address _protocolToken,
    address _stakingToken,
    uint256 _cooldownPeriod
  ) Authorizable(msg.sender) validParams {
    stakingToken = IStakingToken(_stakingToken);
    protocolToken = IProtocolToken(_protocolToken);
    _params.cooldownPeriod = _cooldownPeriod;
  }

  // --- Methods ---

  /// @inheritdoc IStakingManager
  function stake(address _account, uint256 _wad) external {
    if (_account == address(0)) revert StakingManager_StakeNullReceiver();
    if (_wad == 0) revert StakingManager_StakeNullAmount();

    stakedBalances[_account] += _wad;

    // Mint stKITE
    stakingToken.mint(_account, _wad);

    // transfer KITE
    protocolToken.safeTransferFrom(msg.sender, address(this), _wad);

    // Call stake in the reward pools
    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];
      if (_rewardType.isActive) {
        IRewardPool _rewardPool = IRewardPool(_rewardType.rewardPool);
        _rewardPool.stake(_wad);
      }
    }

    emit StakingManagerStaked(_account, _wad);
  }

  /// @inheritdoc IStakingManager
  function initiateWithdrawal(uint256 _wad) external {
    if (_wad == 0) revert StakingManager_WithdrawNullAmount();

    PendingWithdrawal storage _existingWithdrawal = _pendingWithdrawals[msg.sender];
    stakedBalances[msg.sender] -= _wad;

    if (_existingWithdrawal.amount != 0) {
      _existingWithdrawal.amount += _wad;
      _existingWithdrawal.timestamp = block.timestamp;
    } else {
      _pendingWithdrawals[msg.sender] = PendingWithdrawal({amount: _wad, timestamp: block.timestamp});
    }

    // Call decreaseStake in the reward pools
    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];
      if (_rewardType.isActive) {
        IRewardPool _rewardPool = IRewardPool(_rewardType.rewardPool);
        _rewardPool.decreaseStake(_wad);
      }
    }

    emit StakingManagerWithdrawalInitiated(msg.sender, _wad);
  }
  /// @inheritdoc IStakingManager

  function cancelWithdrawal() external {
    PendingWithdrawal storage _existingWithdrawal = _pendingWithdrawals[msg.sender];

    if (_existingWithdrawal.amount == 0) {
      revert StakingManager_NoPendingWithdrawal();
    }

    uint256 _withdrawalAmount = _existingWithdrawal.amount; // Store the amount before deleting

    delete _pendingWithdrawals[msg.sender];

    stakedBalances[msg.sender] += _withdrawalAmount; // use stored amount

    // Call increaseStake in the reward pools
    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];
      if (_rewardType.isActive) {
        IRewardPool _rewardPool = IRewardPool(_rewardType.rewardPool);
        _rewardPool.increaseStake(_withdrawalAmount);
      }
    }

    emit StakingManagerWithdrawalCancelled(msg.sender, _withdrawalAmount);
  }

  /// @inheritdoc IStakingManager
  function withdraw() external {
    PendingWithdrawal storage _existingWithdrawal = _pendingWithdrawals[msg.sender];

    if (_existingWithdrawal.amount == 0) {
      revert StakingManager_NoPendingWithdrawal();
    }

    if (block.timestamp - _existingWithdrawal.timestamp < _params.cooldownPeriod) {
      revert StakingManager_CooldownPeriodNotElapsed();
    }

    uint256 _withdrawalAmount = _existingWithdrawal.amount; // Store amount first

    delete _pendingWithdrawals[msg.sender];

    stakingToken.burnFrom(msg.sender, _withdrawalAmount);

    protocolToken.safeTransfer(msg.sender, _withdrawalAmount);

    emit StakingManagerWithdrawn(msg.sender, _withdrawalAmount);
  }

  /// @inheritdoc IStakingManager
  function emergencyWithdraw(address _rescueReceiver, uint256 _wad) external isAuthorized {
    if (_wad == 0) revert StakingManager_WithdrawNullAmount();

    protocolToken.safeTransfer(_rescueReceiver, _wad);

    emit StakingManagerEmergencyWithdrawal(_rescueReceiver, _wad);
  }

  /// @inheritdoc IStakingManager
  function emergencyWithdrawReward(uint256 _id, address _rescueReceiver, uint256 _wad) external isAuthorized {
    if (_rewardTypes[_id].rewardToken == address(0)) {
      revert StakingManager_InvalidRewardType();
    }
    if (_wad == 0) revert StakingManager_WithdrawNullAmount();

    IERC20(_rewardTypes[_id].rewardToken).safeTransfer(_rescueReceiver, _wad);

    // protocolToken.safeTransfer(_rescueReceiver, _wad);

    emit StakingManagerEmergencyRewardWithdrawal(_rescueReceiver, _rewardTypes[_id].rewardToken, _wad);
  }

  /// @inheritdoc IStakingManager
  function getReward(address _account) external {
    _checkpointAndClaim([_account, _account]);
  }

  /// @inheritdoc IStakingManager
  function getRewardAndForward(address _account, address _forwardTo) external {
    if (msg.sender != _account) revert StakingManager_ForwardingOnly();

    _checkpointAndClaim([_account, _forwardTo]);
  }

  /// @inheritdoc IStakingManager
  function addRewardType(address _rewardToken, address _rewardPool) external isAuthorized {
    if (_rewardToken == address(0)) revert StakingManager_NullRewardToken();
    if (_rewardPool == address(0)) revert StakingManager_NullRewardPool();

    uint256 _id = rewards;
    rewards++;

    RewardType storage _rewardType = _rewardTypes[_id];
    _rewardType.rewardToken = _rewardToken;
    _rewardType.rewardPool = _rewardPool;
    _rewardType.isActive = true;
    _rewardType.rewardIntegral = 0;
    _rewardType.rewardRemaining = 0;

    emit StakingManagerAddRewardType(_id, _rewardToken, _rewardPool);
  }

  /// @inheritdoc IStakingManager
  function activateRewardType(uint256 _id) external isAuthorized {
    if (_rewardTypes[_id].rewardToken == address(0)) {
      revert StakingManager_InvalidRewardType();
    }
    _rewardTypes[_id].isActive = true;
    emit StakingManagerActivateRewardType(_id);
  }

  /// @inheritdoc IStakingManager
  function deactivateRewardType(uint256 _id) external isAuthorized {
    if (_rewardTypes[_id].rewardToken == address(0)) {
      revert StakingManager_InvalidRewardType();
    }
    _rewardTypes[_id].isActive = false;
    emit StakingManagerDeactivateRewardType(_id);
  }

  /// @inheritdoc IStakingManager
  function earned(address _account) external returns (EarnedData[] memory _claimable) {
    _checkpoint([_account, address(0)]);
    return _earned(_account);
  }

  /// @inheritdoc IStakingManager
  function checkpoint(address[2] memory _accounts) external {
    _checkpoint(_accounts);
  }

  /// @inheritdoc IStakingManager
  function userCheckpoint(address _account) external {
    _checkpoint([_account, address(0)]);
  }

  function _earned(address _account) internal view returns (EarnedData[] memory _claimable) {
    _claimable = new EarnedData[](rewards);

    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];

      if (_rewardType.rewardToken == address(0)) {
        continue;
      }

      _claimable[_i].rewardToken = _rewardType.rewardToken;
      _claimable[_i].rewardAmount = _rewardType.claimableReward[_account];
    }
    return _claimable;
  }

  // TODO: Check decimals
  function _calcRewardIntegral(
    uint256 _id,
    address[2] memory _accounts,
    uint256[2] memory _balances,
    uint256 _supply,
    bool _isClaim
  ) internal {
    RewardType storage _rewardType = _rewardTypes[_id];

    if (!_rewardType.isActive) return;

    uint256 _balance = IERC20(_rewardType.rewardToken).balanceOf(address(this));

    // Checks if new rewards have been added by comparing current balance with rewardRemaining
    if (_balance > _rewardType.rewardRemaining) {
      uint256 _newRewards = _balance - _rewardType.rewardRemaining;
      // If there are new rewards and there are existing stakers
      if (_supply > 0) {
        _rewardType.rewardIntegral += (_newRewards * 1e18) / _supply;
        _rewardType.rewardRemaining = _balance;
      }
    }

    for (uint256 _i = 0; _i < _accounts.length; _i++) {
      if (_accounts[_i] == address(0)) continue;
      if (_isClaim && _i != 0) continue; //only update/claim for first address and use second as forwarding

      uint256 _userBalance = _balances[_i];
      uint256 _userIntegral = _rewardType.rewardIntegralFor[_accounts[_i]];

      if (_isClaim || _userIntegral < _rewardType.rewardIntegral) {
        if (_isClaim) {
          // Calculate total receiveable rewards
          uint256 _receiveable = _rewardType.claimableReward[_accounts[_i]]
            + (_userBalance * (_rewardType.rewardIntegral - _userIntegral)) / 1e18;

          if (_receiveable > 0) {
            // Reset claimable rewards to 0
            _rewardType.claimableReward[_accounts[_i]] = 0;

            // Transfer rewards to the next address in the array (forwarding address)
            IERC20(_rewardType.rewardToken).safeTransfer(_accounts[_i + 1], _receiveable);

            emit StakingManagerRewardPaid(_accounts[_i], _rewardType.rewardToken, _receiveable, _accounts[_i + 1]);
            // Update the remaining balance
            _balance = _balance - _receiveable;
          }
        } else {
          // Just accumulate rewards without claiming
          _rewardType.claimableReward[_accounts[_i]] = _rewardType.claimableReward[_accounts[_i]]
            + (_userBalance * (_rewardType.rewardIntegral - _userIntegral)) / 1e18;

          // Update user's reward integral
          _rewardType.rewardIntegralFor[_accounts[_i]] = _rewardType.rewardIntegral;
        }
      }
    }

    // Update remaining reward here since balance could have changed if claiming
    if (_balance != _rewardType.rewardRemaining) {
      _rewardType.rewardRemaining = uint256(_balance);
    }
  }

  function _checkpoint(address[2] memory _accounts) internal {
    uint256 _supply = stakingToken.totalSupply();
    uint256[2] memory _depositedBalance;
    _depositedBalance[0] = stakingToken.balanceOf(_accounts[0]);
    _depositedBalance[1] = stakingToken.balanceOf(_accounts[1]);

    _claimManagerRewards();

    for (uint256 _i = 0; _i < rewards; _i++) {
      _calcRewardIntegral(_i, _accounts, _depositedBalance, _supply, false);
    }
  }

  function _checkpointAndClaim(address[2] memory _accounts) internal {
    uint256 _supply = stakingToken.totalSupply();
    uint256[2] memory _depositedBalance;
    _depositedBalance[0] = stakingToken.balanceOf(_accounts[0]); //only do first slot

    _claimManagerRewards();

    for (uint256 _i = 0; _i < rewards; _i++) {
      _calcRewardIntegral(_i, _accounts, _depositedBalance, _supply, true);
    }
  }

  function _claimManagerRewards() internal {
    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];
      IRewardPool _rewardPool = IRewardPool(_rewardType.rewardPool);
      if (!_rewardType.isActive) continue;
      _rewardPool.getReward();
    }
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    if (_param == 'cooldownPeriod') _params.cooldownPeriod = _uint256;
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.cooldownPeriod.assertNonNull().assertGt(0);
    address(stakingToken).assertHasCode();
    address(protocolToken).assertHasCode();
  }
}

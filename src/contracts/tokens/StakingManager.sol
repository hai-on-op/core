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

import {WAD} from '@libraries/Math.sol';

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
  uint256 public totalKiteRewardsAvailable;

  /// @inheritdoc IStakingManager
  uint256 public totalStaked;

  /// @inheritdoc IStakingManager
  uint256 public totalStakedRaw;

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
   * @param  _cooldownPeriod Amount of time before a user can withdraw their staked tokens
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

    _checkpoint([_account, msg.sender]);

    stakedBalances[_account] += _wad;

    totalStaked += _wad;

    totalStakedRaw += _wad;
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
        emit StakingManagerRewardPoolStaked(_account, _i, _rewardType.rewardPool, _wad);
      }
    }

    emit StakingManagerStaked(_account, _wad);
  }

  /// @inheritdoc IStakingManager
  function initiateWithdrawal(uint256 _wad) external {
    if (_wad == 0) revert StakingManager_WithdrawNullAmount();
    if (_wad > stakedBalances[msg.sender]) {
      revert StakingManager_WithdrawAmountExceedsBalance();
    }

    _checkpoint([msg.sender, address(0)]);

    PendingWithdrawal storage _existingWithdrawal = _pendingWithdrawals[msg.sender];
    stakedBalances[msg.sender] -= _wad;

    totalStaked -= _wad;

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

    _checkpoint([msg.sender, address(0)]);

    uint256 _withdrawalAmount = _existingWithdrawal.amount; // Store the amount before deleting

    delete _pendingWithdrawals[msg.sender];

    stakedBalances[msg.sender] += _withdrawalAmount; // use stored amount

    totalStaked += _withdrawalAmount;

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

    totalStakedRaw -= _withdrawalAmount;

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

    if (_rewardTypes[_id].rewardToken == address(protocolToken)) {
      totalKiteRewardsAvailable -= _wad;
    }

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

  function _calcRewardIntegral(
    uint256 _id,
    address[2] memory _accounts,
    uint256[2] memory _balances,
    uint256 _supply,
    bool _isClaim
  ) internal {
    RewardType storage _rewardType = _rewardTypes[_id];

    if (!_rewardType.isActive) return;

    // --- Start: Adjusted Balance Calculation ---
    uint256 _currentRewardBalance;
    // Get the total balance of the reward token in the contract
    uint256 _contractTokenBalance = IERC20(_rewardType.rewardToken).balanceOf(address(this));

    // Check if reward token is the protocol token
    if (_rewardType.rewardToken == address(protocolToken)) {
      // If yes, subtract the *raw* staked principal amount (totalStakedRaw)
      // Ensure non-negative result
      _currentRewardBalance = totalKiteRewardsAvailable;
    } else {
      // If not, the entire balance is potential rewards
      _currentRewardBalance = _contractTokenBalance;
    }

    // Calculate new rewards based on the difference from remaining
    if (_currentRewardBalance > _rewardType.rewardRemaining) {
      uint256 _newRewards = _currentRewardBalance - _rewardType.rewardRemaining;
      if (_supply > 0) {
        // Update integral with new rewards
        _rewardType.rewardIntegral += (_newRewards * WAD) / _supply;
      }
      // Update remaining rewards to current calculated balance
      _rewardType.rewardRemaining = _currentRewardBalance;
    } else if (_currentRewardBalance < _rewardType.rewardRemaining) {
      // If current balance is less than remaining (e.g., due to direct transfer out), adjust remaining down.
      // This prevents rewardRemaining from staying artificially high.
      _rewardType.rewardRemaining = _currentRewardBalance;
    }
    // --- End: Adjusted Balance Calculation ---

    for (uint256 _i = 0; _i < _accounts.length; _i++) {
      if (_accounts[_i] == address(0)) continue;
      if (_isClaim && _i != 0) continue; // only update/claim for first address and use second as forwarding

      uint256 _userBalance = _balances[_i];
      uint256 _userIntegral = _rewardType.rewardIntegralFor[_accounts[_i]];
      uint256 _rewardAccrued = 0;

      // Calculate rewards accrued since last checkpoint for the user
      if (_rewardType.rewardIntegral > _userIntegral) {
        _rewardAccrued = (_userBalance * (_rewardType.rewardIntegral - _userIntegral)) / WAD;
      }

      if (_isClaim) {
        uint256 _claimablePreviously = _rewardType.claimableReward[_accounts[_i]];
        uint256 _totalReceivable = _claimablePreviously + _rewardAccrued;

        if (_totalReceivable > 0) {
          // Cap receivable amount by the available remaining rewards
          if (_totalReceivable > _rewardType.rewardRemaining) {
            _totalReceivable = _rewardType.rewardRemaining;
          }

          // Update state *before* transfer
          _rewardType.claimableReward[_accounts[_i]] = 0; // Reset claimable
          _rewardType.rewardIntegralFor[_accounts[_i]] = _rewardType.rewardIntegral; // Update integral
          _rewardType.rewardRemaining -= _totalReceivable; // Decrease remaining

          if (_rewardType.rewardToken == address(protocolToken)) {
            totalKiteRewardsAvailable -= _totalReceivable;
          }

          // Transfer rewards
          IERC20(_rewardType.rewardToken).safeTransfer(_accounts[_i + 1], _totalReceivable);

          emit StakingManagerRewardPaid(_accounts[_i], _rewardType.rewardToken, _totalReceivable, _accounts[_i + 1]);
        } else {
          // If no rewards to claim, still update the integral
          _rewardType.rewardIntegralFor[_accounts[_i]] = _rewardType.rewardIntegral;
        }
      } else {
        // Not claiming, just checkpointing
        // Add newly accrued rewards to the user's claimable balance
        _rewardType.claimableReward[_accounts[_i]] += _rewardAccrued;
        // Update user's reward integral
        _rewardType.rewardIntegralFor[_accounts[_i]] = _rewardType.rewardIntegral;
      }
    }
  }

  function _checkpoint(address[2] memory _accounts) internal {
    uint256 _supply = totalStaked;
    uint256[2] memory _depositedBalance;
    _depositedBalance[0] = stakedBalances[_accounts[0]];
    _depositedBalance[1] = stakedBalances[_accounts[1]];

    _claimManagerRewards();

    for (uint256 _i = 0; _i < rewards; _i++) {
      _calcRewardIntegral(_i, _accounts, _depositedBalance, _supply, false);
    }
  }

  function _checkpointAndClaim(address[2] memory _accounts) internal {
    uint256 _supply = totalStaked;
    uint256[2] memory _depositedBalance;
    _depositedBalance[0] = stakedBalances[_accounts[0]]; // only do first slot

    _claimManagerRewards();

    for (uint256 _i = 0; _i < rewards; _i++) {
      _calcRewardIntegral(_i, _accounts, _depositedBalance, _supply, true);
    }
  }

  function _claimManagerRewards() internal {
    for (uint256 _i = 0; _i < rewards; _i++) {
      RewardType storage _rewardType = _rewardTypes[_i];
      if (!_rewardType.isActive) continue;

      IRewardPool _rewardPool = IRewardPool(_rewardType.rewardPool);

      uint256 _reward = _rewardPool.getReward();
      if (_rewardType.rewardToken == address(protocolToken)) {
        totalKiteRewardsAvailable += _reward;
      }
    }
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    if (_param == 'cooldownPeriod') {
      _params.cooldownPeriod = _data.toUint256();
    } else {
      revert UnrecognizedParam();
    }
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.cooldownPeriod.assertNonNull().assertGt(0);
    address(stakingToken).assertHasCode();
    address(protocolToken).assertHasCode();
  }
}

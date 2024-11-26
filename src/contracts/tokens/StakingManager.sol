// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IProtocolToken} from "@interfaces/tokens/IProtocolToken.sol";
import {IStakingToken} from "@interfaces/tokens/IStakingToken.sol";

import {IRewardPool} from "@interfaces/tokens/IRewardPool.sol";

import {IStakingManager} from "@interfaces/tokens/IStakingManager.sol";

import {Authorizable} from "@contracts/utils/Authorizable.sol";
import {Modifiable} from "@contracts/utils/Modifiable.sol";

/**
 * @title  StakingManager
 * @notice This contract is used to manage staking positions
 *         and to distribute staking rewards
 */
contract StakingManager is Authorizable, Modifiable, IStakingManager {
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
    function params()
        external
        view
        returns (StakingManagerParams memory _params)
    {
        return _params;
    }

    // --- Data ---

    /// @inheritdoc IStakingManager
    uint256 public cooldownPeriod = 3 days;

    /// @inheritdoc IStakingManager
    uint256 public stakedSupply;

    /// @inheritdoc IStakingManager
    mapping(address => uint256) public stakedBalances;

    /// @inheritdoc IStakingManager
    // mapping(address => PendingWithdrawal[]) public pendingWithdrawals;
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    mapping(address => RewardType) public _rewardTypes;

    /// @inheritdoc IStakingManager
    function rewardTypes(
        uint256 _id
    ) external view returns (RewardType memory _rewardType) {
        return _rewardTypes[_id];
    }

    /// @inheritdoc IStakingManager
    uint256 public rewards;

    // --- Init ---

    /**
     * @param  _protocolToken Address of the ProtocolToken contract
     * @param  _stakingToken Address of the StakingToken contract
     */
    constructor(
        address _protocolToken,
        address _stakingToken
    ) Authorizable(msg.sender) {
        stakingToken = IStakingToken(_stakingToken);
        protocolToken = IProtocolToken(_protocolToken);
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
        uint256 rewardCount = rewards;
        for (uint256 _i = 0; i < rewardCount; _i++) {
            RewardType memory rewardType = _rewardTypes[_i];
            if (rewardType.isActive) {
                IRewardPool rewardPool = rewardType.rewardPool;
                rewardPool.stake(_wad);
            }
        }

        emit StakingManager_Staked(_account, _wad);
    }

    /// @inheritdoc IStakingManager
    function initiateWithdrawal(uint256 _wad) external {
        if (_wad == 0) revert StakingManager_WithdrawNullAmount();

        PendingWithdrawal storage _existingWithdrawal = pendingWithdrawals[
            msg.sender
        ];
        if (_existingWithdrawal.amount != 0) {
            stakedBalances[msg.sender] -= _wad;
            _existingWithdrawal.amount += _wad;
            _existingWithdrawal.timestamp = block.timestamp;
            return;
        }
        stakedBalances[msg.sender] -= _wad;
        pendingWithdrawals[msg.sender] = PendingWithdrawal({
            amount: _wad,
            timestamp: block.timestamp
        });

        // Call decreaseStake in the reward pools
        uint256 rewardCount = rewards.length;
        for (uint256 i = 0; i < rewardCount; i++) {
            RewardType memory rewardType = _rewardTypes[_id];
            if (rewardType.isActive) {
                IRewardPool rewardPool = rewardType.rewardPool;
                rewardPool.decreaseStake(_wad);
            }
        }

        emit StakingManager_WithdrawalInitiated(msg.sender, _wad);
    }

    /// @inheritdoc IStakingManager
    function cancelWithdrawal() {
        PendingWithdrawal storage _existingWithdrawal = pendingWithdrawals[
            msg.sender
        ];

        if (_existingWithdrawal.amount == 0) {
            revert StakingManager_NoPendingWithdrawal();
        }

        delete pendingWithdrawals[msg.sender];

        stakedBalances[msg.sender] += _existingWithdrawal.amount; // return the tokens to the staked balance

        // Call increaseStake in the reward pools
        uint256 rewardCount = rewards.length;
        for (uint256 i = 0; i < rewardCount; i++) {
            RewardType memory rewardType = _rewardTypes[_id];
            if (rewardType.isActive) {
                IRewardPool rewardPool = rewardType.rewardPool;
                rewardPool.increaseStake(_existingWithdrawal.amount);
            }
        }

        emit StakingManager_WithdrawalCancelled(
            msg.sender,
            _existingWithdrawal.amount
        );
    }

    /// @inheritdoc IStakingManager
    function withdraw() {
        PendingWithdrawal storage _existingWithdrawal = pendingWithdrawals[
            msg.sender
        ];

        if (_existingWithdrawal.amount == 0) {
            revert StakingManager_NoPendingWithdrawal();
        }

        if (block.timestamp - _existingWithdrawal.timestamp < cooldownPeriod) {
            revert StakingManager_CooldownPeriodNotElapsed();
        }

        delete pendingWithdrawals[msg.sender];

        stakingToken.burnFrom(msg.sender, _existingWithdrawal.amount);

        protocolToken.safeTransfer(msg.sender, _existingWithdrawal.amount);

        emit StakingManager_Withdrawn(msg.sender, _existingWithdrawal.amount);
    }

    /// @inheritdoc IStakingManager
    function emergencyWithdraw(
        address _rescueReceiver,
        uint256 _wad
    ) isAuthorized {
        if (_wad == 0) revert StakingManager_WithdrawNullAmount();

        protocolToken.safeTransfer(_rescueReceiver, _wad);

        emit StakingManager_EmergencyWithdrawal(_rescueReceiver, _wad);
    }

    /// @inheritdoc IStakingManager
    function emergencyWithdrawReward(
        uint256 _id,
        address _rescueReceiver,
        uint256 _wad
    ) isAuthorized {
        if (_rewardTypes[_id].rewardToken == address(0))
            revert StakingManager_InvalidRewardType();
        if (_wad == 0) revert StakingManager_WithdrawNullAmount();

        IERC20(_rewardTypes[_id].rewardToken).safeTransfer(
            _rescueReceiver,
            _wad
        );

        protocolToken.safeTransfer(_rescueReceiver, _wad);

        emit StakingManager_EmergencyRewardWithdrawal(
            _rescueReceiver,
            _rewardTypes[_id].rewardToken,
            _wad
        );
    }

    /// @inheritdoc IStakingManager
    function getReward(address _account) external {
        _checkpointAndClaim([_account, _account]);
    }

    /// @inheritdoc IStakingManager
    function getRewardAndForward(
        address _account,
        address _forwardTo
    ) external {
        if (msg.sender != _account) revert StakingManager_ForwardingOnly();

        _checkpointAndClaim([_account, _forwardTo]);
    }

    /// @inheritdoc IStakingManager
    function addRewardType(
        address _rewardToken,
        address _rewardPool
    ) external isAuthorized {
        if (_rewardToken == address(0)) revert StakingManager_NullRewardToken();
        if (_rewardPool == address(0)) revert StakingManager_NullRewardPool();

        uint256 _id = ++rewards;

        _rewardTypes[_id] = RewardType({
            rewardToken: _rewardToken,
            rewardPool: _rewardPool,
            isActive: true,
            rewardIntegral: 0,
            rewardRemaining: 0
        });

        emit StakingManager_AddRewardType(_id, _rewardToken, _rewardPool);
    }

    /// @inheritdoc IStakingManager
    function activateRewardType(uint256 _id) external isAuthorized {
        if (_rewardTypes[_id].rewardToken == address(0))
            revert StakingManager_InvalidRewardType();
        _rewardTypes[_id].isActive = true;
        emit StakingManager_ActivateRewardType(_id);
    }

    /// @inheritdoc IStakingManager
    function deactivateRewardType(uint256 _id) external isAuthorized {
        if (_rewardTypes[_id].rewardToken == address(0))
            revert StakingManager_InvalidRewardType();
        _rewardTypes[_id].isActive = false;
        emit StakingManager_DeactivateRewardType(_id);
    }

    /// @inheritdoc IStakingManager
    function earned(
        address _account
    ) external returns (EarnedData[] memory claimable) {
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

    function _earned(
        address _account
    ) internal view returns (EarnedData[] memory claimable) {
        claimable = new EarnedData[](rewards);

        for (uint256 i = 0; i < rewards; i++) {
            RewardType storage rewardType = _rewardTypes[i];

            if (rewardType.rewardToken == address(0)) {
                continue;
            }

            claimable[i].rewardToken = rewardType.rewardToken;
            claimable[i].rewardAmount = rewardType.claimableReward[_account];
        }
        return claimable;
    }

    // TODO: Check decimals
    function _calcRewardIntegral(
        uint256 _id,
        address[2] memory _accounts,
        uint256[2] memory _balances,
        uint256 _supply,
        bool _isClaim
    ) {
        RewardType memory rewardType = _rewardTypes[_id];

        if (!rewardType.isActive) return;

        uint256 balance = IERC20(rewardType.rewardToken).balanceOf(
            address(this)
        );

        // Checks if new rewards have been added by comparing current balance with rewardRemaining
        if (balance > rewardType.rewardRemaining) {
            uint256 newRewards = balance - rewardType.rewardRemaining;
            // If there are new rewards and there are existing stakers
            if (_supply > 0) {
                rewardType.rewardIntegral += newRewards / _supply;
                rewardType.rewardRemaining = balance;
            }
        }

        for (uint256 i = 0; i < _accounts.length; i++) {
            if (_accounts[i] == address(0)) continue;
            if (is_claim && i != 0) continue; //only update/claim for first address and use second as forwarding

            uint256 userBalance = _balances[i];
            uint256 userIntegral = rewardType.rewardIntegralFor[_accounts[i]];

            if (_isClaim || userIntegral < rewardType.rewardIntegral) {
                if (_isClaim) {
                    // Calculate total receiveable rewards
                    uint256 receiveable = rewardType.claimableReward[
                        _accounts[i]
                    ] +
                        (userBalance *
                            (rewardType.rewardIntegral - userIntegral));
                    // (rewardType.rewardIntegral - userIntegral).div(
                    //     1e20
                    // ));

                    if (receiveable > 0) {
                        // Reset claimable rewards to 0
                        rewardType.claimableReward[_accounts[i]] = 0;

                        // Transfer rewards to the next address in the array (forwarding address)
                        IERC20(rewardType.rewardToken).safeTransfer(
                            _accounts[i + 1],
                            receiveable
                        );

                        emit StakingManager_RewardPaid(
                            _accounts[i],
                            rewardType.rewardToken,
                            receiveable,
                            _accounts[i + 1]
                        );
                        // Update the remaining balance
                        balance = balance.sub(receiveable);
                    }
                } else {
                    // Just accumulate rewards without claiming
                    rewardType.claimableReward[_accounts[i]] =
                        rewardType.claimableReward[_accounts[i]] +
                        (userBalance *
                            (rewardType.rewardIntegral - userIntegral));
                    // (rewardType.rewardIntegral - userIntegral).div(
                    //     1e20
                    // ));
                }
            }
        }

        // Update remaining reward here since balance could have changed if claiming
        if (balance != reward.rewardRemaining) {
            reward.rewardRemaining = uint256(balance);
        }
    }

    function _checkPoint(address[2] memory _accounts) internal {
        uint256 supply = stakingToken.totalSupply();
        uint256[2] memory depositedBalance;
        depositedBalance[0] = stakingToken.balanceOf(_accounts[0]);
        depositedBalance[1] = stakingToken.balanceOf(_accounts[1]);

        _claimManagerRewards();

        for (uint256 i = 0; i < rewards; i++) {
            _calcRewardIntegral(i, _accounts, depositedBalance, supply, false);
        }
    }

    function _checkpointAndClaim(address[2] memory _accounts) internal {
        uint256 supply = stakingToken.totalSupply();
        uint256[2] memory depositedBalance;
        depositedBalance[0] = stakingToken.balanceOf(_accounts[0]); //only do first slot

        _claimManagerRewards();

        for (uint256 i = 0; i < rewards; i++) {
            _calcRewardIntegral(i, _accounts, depositedBalance, supply, true);
        }
    }

    function _claimManagerRewards() internal {
        for (uint256 i = 0; i < rewards; i++) {
            RewardType memory rewardType = _rewardTypes[i];
            RewardPool memory rewardPool = rewardType.rewardPool;
            if (!rewardType.isActive) continue;
            rewardPool.getReward(address(this));
        }
    }

    // --- Administration ---

    /// @inheritdoc Modifiable
    function _modifyParameters(bytes32 _param, bytes memory _data) {
        uint256 _uint256 = _data.toUint256();
        if (_param == "cooldownPeriod") _params.cooldownPeriod = _uint256;
    }

    /// @inheritdoc Modifiable
    function _validateParameters() {
        _params.cooldownPeriod.assertNonNull().assertGt(0);
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title  IRewardPool
 * @notice Interface for the RewardPool contract which manages reward distribution
 */
interface IRewardPool {
    // --- Events ---

    /**
     * @notice Emitted when tokens are staked
     * @param _account The address that staked tokens
     * @param _amount Amount of tokens staked [wad]
     */
    event RewardPool_Staked(address indexed _account, uint256 _amount);

    /**
     * @notice Emitted when stake is increased
     * @param _account The address that increased stake
     * @param _amount Amount of tokens added to stake [wad]
     */
    event RewardPool_IncreaseStake(address indexed _account, uint256 _amount);

    /**
     * @notice Emitted when stake is decreased
     * @param _account The address that decreased stake
     * @param _amount Amount of tokens removed from stake [wad]
     */
    event RewardPool_DecreaseStake(address indexed _account, uint256 _amount);

    /**
     * @notice Emitted when tokens are withdrawn
     * @param _account The address that withdrew tokens
     * @param _amount Amount of tokens withdrawn [wad]
     */
    event RewardPool_Withdrawn(address indexed _account, uint256 _amount);

    /**
     * @notice Emitted when rewards are paid out
     * @param _account The address that received rewards
     * @param _reward Amount of reward tokens paid [wad]
     */
    event RewardPool_RewardPaid(address indexed _account, uint256 _reward);

    /**
     * @notice Emitted when new rewards are added
     * @param _reward Amount of reward tokens added [wad]
     */

    event RewardPool_RewardAdded(uint256 _reward);

    /**
     * @notice Emitted on emergency withdrawal
     * @param _account The address that performed the withdrawal
     * @param _amount Amount withdrawn [wad]
     */
    event RewardPool_EmergencyWithdrawal(
        address indexed account,
        uint256 amount
    );

    // --- Errors ---

    /// @notice Throws when reward token address is invalid
    error RewardPool_InvalidRewardToken();

    /// @notice Throws when attempting to stake zero tokens
    error RewardPool_StakeNullAmount();

    /// @notice Throws when attempting to increase stake by zero
    error RewardPool_IncreaseStakeNullAmount();

    /// @notice Throws when attempting to decrease stake by zero
    error RewardPool_DecreaseStakeNullAmount();

    /// @notice Throws when attempting to withdraw zero tokens
    error RewardPool_WithdrawNullAmount();

    /// @notice Throws when balance is insufficient for operation
    error RewardPool_InsufficientBalance();

    /// @notice Throws when reward amount is invalid
    error RewardPool_InvalidRewardAmount();

    // --- Structs ---

    struct RewardPoolParams {
        uint256 duration; // Duration of rewards distribution
        uint256 newRewardRatio; // Ratio for accepting new rewards
    }

    // --- Data ---

    /**
     * @notice Getter for the reward token
     * @return _rewardToken The reward token being distributed
     */
    function rewardToken() external view returns (IERC20 _rewardToken);

    /**
     * @notice Getter for the contract parameters struct
     * @return _rewardPoolParams RewardPool parameters struct
     */
    function params()
        external
        view
        returns (RewardPoolParams memory _rewardPoolParams);

    /**
     * @notice Getter for the Total amount of tokens staked
     * @return _totalStaked Total amount of tokens staked
     */
    function totalStaked() external view returns (uint256 _totalStaked);

    /**
     * @notice Getter for the last timestamp that rewards were applicable
     * @return _periodFinish last timestamp that rewards were applicable
     */
    function lastTimeRewardApplicable()
        external
        view
        returns (uint256 _periodFinish);

    /**
     * @notice Calculates the reward per token stored
     * @return _rewardPerToken reward per token stored
     */
    function rewardPerToken() external view returns (uint256 _rewardPerToken);

    /**
     * @notice Getter for the earned rewards for an account
     * @return _earned earned rewards for an account
     */
    function earned() external view returns (uint256 _earned);

    // --- Methods ---

    /// @notice Stake tokens in the pool
    function stake(uint256 amount) external;

    /// @notice Increase staked amount
    function increaseStake(uint256 amount) external;

    /// @notice Decrease staked amount
    function decreaseStake(uint256 amount) external;

    /// @notice Withdraw staked tokens
    function withdraw(uint256 amount, bool claim) external;

    /// @notice Claim earned rewards
    function getReward() external;

    /// @notice Queue new rewards for distribution
    function queueNewRewards(uint256 amount) external;

    /// @notice Notify reward amount for immediate distribution
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Emergency withdrawal of reward tokens
    function emergencyWithdraw(address _rescueReceiver, uint256 _wad) external;

    /// @notice Returns the address of the staking manager
    /// @return The address of the staking manager
    function stakingManager() external view returns (address);
}

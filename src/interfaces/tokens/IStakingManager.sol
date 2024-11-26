// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStakingToken} from "@interfaces/tokens/IStakingToken.sol";

import {IAuthorizable} from "@interfaces/utils/IAuthorizable.sol";
import {IModifiable} from "@interfaces/utils/IModifiable.sol";

interface IStakingManager is IAuthorizable, IModifiable {
    // --- Events ---

    /**
     * @notice Emitted when a new reward type is added
     * @param  _id Id of the reward type
     * @param  _rewardToken Address of the reward token
     * @param  _rewardPool Address of the reward pool
     */
    event StakingManager_AddRewardType(
        uint256 indexed _id,
        address indexed _rewardToken,
        address indexed _rewardPool
    );

    /**
     * @notice Emitted when an existing reward type is activated
     * @param  _id Id of the reward type
     */
    event StakingManager_ActivateRewardType(uint256 indexed _id);

    /**
     * @notice Emitted when an existing reward type is deactivated
     * @param  _id Id of the reward type
     */
    event StakingManager_DeactivateRewardType(uint256 indexed _id);

    /**
     * @notice Emitted when a user stakes tokens
     * @param _account Address of the user staking the tokens
     * @param _wad Amount of tokens staked
     */
    event StakingManager_Staked(address indexed _account, uint256 _wad);

    /**
     * @notice Emitted when a user initiates a withdrawal of staked tokens
     * @param  _account Address of the user initiating the withdrawal
     * @param  _wad Amount of tokens withdrawn
     */
    event StakingManager_WithdrawalInitiated(
        address indexed _account,
        uint256 _wad
    );

    /**
     * @notice Emitted when a user cancels a pending withdrawal of staked tokens
     * @param  _account Address of the user that cancelled the withdrawal
     * @param  _wad Amount of tokens in the cancelled withdrawal
     */
    event StakingManager_WithdrawalCancelled(
        address indexed _account,
        uint256 _wad
    );

    /**
     * @notice Emitted when a user withdraws staked tokens from a pending withdrawal
     * @param  _account Address of the user that withdrew
     * @param  _wad Amount of tokens withdrawn
     */
    event StakingManager_Withdrawn(address indexed _account, uint256 _wad);

    /**
     * @notice Emitted when an emergency withdrawal is executed
     * @param  _account Address that the tokens were sent to from the emergency withdrawal
     * @param  _wad Amount of tokens withdrawn
     */
    event StakingManager_EmergencyWithdrawal(
        address indexed _account,
        uint256 _wad
    );

    /**
     * @notice Emitted when an emergency reward withdrawal is executed
     * @param  _account Address that the tokens were sent to from the emergency reward withdrawal
     * @param  _rewardToken Address of the reward token
     * @param  _wad Amount of reward tokens withdrawn
     */
    event StakingManager_EmergencyRewardWithdrawal(
        address indexed _account,
        address indexed _rewardToken,
        uint256 _wad
    );

    /**
     * @notice Emitted when a reward is paid to a user
     * @param  _account Address of the user that earned the rewards
     * @param  _rewardToken Address of the reward token
     * @param  _wad Amount of rewards paid
     * @param  _destination Address of the destination the rewards were sent to
     */
    event StakingManager_RewardPaid(
        address indexed _account,
        address indexed _rewardToken,
        uint256 _wad,
        address indexed _destination
    );

    // --- Errors ---

    /// @notice Throws when trying to access an invalid reward type
    error StakingManager_InvalidRewardType();

    /// @notice Throws when trying to stake a null amount
    error StakingManager_StakeNullAmount();

    /// @notice Throws when trying to stake and mint $stKITE to a null address
    error StakingManager_StakeNullReceiver();

    /// @notice Throws when trying to withdraw a null amount
    error StakingManager_WithdrawNullAmount();

    /// @notice Throws when trying to withdraw a negative amount
    error StakingManager_WithdrawNegativeAmount();

    /// @notice Throws when trying to cancel or withdraw with no pending withdrawal
    error StakingManager_NoPendingWithdrawal();

    /// @notice Throws when trying to withdraw and the cooldown period hasn't elapsed
    error StakingManager_CooldownPeriodNotElapsed();

    /// @notice Throws when trying to add a reward type with a null reward token
    error StakingManager_NullRewardToken();

    /// @notice Throws when trying to add a reward type with a null reward pool
    error StakingManager_NullRewardPool();

    /// @notice Throws when trying to calculate rewards on an inactive reward type
    error StakingManager_InactiveRewardType();

    /// @notice Throws when trying to forward rewards without being the account owner
    error StakingManager_ForwardingOnly();

    // --- Data ---

    struct RewardType {
        // Address of the reward token
        address rewardToken;
        // Address of the reward pool
        address rewardPool;
        // Flag if this reward type is currently active
        bool isActive;
        // Total amount of rewards accrued by the contract
        uint256 rewardIntegral;
        // Total amount of rewards remaining to be claimed
        uint256 rewardRemaining;
        // Stores reward integral for each user
        mapping(address => uint256) rewardIntegralFor;
        // Stores claimable rewards for each user
        mapping(address => uint256) claimableReward;
    }

    struct EarnedData {
        // Address of the reward token
        address rewardToken;
        // Amount of rewards
        uint256 rewardAmount;
    }

    struct PendingWithdrawal {
        // Amount of tokens withdrawal was initiated for
        uint256 amount;
        // Timestamp of when withdrawal was initiated
        uint256 timestamp;
    }

    struct StakingManagerParams {
        uint256 cooldownPeriod;
    }

    // --- Registry ---

    /// @notice Address of the protocol token
    function protocolToken() external view returns (address _protocolToken);

    /// @notice Address of the staking token
    function stakingToken() external view returns (address _stakingToken);

    // --- Params ---

    /**
     * @notice Getter for the contract parameters struct
     * @return _params StakingManager parameters struct
     */
    function params()
        external
        view
        returns (StakingManagerParams memory _params);

    /**
     * @notice Getter for the unpacked contract parameters struct
     * @return _cooldownPeriod How long a user has to wait before they can withdraw after initiating a withdrawal
     */
    // solhint-disable-next-line private-vars-leading-underscore
    function _params() external view returns (uint256 _cooldownPeriod);

    // --- Data ---

    /**
     * @notice The delay between when a withdrawal is initiated and when it is processed
     * @return _cooldownPeriod Duration of the cooldown period in seconds
     */
    function cooldownPeriod() external view returns (uint256 _cooldownPeriod);

    /**
     * @notice The total amount of tokens staked in the staking manager
     * @return _stakedSupply Total amount of tokens that is currently staked in the staking manager [wad]
     */
    function stakedSupply() external view returns (uint256 _stakedSupply);

    /**
     * @notice The total amount of reward types
     * @return _rewards Total amount of reward types [wad]
     */
    function rewards() external view returns (uint256 _rewards);

    /**
     * @notice Data of a reward type
     * @param  _id Id of the reward type
     * @return _rewardType RewardType data struct
     */
    function rewardTypes(
        uint256 _id
    ) external view returns (RewardType memory _rewardType);

    /**
     * @notice A mapping storing user's staked balances
     * @param  _account Address of the user
     * @return _stakedBalance User's staked balance [wad]
     */
    function stakedBalances(
        address _account
    ) external view returns (uint256 _stakedBalance);

    /**
     * @notice A mapping storing user pending withdrawals
     * @param  _account Address of the user
     * @return _pendingWithdrawal PendingWithdrawal type data struct
     */
    function pendingWithdrawals(
        address _account
    ) external view returns (PendingWithdrawal memory _pendingWithdrawal);

    // --- Methods ---

    /**
     * @notice Stake $KITE tokens
     * @param _account Account that will receive the minted $stKITE
     * @param _wad Amount of $KITE being staked [wad]
     */
    function stake(address _account, uint256 _wad) external;

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

    /**
     * @notice Emergency withdraw all staked $KITE
     * @param _rescueReceiver Account that will receive the withdrawn $KITE
     * @param _wad Amount of $KITE being withdrawn [wad]
     */
    function emergencyWithdraw(address _rescueReceiver, uint256 _wad) external;

    /**
     * @notice Emergency withdraw rewards from the staking manager
     * @param _id ID of the reward type
     * @param _rescueReceiver Account that will receive the withdrawn tokens
     * @param _wad Amount of tokens being withdrawn [wad]
     */
    function emergencyWithdrawReward(
        uint256 _id,
        address _rescueReceiver,
        uint256 _wad
    ) external;

    /**
     * @notice Claims earned rewards
     * @param _account Address of the account that will receive the rewards
     */
    function getReward(address _account) external;

    /**
     * @notice Claims and forwards earned rewards
     * @param _account Address of the account that earned the rewards
     * @param _forwardTo Address of the account that will receive the rewards
     */
    function getRewardAndForward(address _account, address _forwardTo) external;

    /**
     * @notice Add a new reward type
     * @param _rewardToken Address of the reward token
     * @param _rewardPool Address of the reward pool
     */
    function addRewardType(address _rewardToken, address _rewardPool) external;

    /**
     * @notice Activate an existing reward type
     * @param _id ID of the reward type
     */
    function activateRewardType(uint256 _id) external;

    /**
     * @notice Deactivate an existing reward type
     * @param _id ID of the reward type
     */
    function deactivateRewardType(uint256 _id) external;

    /**
     * @notice Check rewards earned for an account
     * @param _account Account to check
     */
    function earned(
        address _account
    ) external returns (EarnedData[] memory claimable);

    /**
     * @notice Checkpoint account balances
     * @param _accounts Accounts to checkpoint
     */
    function checkpoint(address[2] memory _accounts) external;

    /**
     * @notice Checkpoint account balance
     * @param _account Account to checkpoint
     */
    function userCheckpoint(address _account) external returns (bool);
}

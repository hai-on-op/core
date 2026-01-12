// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityPool} from "@interfaces/IStabilityPool.sol";

/**
 * @title IEmissionsController
 * @notice Interface for the EmissionsController that distributes KITE over 1 year
 */
interface IEmissionsController {
    // --- Events ---

    /**
     * @notice Emitted when the reward split is updated
     * @param  _stabilityPoolSplit Percentage going to stability pool (0-100)
     * @param  _mintingSplit Percentage going to minting (0-100)
     */
    event UpdateRewardSplit(uint256 _stabilityPoolSplit, uint256 _mintingSplit);

    /**
     * @notice Emitted when rewards are claimed for the stability pool
     * @param  _amount Amount of KITE claimed [wad]
     */
    event ClaimRewardsForStabilityPool(uint256 _amount);

    /**
     * @notice Emitted when minting rewards are marked as distributed
     * @param  _amount Amount of minting rewards marked as distributed [wad]
     */
    event MarkMintingRewardsDistributed(uint256 _amount);

    // --- Errors ---

    /// @notice Throws when trying to update split too frequently
    error EmissionsController_SplitUpdateTooFrequent();
    /// @notice Throws when trying to claim rewards before emissions start
    error EmissionsController_EmissionsNotStarted();
    /// @notice Throws when trying to claim rewards after emissions end
    error EmissionsController_EmissionsEnded();

    // --- Methods ---

    /**
     * @notice Updates the reward split ratio based on price deviation
     * @dev    Can be called by anyone, max once per hour
     */
    function updateRewardSplit() external;

    /**
     * @notice Claims accrued KITE rewards for the stability pool
     * @dev    Can only be called by the StabilityPool contract
     * @return _amount Amount of KITE claimed [wad]
     */
    function claimRewardsForStabilityPool() external returns (uint256 _amount);

    /**
     * @notice Marks minting rewards as distributed (resets counter)
     * @param  _amount Amount of minting rewards that were distributed [wad]
     */
    function markMintingRewardsDistributed(uint256 _amount) external;

    // --- View Methods ---

    /**
     * @notice Returns the accrued KITE rewards for the stability pool
     * @return _amount Amount of accrued KITE [wad]
     */
    function getAccruedRewardsForStabilityPool()
        external
        view
        returns (uint256 _amount);

    /**
     * @notice Returns the accumulated minting rewards since last distribution
     * @return _amount Amount of minting rewards to distribute [wad]
     */
    function getMintingRewardsToDistribute()
        external
        view
        returns (uint256 _amount);
}

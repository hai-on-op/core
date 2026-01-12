// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@libraries/Math.sol";
import {IEmissionsController} from "@interfaces/IEmissionsController.sol";
import {IStabilityPool} from "@interfaces/IStabilityPool.sol";
import {IOracleRelayer} from "@interfaces/IOracleRelayer.sol";
import {Authorizable} from "@contracts/utils/Authorizable.sol";

/**
 * @title EmissionsController
 * @notice Distributes KITE over 1 year, splitting emissions between StabilityPool and minting incentives
 * @dev Uses hybrid streaming mechanism with checkpoint-based reward tracking
 */
contract EmissionsController is Authorizable, IEmissionsController {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // --- State Variables ---

    /// @notice The KITE token
    IERC20 public immutable kiteToken;

    /// @notice Contract providing market/redemption prices
    IOracleRelayer public immutable oracleRelayer;

    /// @notice Address of StabilityPool contract
    IStabilityPool public immutable stabilityPool;

    /// @notice Total KITE to distribute over 1 year
    uint256 public immutable totalKiteAmount;

    /// @notice When emissions started
    uint256 public immutable emissionStartTime;

    /// @notice When emissions end (startTime + 1 year)
    uint256 public immutable emissionEndTime;

    /// @notice Percentage (0-100) going to stability pool
    uint256 public stabilityPoolSplit;

    /// @notice Percentage (0-100) going to minting (100 - stabilityPoolSplit)
    uint256 public mintingSplit;

    /// @notice Upper/lower limit for deviation (10% = 0.1e18)
    uint256 public deviationLimit;

    /// @notice Last time split was updated (for rate limiting)
    uint256 public lastSplitUpdateTime;

    // --- Hybrid Streaming Mechanism ---

    /// @notice Last time rewards were checkpointed
    uint256 public lastCheckpointTime;

    /// @notice Cumulative KITE emitted to stability pool up to last checkpoint
    uint256 public stabilityPoolCumulativeRewards;

    /// @notice Cumulative KITE emitted to minting up to last checkpoint
    uint256 public mintingCumulativeRewards;

    /// @notice Last amount of minting rewards that were distributed (checkpoint for off-chain script)
    uint256 public mintingRewardsLastDistributed;

    /// @notice Current per-second emission rate for stability pool [wad per second]
    uint256 public currentStabilityPoolRate;

    /// @notice Current per-second emission rate for minting [wad per second]
    uint256 public currentMintingRate;

    /// @notice When current rates started
    uint256 public currentRateStartTime;

    // --- Constructor ---

    /**
     * @param  _kiteToken Address of the KITE token
     * @param  _oracleRelayer Address of the OracleRelayer contract
     * @param  _stabilityPool Address of the StabilityPool contract
     * @param  _totalKiteAmount Total KITE to distribute over 1 year [wad]
     * @param  _deviationLimit Upper/lower limit for deviation (10% = 0.1e18) [wad]
     */
    constructor(
        IERC20 _kiteToken,
        IOracleRelayer _oracleRelayer,
        IStabilityPool _stabilityPool,
        uint256 _totalKiteAmount,
        uint256 _deviationLimit
    ) Authorizable(msg.sender) {
        kiteToken = _kiteToken;
        oracleRelayer = _oracleRelayer;
        stabilityPool = _stabilityPool;
        totalKiteAmount = _totalKiteAmount;
        deviationLimit = _deviationLimit;

        emissionStartTime = block.timestamp;
        emissionEndTime = block.timestamp + YEAR;

        // Initialize with 50/50 split
        stabilityPoolSplit = 50;
        mintingSplit = 50;

        // Calculate initial emission rates
        uint256 _totalRate = _totalKiteAmount / YEAR; // Total per-second rate
        currentStabilityPoolRate = (_totalRate * stabilityPoolSplit) / 100;
        currentMintingRate = (_totalRate * mintingSplit) / 100;

        lastCheckpointTime = block.timestamp;
        currentRateStartTime = block.timestamp;
        lastSplitUpdateTime = block.timestamp;
    }

    // --- Split Update Logic ---

    /**
     * @notice Updates the reward split ratio based on price deviation
     * @dev    Can be called by anyone, max once per hour
     */
    function updateRewardSplit() external {
        // Rate limit: max once per hour
        if (block.timestamp < lastSplitUpdateTime + HOUR) {
            revert EmissionsController_SplitUpdateTooFrequent();
        }

        // Checkpoint rewards up to now
        _checkpointRewards();

        // Get prices (both in RAY)
        uint256 _redemptionPrice = oracleRelayer.calcRedemptionPrice();
        uint256 _marketPrice = oracleRelayer.marketPrice();

        // Calculate deviation: (redemptionPrice - marketPrice) / redemptionPrice
        // Convert to WAD for easier calculation: deviation in WAD
        // Positive deviation: redemptionPrice > marketPrice (HAI below peg, more to stability pool)
        // Negative deviation: marketPrice > redemptionPrice (HAI above peg, more to minting)
        int256 _numerator = int256(_redemptionPrice) - int256(_marketPrice);
        int256 _deviationWad = (_numerator * int256(WAD)) / int256(_redemptionPrice);

        // Calculate new split
        uint256 _newStabilityPoolSplit;
        if (_deviationWad >= int256(deviationLimit)) {
            // deviation >= 0.10e18: 100% stability pool, 0% minting
            _newStabilityPoolSplit = 100;
        } else if (_deviationWad <= -int256(deviationLimit)) {
            // deviation <= -0.10e18: 0% stability pool, 100% minting
            _newStabilityPoolSplit = 0;
        } else {
            // Linear scaling from 50% base: stabilityPoolSplit = 50 + (deviation * 50) / deviationLimit
            // For positive deviation: more to stability pool
            // For negative deviation: more to minting
            int256 _scaledDeviation = (_deviationWad * 50) / int256(deviationLimit);
            int256 _newSplit = 50 + _scaledDeviation;
            if (_newSplit < 0) {
                _newStabilityPoolSplit = 0;
            } else if (_newSplit > 100) {
                _newStabilityPoolSplit = 100;
            } else {
                _newStabilityPoolSplit = uint256(_newSplit);
            }
        }

        // Update splits
        stabilityPoolSplit = _newStabilityPoolSplit;
        mintingSplit = 100 - _newStabilityPoolSplit;

        // Update rates
        uint256 _totalRate = totalKiteAmount / YEAR; // Total per-second rate
        currentStabilityPoolRate = (_totalRate * stabilityPoolSplit) / 100;
        currentMintingRate = (_totalRate * mintingSplit) / 100;
        currentRateStartTime = block.timestamp;

        lastSplitUpdateTime = block.timestamp;

        emit UpdateRewardSplit(stabilityPoolSplit, mintingSplit);
    }

    // --- Reward Checkpointing ---

    /**
     * @notice Checkpoints rewards up to the current time
     * @dev Updates cumulative rewards based on current rates and time elapsed
     */
    function _checkpointRewards() internal {
        uint256 _currentTime = block.timestamp;
        if (_currentTime <= lastCheckpointTime) return;

        // Cap at emission end time
        uint256 _checkpointTime = _currentTime > emissionEndTime ? emissionEndTime : _currentTime;
        uint256 _timeElapsed = _checkpointTime - lastCheckpointTime;

        // Calculate rewards accrued since last checkpoint
        uint256 _stabilityPoolRewards = currentStabilityPoolRate * _timeElapsed;
        uint256 _mintingRewards = currentMintingRate * _timeElapsed;

        // Update cumulative rewards
        stabilityPoolCumulativeRewards += _stabilityPoolRewards;
        mintingCumulativeRewards += _mintingRewards;

        lastCheckpointTime = _checkpointTime;
    }

    // --- Reward Claiming ---

    /**
     * @notice Claims accrued KITE rewards for the stability pool
     * @dev    Can only be called by the StabilityPool contract
     * @return _amount Amount of KITE claimed [wad]
     */
    function claimRewardsForStabilityPool() external returns (uint256 _amount) {
        if (msg.sender != address(stabilityPool)) {
            revert(); // Only StabilityPool can call
        }

        if (block.timestamp < emissionStartTime) {
            revert EmissionsController_EmissionsNotStarted();
        }

        // Checkpoint rewards up to now (will cap at emissionEndTime)
        _checkpointRewards();

        // Calculate accrued rewards
        _amount = stabilityPoolCumulativeRewards;

        if (_amount > 0) {
            // Reset cumulative rewards (they've been claimed)
            stabilityPoolCumulativeRewards = 0;

            // Transfer KITE to StabilityPool
            kiteToken.safeTransfer(address(stabilityPool), _amount);

            emit ClaimRewardsForStabilityPool(_amount);
        }
    }

    /**
     * @notice Returns the accrued KITE rewards for the stability pool
     * @return _amount Amount of accrued KITE [wad]
     */
    function getAccruedRewardsForStabilityPool() external view returns (uint256 _amount) {
        // Calculate current cumulative rewards (including uncheckpointed time)
        uint256 _currentTime = block.timestamp > emissionEndTime ? emissionEndTime : block.timestamp;
        uint256 _timeElapsed = _currentTime > lastCheckpointTime ? _currentTime - lastCheckpointTime : 0;

        uint256 _stabilityPoolRewards = currentStabilityPoolRate * _timeElapsed;
        _amount = stabilityPoolCumulativeRewards + _stabilityPoolRewards;
    }

    /**
     * @notice Returns the accumulated minting rewards since last distribution
     * @return _amount Amount of minting rewards to distribute [wad]
     */
    function getMintingRewardsToDistribute() external view returns (uint256 _amount) {
        // Calculate current cumulative rewards (including uncheckpointed time)
        uint256 _currentTime = block.timestamp > emissionEndTime ? emissionEndTime : block.timestamp;
        uint256 _timeElapsed = _currentTime > lastCheckpointTime ? _currentTime - lastCheckpointTime : 0;

        uint256 _mintingRewards = currentMintingRate * _timeElapsed;
        uint256 _totalMintingRewards = mintingCumulativeRewards + _mintingRewards;

        // Return only the new rewards since last distribution
        if (_totalMintingRewards > mintingRewardsLastDistributed) {
            _amount = _totalMintingRewards - mintingRewardsLastDistributed;
        } else {
            _amount = 0;
        }
    }

    /**
     * @notice Marks minting rewards as distributed (resets counter)
     * @param  _amount Amount of minting rewards that were distributed [wad]
     */
    function markMintingRewardsDistributed(uint256 _amount) external {
        // Checkpoint rewards first
        _checkpointRewards();

        // Update last distributed checkpoint
        uint256 _currentMintingRewards = mintingCumulativeRewards;
        if (_amount > _currentMintingRewards - mintingRewardsLastDistributed) {
            // Can't mark more than what's available
            _amount = _currentMintingRewards - mintingRewardsLastDistributed;
        }

        mintingRewardsLastDistributed += _amount;

        emit MarkMintingRewardsDistributed(_amount);
    }
}


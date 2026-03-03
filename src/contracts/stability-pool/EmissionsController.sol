// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, WAD, YEAR, HOUR} from '@libraries/Math.sol';

/**
 * @title EmissionsController
 * @notice Distributes KITE over 1 year, splitting emissions between stability and minting incentives
 */
contract EmissionsController is Authorizable, ReentrancyGuard, IEmissionsController {
  using SafeERC20 for IERC20;
  using Math for uint256;

  // --- Constants ---

  uint256 internal constant _PERCENT_BASE = 100;
  uint256 internal constant _SPLIT_BASELINE = 50;

  // --- Registry ---

  /// @notice The KITE token
  IERC20 public immutable kiteToken;

  /// @notice Contract providing market/redemption prices
  IOracleRelayer public immutable oracleRelayer;

  // --- Params ---

  /// @notice Total KITE to distribute over 1 year
  uint256 public immutable totalKiteAmount;

  /// @notice When emissions started
  uint256 public immutable emissionStartTime;

  /// @notice When emissions end (startTime + 1 year)
  uint256 public immutable emissionEndTime;

  // --- Data ---

  /// @inheritdoc IEmissionsController
  address public stabilityRewardsReceiver;

  /// @notice Percentage (0-100) going to stability pool side
  uint256 public stabilityPoolSplit;

  /// @notice Percentage (0-100) going to minting (100 - stabilityPoolSplit)
  uint256 public mintingSplit;

  /// @notice Upper/lower limit for deviation (10% = 0.1e18)
  uint256 public immutable deviationLimit;

  /// @notice Last time split was updated (for rate limiting)
  uint256 public lastSplitUpdateTime;

  /// @notice Last time rewards were checkpointed
  uint256 public lastCheckpointTime;

  /// @notice Cumulative KITE emitted to stability side up to last checkpoint
  uint256 public stabilityPoolCumulativeRewards;

  /// @notice Cumulative KITE emitted to minting up to last checkpoint
  uint256 public mintingCumulativeRewards;

  /// @notice Last amount of minting rewards that were distributed (checkpoint for off-chain script)
  uint256 public mintingRewardsLastDistributed;

  /// @notice Current per-second emission rate for stability side [wad per second]
  uint256 public currentStabilityPoolRate;

  /// @notice Current per-second emission rate for minting [wad per second]
  uint256 public currentMintingRate;

  /// @notice When current rates started
  uint256 public currentRateStartTime;

  // --- Init ---

  /**
   * @param  _kiteToken Address of the KITE token
   * @param  _oracleRelayer Address of the OracleRelayer
   * @param  _stabilityRewardsReceiver Address receiving stability-side emissions
   * @param  _totalKiteAmount Total KITE to distribute over 1 year [wad]
   * @param  _deviationLimit Upper/lower limit for deviation (10% = 0.1e18) [wad]
   */
  constructor(
    IERC20 _kiteToken,
    IOracleRelayer _oracleRelayer,
    address _stabilityRewardsReceiver,
    uint256 _totalKiteAmount,
    uint256 _deviationLimit
  ) Authorizable(msg.sender) {
    if (_stabilityRewardsReceiver == address(0)) revert EmissionsController_InvalidStabilityReceiver();

    kiteToken = _kiteToken;
    oracleRelayer = _oracleRelayer;
    stabilityRewardsReceiver = _stabilityRewardsReceiver;
    totalKiteAmount = _totalKiteAmount;
    deviationLimit = _deviationLimit;

    emissionStartTime = block.timestamp;
    emissionEndTime = block.timestamp + YEAR;

    // Initialize with 50/50 split
    stabilityPoolSplit = _SPLIT_BASELINE;
    mintingSplit = _SPLIT_BASELINE;

    // Calculate initial emission rates
    uint256 _totalRate = _totalKiteAmount / YEAR; // Total per-second rate
    currentStabilityPoolRate = (_totalRate * stabilityPoolSplit) / _PERCENT_BASE;
    currentMintingRate = (_totalRate * mintingSplit) / _PERCENT_BASE;

    lastCheckpointTime = block.timestamp;
    currentRateStartTime = block.timestamp;
    lastSplitUpdateTime = block.timestamp;
  }

  // --- Methods ---

  /// @inheritdoc IEmissionsController
  function updateRewardSplit() external nonReentrant {
    // Rate limit: max once per hour
    if (block.timestamp < lastSplitUpdateTime + HOUR) {
      revert EmissionsController_SplitUpdateTooFrequent();
    }

    _checkpointRewards();

    uint256 _redemptionPrice = oracleRelayer.calcRedemptionPrice();
    if (_redemptionPrice == 0) revert EmissionsController_InvalidRedemptionPrice();
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
      _newStabilityPoolSplit = _PERCENT_BASE;
    } else if (_deviationWad <= -int256(deviationLimit)) {
      // deviation <= -0.10e18: 0% stability pool, 100% minting
      _newStabilityPoolSplit = 0;
    } else {
      // Linear scaling from 50% base: stabilityPoolSplit = 50 + (deviation * 50) / deviationLimit
      // For positive deviation: more to stability pool
      // For negative deviation: more to minting
      int256 _scaledDeviation = (_deviationWad * int256(_SPLIT_BASELINE)) / int256(deviationLimit);
      int256 _newSplit = int256(_SPLIT_BASELINE) + _scaledDeviation;
      if (_newSplit < 0) {
        _newStabilityPoolSplit = 0;
      } else if (_newSplit > int256(_PERCENT_BASE)) {
        _newStabilityPoolSplit = _PERCENT_BASE;
      } else {
        _newStabilityPoolSplit = uint256(_newSplit);
      }
    }

    stabilityPoolSplit = _newStabilityPoolSplit;
    mintingSplit = _PERCENT_BASE - _newStabilityPoolSplit;

    uint256 _totalRate = totalKiteAmount / YEAR;
    currentStabilityPoolRate = (_totalRate * stabilityPoolSplit) / _PERCENT_BASE;
    currentMintingRate = (_totalRate * mintingSplit) / _PERCENT_BASE;
    currentRateStartTime = block.timestamp;

    lastSplitUpdateTime = block.timestamp;

    emit UpdateRewardSplit(stabilityPoolSplit, mintingSplit);
  }

  // --- Rewards ---

  /// @inheritdoc IEmissionsController
  function claimRewardsForStabilityPool() external nonReentrant returns (uint256 _amount) {
    if (msg.sender != stabilityRewardsReceiver) {
      revert EmissionsController_OnlyStabilityRewardsReceiver();
    }

    if (block.timestamp < emissionStartTime) {
      revert EmissionsController_EmissionsNotStarted();
    }

    _checkpointRewards();
    _amount = stabilityPoolCumulativeRewards;

    if (_amount > 0) {
      // Reset cumulative rewards (they've been claimed)
      stabilityPoolCumulativeRewards = 0;
      kiteToken.safeTransfer(stabilityRewardsReceiver, _amount);
      emit ClaimRewardsForStabilityPool(_amount);
    }
  }

  /// @inheritdoc IEmissionsController
  function setStabilityRewardsReceiver(address _receiver) external nonReentrant isAuthorized {
    if (_receiver == address(0)) revert EmissionsController_InvalidStabilityReceiver();

    _checkpointRewards();

    address _oldReceiver = stabilityRewardsReceiver;
    stabilityRewardsReceiver = _receiver;

    if (_oldReceiver != address(0) && _oldReceiver != _receiver && stabilityPoolCumulativeRewards > 0) {
      uint256 _accrued = stabilityPoolCumulativeRewards;
      stabilityPoolCumulativeRewards = 0;
      kiteToken.safeTransfer(_oldReceiver, _accrued);
      emit ClaimRewardsForStabilityPool(_accrued);
    }

    emit SetStabilityRewardsReceiver(_oldReceiver, _receiver);
  }

  /// @inheritdoc IEmissionsController
  function getAccruedRewardsForStabilityPool() external view returns (uint256 _amount) {
    // Calculate current cumulative rewards (including uncheckpointed time)
    uint256 _currentTime = block.timestamp > emissionEndTime ? emissionEndTime : block.timestamp;
    uint256 _timeElapsed = _currentTime > lastCheckpointTime ? _currentTime - lastCheckpointTime : 0;

    uint256 _stabilityPoolRewards = currentStabilityPoolRate * _timeElapsed;
    _amount = stabilityPoolCumulativeRewards + _stabilityPoolRewards;
  }

  /// @inheritdoc IEmissionsController
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

  /// @inheritdoc IEmissionsController
  function markMintingRewardsDistributed(uint256 _amount) external isAuthorized {
    _checkpointRewards();

    // Update last distributed checkpoint
    uint256 _currentMintingRewards = mintingCumulativeRewards;
    uint256 _available = _currentMintingRewards - mintingRewardsLastDistributed;
    if (_amount > _available) {
      _amount = _available;
    }

    mintingRewardsLastDistributed += _amount;
    emit MarkMintingRewardsDistributed(_amount);
  }

  // --- Internal Methods ---

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
}

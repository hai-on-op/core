// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title IEmissionsController
 * @notice Interface for the EmissionsController that distributes KITE over a configured duration
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
   * @notice Emitted when KITE is emergency withdrawn
   * @param  _rescueReceiver Address that received the withdrawn KITE
   * @param  _wad Amount of KITE withdrawn [wad]
   */
  event EmergencyWithdrawKite(address indexed _rescueReceiver, uint256 _wad);

  /**
   * @notice Emitted when minting rewards are marked as distributed
   * @param  _amount Amount of minting rewards marked as distributed [wad]
   */
  event MarkMintingRewardsDistributed(uint256 _amount);

  /**
   * @notice Emitted when stability rewards receiver is updated
   * @param  _oldReceiver Previous stability rewards receiver
   * @param  _newReceiver New stability rewards receiver
   */
  event SetStabilityRewardsReceiver(address indexed _oldReceiver, address indexed _newReceiver);

  /**
   * @notice Emitted when emissions are extended
   * @param  _oldEndTime Previous emission end timestamp
   * @param  _newEndTime New emission end timestamp
   * @param  _additionalKiteAmount Additional KITE added for emissions [wad]
   * @param  _additionalDuration Additional emission duration [seconds]
   * @param  _newBaseRate New total per-second emission rate [wad per second]
   */
  event ExtendEmissions(
    uint256 _oldEndTime,
    uint256 _newEndTime,
    uint256 _additionalKiteAmount,
    uint256 _additionalDuration,
    uint256 _newBaseRate
  );

  // --- Errors ---

  /// @notice Throws when trying to update split too frequently
  error EmissionsController_SplitUpdateTooFrequent();
  /// @notice Throws when trying to claim rewards before emissions start
  error EmissionsController_EmissionsNotStarted();
  /// @notice Throws when trying to claim rewards after emissions end
  error EmissionsController_EmissionsEnded();
  /// @notice Throws when trying to set a null stability receiver
  error EmissionsController_InvalidStabilityReceiver();
  /// @notice Throws when redemption price is zero
  error EmissionsController_InvalidRedemptionPrice();
  /// @notice Throws when caller is not the stability rewards receiver
  error EmissionsController_OnlyStabilityRewardsReceiver();
  /// @notice Throws when emission duration is zero
  error EmissionsController_InvalidEmissionDuration();
  /// @notice Throws when deviation limit is zero
  error EmissionsController_InvalidDeviationLimit();

  // --- Registry ---

  /**
   * @notice Address currently receiving stability-side emissions claims
   * @return _receiver Address receiving stability-side KITE rewards
   */
  function stabilityRewardsReceiver() external view returns (address _receiver);

  // --- Data ---

  /**
   * @notice Returns the accrued KITE rewards for the stability pool side
   * @return _amount Amount of accrued KITE [wad]
   */
  function getAccruedRewardsForStabilityPool() external view returns (uint256 _amount);

  /**
   * @notice Returns the accumulated minting rewards since last distribution checkpoint
   * @return _amount Amount of minting rewards to distribute [wad]
   */
  function getMintingRewardsToDistribute() external view returns (uint256 _amount);

  // --- Methods ---

  /**
   * @notice Updates the reward split ratio based on price deviation
   * @dev    Callable by anyone and rate-limited to once per hour
   */
  function updateRewardSplit() external;

  /**
   * @notice Claims accrued KITE rewards for the stability pool side
   * @dev    Callable only by the configured stability rewards receiver
   * @return _amount Amount of KITE claimed [wad]
   */
  function claimRewardsForStabilityPool() external returns (uint256 _amount);

  /**
   * @notice Marks minting rewards as distributed
   * @param  _amount Amount of minting rewards that were distributed [wad]
   */
  function markMintingRewardsDistributed(uint256 _amount) external;

  /**
   * @notice Emergency withdraws KITE held by the controller
   * @dev    Callable only by authorized accounts
   * @param  _rescueReceiver Address that receives withdrawn KITE
   * @param  _wad Amount of KITE to withdraw [wad]
   */
  function emergencyWithdrawKite(address _rescueReceiver, uint256 _wad) external;

  /**
   * @notice Sets the receiver for stability-side emissions claims
   * @param  _receiver Address that receives stability-side KITE rewards
   */
  function setStabilityRewardsReceiver(address _receiver) external;

  /**
   * @notice Extends the emissions schedule and optionally adds more KITE rewards
   * @param  _additionalKiteAmount Additional KITE to transfer in for emissions [wad]
   * @param  _additionalDuration Additional duration to append to emissions [seconds]
   */
  function extendEmissions(uint256 _additionalKiteAmount, uint256 _additionalDuration) external;
}

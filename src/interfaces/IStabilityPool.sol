// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

/**
 * @title IStabilityPool
 * @notice Interface for the StabilityPool ERC4626 vault with liquidation pipeline + KITE rewards
 */
interface IStabilityPool is IERC4626 {
  // --- Events ---

  /**
   * @notice Emitted when a user claims accrued KITE rewards
   * @param  _user Address that claimed rewards
   * @param  _amount Amount of KITE claimed [wad]
   */
  event ClaimRewards(address indexed _user, uint256 _amount);

  /**
   * @notice Emitted when KITE rewards are claimed from the emissions controller
   * @param  _amount Amount of KITE claimed [wad]
   */
  event ClaimRewardsFromEmissionsController(uint256 _amount);

  /**
   * @notice Emitted when KITE is emergency withdrawn from the pool
   * @param  _rescueReceiver Address that received the withdrawn KITE
   * @param  _wad Amount of KITE withdrawn [wad]
   */
  event EmergencyWithdrawKite(address indexed _rescueReceiver, uint256 _wad);

  /**
   * @notice Emitted when the pool covers debt in a collateral auction and repays it with swapped HAI
   * @param  _auctionId Id of the covered collateral auction
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _collateralAmount Amount of collateral purchased from the auction [wad]
   * @param  _haiSpent Amount of HAI effectively spent to buy collateral [wad]
   * @param  _haiReceived Amount of HAI received after executing strategy steps [wad]
   */
  event CoverAndRepayDebt(
    uint256 indexed _auctionId,
    bytes32 indexed _collateralType,
    uint256 _collateralAmount,
    uint256 _haiSpent,
    uint256 _haiReceived
  );

  /**
   * @notice Emitted when strategy steps are configured for a collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _steps Ordered list of strategy step addresses
   */
  event SetStrategySteps(bytes32 indexed _collateralType, address[] _steps);

  /**
   * @notice Emitted when strategy steps are cleared for a collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   */
  event ClearStrategySteps(bytes32 indexed _collateralType);

  /**
   * @notice Emitted when a strategy step address is added to or removed from the whitelist
   * @param  _step Address of the strategy step
   * @param  _allowed Whether the step is allowed
   */
  event SetStepWhitelist(address indexed _step, bool _allowed);

  /**
   * @notice Emitted when collateral-level slippage fallback is set
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _bps Slippage tolerance in basis points
   */
  event SetCollateralSlippageBps(bytes32 indexed _collateralType, uint16 _bps);

  /**
   * @notice Emitted when step-type-level slippage fallback is set
   * @param  _stepType Bytes32 representation of the step type
   * @param  _bps Slippage tolerance in basis points
   */
  event SetStepTypeSlippageBps(bytes32 indexed _stepType, uint16 _bps);

  /// @notice Emitted when sHAI transfers are enabled
  event TransfersEnabled();

  /**
   * @notice Emitted when KITE accrual is permanently disabled
   * @param  _finalIntegral Final value of reward integral [wad]
   * @param  _remainingKite Unclaimed KITE left in the pool [wad]
   */
  event KiteRewardsDeactivated(uint256 _finalIntegral, uint256 _remainingKite);

  /**
   * @notice Emitted when internal SAFEEngine coin is exited to external HAI
   * @param  _exitedWad Amount exited from internal coin balance [wad]
   */
  event SweepInternalCoin(uint256 _exitedWad);

  // --- Errors ---

  /// @notice Throws when trying to execute/preview with no configured strategy steps
  error StabilityPool_NoStrategySteps();
  /// @notice Throws when a strategy step config is invalid
  error StabilityPool_InvalidStrategyStep();
  /// @notice Throws when a strategy step is not whitelisted
  error StabilityPool_StepNotWhitelisted();
  /// @notice Throws when a cover operation cannot produce enough HAI
  error StabilityPool_NotProfitable();
  /// @notice Throws when the auction collateral type does not match the provided collateral type
  error StabilityPool_CollateralTypeMismatch();
  /// @notice Throws when collateral join cannot be resolved for a collateral type
  error StabilityPool_InvalidCollateralJoin();
  /// @notice Throws when the provided auction house is not the configured canonical auction house for the collateral
  error StabilityPool_InvalidAuctionHouse();
  /// @notice Throws when slippage basis points exceed the maximum value
  error StabilityPool_InvalidSlippageBps();
  /// @notice Throws when trying to transfer shares while transfers are disabled
  error StabilityPool_TransfersDisabled();
  /// @notice Throws when trying to enable transfers after they were already enabled
  error StabilityPool_TransfersAlreadyEnabled();
  /// @notice Throws when the emissions controller rewards receiver configuration is invalid
  error StabilityPool_InvalidRewardsReceiver();
  /// @notice Throws when claiming emissions-side rewards after reward accrual has been disabled
  error StabilityPool_RewardsInactive();
  /// @notice Throws when a strategy step delegatecall fails without bubbling a revert reason
  error StabilityPool_DelegatecallFailed();
  /// @notice Throws when trying to sweep internal coin before the cooldown elapsed
  error StabilityPool_InternalCoinSweepTooFrequent();

  // --- Structs ---

  struct StepConfig {
    // Address of the strategy step implementation
    address step;
    // ABI-encoded step configuration data
    bytes data;
    // Explicit slippage override in basis points (0 means use fallback precedence)
    uint16 slippageBps;
  }

  // --- Registry ---

  /// @notice Address of the SystemCoin token contract used as the vault asset
  function systemCoin() external view returns (ISystemCoin _systemCoin);

  /// @notice Address of the KITE token contract
  function protocolToken() external view returns (IProtocolToken _protocolToken);

  /// @notice Address of the OracleRelayer contract
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  /// @notice Address of the EmissionsController contract
  function emissionsController() external view returns (IEmissionsController _emissionsController);

  /// @notice Address of the CoinJoin adapter used for SAFEEngine internal coin transitions
  function coinJoin() external view returns (ICoinJoin _coinJoin);

  /// @notice Address of the CollateralJoinFactory used to resolve collateral joins by collateral type
  function collateralJoinFactory() external view returns (ICollateralJoinFactory _collateralJoinFactory);

  /// @notice Address of the CollateralAuctionHouseFactory used to resolve canonical auction houses by collateral type
  function collateralAuctionHouseFactory() external view returns (ICollateralAuctionHouseFactory _factory);

  // --- Data ---

  /// @notice Running KITE rewards-per-share accumulator [wad]
  function kiteRewardIntegral() external view returns (uint256 _kiteRewardIntegral);

  /// @notice Remaining KITE tracked by the pool for claim accounting [wad]
  function kiteRewardRemaining() external view returns (uint256 _kiteRewardRemaining);

  /**
   * @notice User reward debt used in per-share accounting
   * @param  _user Address of the user
   * @return _rewardDebt Reward debt for the user [wad]
   */
  function rewardDebt(address _user) external view returns (uint256 _rewardDebt);

  /**
   * @notice User rewards that are currently claimable
   * @param  _user Address of the user
   * @return _claimable Amount of claimable KITE [wad]
   */
  function claimable(address _user) external view returns (uint256 _claimable);

  /// @notice Whether sHAI transfers are enabled
  function transfersEnabled() external view returns (bool _transfersEnabled);

  /// @notice Whether KITE reward accrual is active
  function kiteRewardsActive() external view returns (bool _kiteRewardsActive);

  /// @notice Last timestamp when internal coin was swept to external HAI
  function lastInternalCoinSweepTime() external view returns (uint256 _lastInternalCoinSweepTime);

  /**
   * @notice Whether a strategy step address is whitelisted
   * @param  _step Address of the strategy step
   * @return _isWhitelisted Whether the step is allowed
   */
  function isWhitelistedStep(address _step) external view returns (bool _isWhitelisted);

  /**
   * @notice Collateral-level slippage fallback for strategy execution
   * @param  _collateralType Bytes32 representation of the collateral type
   * @return _bps Slippage tolerance in basis points
   */
  function collateralSlippageBps(bytes32 _collateralType) external view returns (uint16 _bps);

  /**
   * @notice Step-type-level slippage fallback for strategy execution
   * @param  _stepType Bytes32 representation of the strategy step type
   * @return _bps Slippage tolerance in basis points
   */
  function stepTypeSlippageBps(bytes32 _stepType) external view returns (uint16 _bps);

  /**
   * @notice Returns a strategy step config for a collateral type by index
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _idx Index of the strategy step in the configured pipeline
   * @return _stepConfig Strategy step configuration
   */
  function strategySteps(bytes32 _collateralType, uint256 _idx) external view returns (StepConfig memory _stepConfig);

  /**
   * @notice Returns the number of configured strategy steps for a collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   * @return _length Number of configured steps
   */
  function strategyStepsLength(bytes32 _collateralType) external view returns (uint256 _length);

  // --- Methods ---

  /**
   * @notice Claims KITE rewards from the emissions controller into this pool
   * @return _amount Amount of claimed KITE [wad]
   */
  function claimRewardsFromEmissionsController() external returns (uint256 _amount);

  /**
   * @notice Claims caller's accrued KITE rewards
   * @return _amount Amount of claimed KITE [wad]
   */
  function claimRewards() external returns (uint256 _amount);

  /**
   * @notice Emergency withdraws KITE held by the pool
   * @dev    Callable only by authorized accounts
   * @param  _rescueReceiver Address that receives withdrawn KITE
   * @param  _wad Amount of KITE to withdraw [wad]
   */
  function emergencyWithdrawKite(address _rescueReceiver, uint256 _wad) external;

  /**
   * @notice Returns pending rewards for a user, including not-yet-checkpointed accrual
   * @param  _user Address of the user
   * @return _amount Amount of pending KITE [wad]
   */
  function pendingRewards(address _user) external view returns (uint256 _amount);

  /// @notice Enables one-way transferability for sHAI and deactivates KITE accrual
  function enableTransfers() external;

  /**
   * @notice Exits available SAFEEngine internal coin to external HAI
   * @dev    Callable by anyone and rate-limited to once per hour
   * @return _exitedWad Amount of internal coin exited [wad]
   */
  function sweepInternalCoin() external returns (uint256 _exitedWad);

  /**
   * @notice Sets the ordered strategy step pipeline for a collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _steps Ordered list of strategy step configs
   */
  function setStrategySteps(bytes32 _collateralType, StepConfig[] calldata _steps) external;

  /**
   * @notice Clears the strategy step pipeline for a collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   */
  function clearStrategySteps(bytes32 _collateralType) external;

  /**
   * @notice Updates whitelist status for a strategy step implementation
   * @param  _step Address of the strategy step implementation
   * @param  _allowed Whether the step is allowed
   */
  function setStepWhitelist(address _step, bool _allowed) external;

  /**
   * @notice Sets collateral-level slippage fallback used during strategy preview/execution
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _bps Slippage tolerance in basis points
   */
  function setCollateralSlippageBps(bytes32 _collateralType, uint16 _bps) external;

  /**
   * @notice Sets step-type-level slippage fallback used during strategy preview/execution
   * @param  _stepType Bytes32 representation of the strategy step type
   * @param  _bps Slippage tolerance in basis points
   */
  function setStepTypeSlippageBps(bytes32 _stepType, uint16 _bps) external;

  /**
   * @notice Previews the expected HAI output from swapping collateral through configured strategy steps
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _collateralAmount Amount of collateral to route through the strategy [wei]
   * @return _expectedHai Expected HAI output [wad]
   */
  function previewSwapToHai(
    bytes32 _collateralType,
    uint256 _collateralAmount
  ) external view returns (uint256 _expectedHai);

  /**
   * @notice Covers collateral auction debt and repays it by buying collateral and swapping it to HAI
   * @param  _auctionHouse Address of the collateral auction house
   * @param  _auctionId Id of the collateral auction
   * @param  _bidAmount Amount of HAI to bid in the auction [wad]
   * @param  _collateralType Bytes32 representation of the collateral type
   * @return _profit Net profit in HAI (positive) or loss (negative) [wad]
   */
  function coverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) external returns (int256 _profit);
}

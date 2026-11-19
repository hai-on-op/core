// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';

interface IAutoLiner is IAuthorizable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when the live debt ceiling is updated in the SAFEEngine
   * @param _cType Bytes32 representation of the collateral type
   * @param _oldDebtCeiling Previous live debt ceiling [rad]
   * @param _newDebtCeiling New live debt ceiling [rad]
   */
  event UpdateCeiling(bytes32 indexed _cType, uint256 _oldDebtCeiling, uint256 _newDebtCeiling);
  // --- Errors ---

  /// @notice Throws when trying to update a ceiling before the cooldown has passed
  error AutoLiner_Cooldown();
  /// @notice Throws when the collateral type has not been initialized in AutoLiner
  error AutoLiner_CollateralTypeNotInitialized();
  /// @notice Throws when the collateral type is initialized but inactive in AutoLiner
  error AutoLiner_CollateralTypeNotActive();
  /// @notice Throws when the collateral type is not registered in the SAFEEngine
  error AutoLiner_CollateralTypeNotRegistered();
  /// @notice Throws when trying to initialize a collateral type with a zero ceiling cap
  error AutoLiner_NullCeilingCap();
  /// @notice Throws when the collateral headroom is zero
  error AutoLiner_NullGap();
  /// @notice Throws when the effective minimum debt ceiling is zero
  error AutoLiner_NullMinDebt();

  // --- Structs ---

  struct AutoLinerParams {
    // Minimum delay between any two live ceiling changes
    uint256 /* seconds */ cooldown;
  }

  struct AutoLinerCollateralParams {
    // Maximum live debt ceiling that can be restored for the collateral
    uint256 /* RAD */ ceilingCap;
    // Collateral specific minimum live debt ceiling floor
    uint256 /* RAD */ minDebt;
    // Collateral specific headroom to leave above the current debt
    uint256 /* RAD */ gap;
  }

  struct AutoLinerCollateralData {
    // Timestamp of the last live ceiling update
    uint256 /* seconds */ lastUpdateTime;
  }

  // --- Registry ---

  /**
   * @notice SAFEEngine where live collateral debt ceilings are stored
   */
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _autoLinerParams The active AutoLinerParams
   */
  function params() external view returns (AutoLinerParams memory _autoLinerParams);

  /**
   * @notice Getter for the collateral parameters struct
   * @param _cType Bytes32 representation of the collateral type
   * @return _autoLinerCParams The active AutoLinerCollateralParams
   */
  function cParams(bytes32 _cType) external view returns (AutoLinerCollateralParams memory _autoLinerCParams);

  // --- Data ---

  /**
   * @notice Getter for the collateral state struct
   * @param _cType Bytes32 representation of the collateral type
   * @return _autoLinerCData The active AutoLinerCollateralData
   */
  function cData(bytes32 _cType) external view returns (AutoLinerCollateralData memory _autoLinerCData);

  // --- Views ---

  /**
   * @notice Compute the next live debt ceiling for a collateral type
   * @param _cType Bytes32 representation of the collateral type
   * @return _nextDebtCeiling The next live debt ceiling [rad]
   */
  function getNextDebtCeiling(bytes32 _cType) external view returns (uint256 _nextDebtCeiling);

  // --- Methods ---

  /**
   * @notice Update the live debt ceiling for a collateral type in the SAFEEngine
   * @param _cType Bytes32 representation of the collateral type
   * @return _nextDebtCeiling The live debt ceiling that should apply after the call [rad]
   */
  function updateCeiling(bytes32 _cType) external returns (uint256 _nextDebtCeiling);
}

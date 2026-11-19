// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAutoLiner} from '@interfaces/utils/IAutoLiner.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Math} from '@libraries/Math.sol';

/**
 * @title  AutoLiner
 * @notice Maintains a live collateral debt ceiling in the SAFEEngine with a configurable minting headroom
 */
contract AutoLiner is Authorizable, Modifiable, ModifiablePerCollateral, IAutoLiner {
  using Assertions for uint256;
  using Assertions for address;
  using Encoding for bytes;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Registry ---

  ISAFEEngine public safeEngine;

  // --- Params ---

  // solhint-disable-next-line private-vars-leading-underscore
  AutoLinerParams public _params;

  /// @inheritdoc IAutoLiner
  function params() external view returns (AutoLinerParams memory _autoLinerParams) {
    return _params;
  }

  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => AutoLinerCollateralParams) public _cParams;

  /// @inheritdoc IAutoLiner
  function cParams(bytes32 _cType) external view returns (AutoLinerCollateralParams memory _autoLinerCParams) {
    return _cParams[_cType];
  }

  // --- Data ---

  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => AutoLinerCollateralData) public _cData;

  /// @inheritdoc IAutoLiner
  function cData(bytes32 _cType) external view returns (AutoLinerCollateralData memory _autoLinerCData) {
    return _cData[_cType];
  }

  // --- Init ---

  /**
   * @param _safeEngine Address of the SAFEEngine contract
   * @param _autoLinerParams Initial valid AutoLiner parameters
   */
  constructor(address _safeEngine, AutoLinerParams memory _autoLinerParams) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertHasCode());
    _params = _autoLinerParams;
  }

  // --- Views ---

  /// @inheritdoc IAutoLiner
  function getNextDebtCeiling(bytes32 _cType) external view returns (uint256 _nextDebtCeiling) {
    _ensureAutoLinerCollateral(_cType);
    _getLiveDebtCeiling(_cType);
    return _getNextDebtCeiling(_cType);
  }

  // --- Methods ---

  /// @inheritdoc IAutoLiner
  function updateCeiling(bytes32 _cType) external returns (uint256 _nextDebtCeiling) {
    _ensureAutoLinerCollateral(_cType);
    uint256 _currentDebtCeiling = _getLiveDebtCeiling(_cType);

    _nextDebtCeiling = _getNextDebtCeiling(_cType);

    if (_nextDebtCeiling == _currentDebtCeiling) return _nextDebtCeiling;
    if (!_cooldownPassed(_cType)) revert AutoLiner_Cooldown();

    _cData[_cType].lastUpdateTime = block.timestamp;
    safeEngine.modifyParameters(_cType, 'debtCeiling', abi.encode(_nextDebtCeiling));

    emit UpdateCeiling(_cType, _currentDebtCeiling, _nextDebtCeiling);
  }

  // --- Administration ---

  /// @inheritdoc ModifiablePerCollateral
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override {
    AutoLinerCollateralParams memory _decodedParams = abi.decode(_collateralParams, (AutoLinerCollateralParams));
    if (_decodedParams.ceilingCap == 0) revert AutoLiner_NullCeilingCap();
    _cParams[_cType] = _decodedParams;
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'cooldown') _params.cooldown = _uint256;
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    if (_param == 'ceilingCap') _cParams[_cType].ceilingCap = _uint256;
    else if (_param == 'minDebt') _cParams[_cType].minDebt = _uint256;
    else if (_param == 'gap') _cParams[_cType].gap = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(safeEngine).assertHasCode();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _validateCParameters(bytes32 _cType) internal view override {
    if (_cParams[_cType].minDebt == 0) revert AutoLiner_NullMinDebt();
    if (_cParams[_cType].gap == 0) revert AutoLiner_NullGap();
  }

  // --- Internal ---

  function _getNextDebtCeiling(bytes32 _cType) internal view returns (uint256 _nextDebtCeiling) {
    AutoLinerCollateralParams memory __cParams = _cParams[_cType];
    uint256 _ceilingCap = __cParams.ceilingCap;
    uint256 _minDebt = __cParams.minDebt;
    uint256 _gap = __cParams.gap;

    if (_gap == type(uint256).max) return _ceilingCap;

    uint256 _currentDebt = _getCurrentDebt(_cType);
    if (_currentDebt >= _ceilingCap) return _ceilingCap;

    uint256 _remainingHeadroom = _ceilingCap - _currentDebt;
    uint256 _debtPlusGap = _currentDebt + Math.min(_gap, _remainingHeadroom);
    return Math.min(_ceilingCap, Math.max(_minDebt, _debtPlusGap));
  }

  function _getCurrentDebt(bytes32 _cType) internal view returns (uint256 _currentDebt) {
    ISAFEEngine.SAFEEngineCollateralData memory _safeEngineCData = safeEngine.cData(_cType);
    return _safeEngineCData.debtAmount * _safeEngineCData.accumulatedRate;
  }

  function _getLiveDebtCeiling(bytes32 _cType) internal view returns (uint256 _liveDebtCeiling) {
    _liveDebtCeiling = safeEngine.cParams(_cType).debtCeiling;
    if (_liveDebtCeiling == 0) revert AutoLiner_CollateralTypeNotRegistered();
    return _liveDebtCeiling;
  }

  function _cooldownPassed(bytes32 _cType) internal view returns (bool _passed) {
    uint256 _lastUpdateTime = _cData[_cType].lastUpdateTime;
    return _lastUpdateTime == 0 || block.timestamp - _lastUpdateTime >= _params.cooldown;
  }

  function _ensureAutoLinerCollateral(bytes32 _cType) internal view {
    if (!_collateralList.contains(_cType)) revert AutoLiner_CollateralTypeNotInitialized();
    if (_cParams[_cType].ceilingCap == 0) revert AutoLiner_CollateralTypeNotActive();
  }
}

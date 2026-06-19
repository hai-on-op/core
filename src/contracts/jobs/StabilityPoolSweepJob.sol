// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityPoolSweepJob} from '@interfaces/jobs/IStabilityPoolSweepJob.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  StabilityPoolSweepJob
 * @notice This contract contains a rewarded method to run StabilityPool sweepInternalCoin
 */
contract StabilityPoolSweepJob is Authorizable, Modifiable, Job, IStabilityPoolSweepJob {
  using Encoding for bytes;
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc IStabilityPoolSweepJob
  bool public shouldWork;

  // --- Registry ---

  /// @inheritdoc IStabilityPoolSweepJob
  IStabilityPool public stabilityPool;

  // --- Init ---

  /**
   * @param  _stabilityPool Address of the StabilityPool contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(
    address _stabilityPool,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) validParams {
    stabilityPool = IStabilityPool(_stabilityPool);

    shouldWork = true;
  }

  // --- Job ---

  /// @inheritdoc IStabilityPoolSweepJob
  function workSweepInternalCoin() external reward returns (uint256 _exitedWad) {
    if (!shouldWork) revert NotWorkable();

    _exitedWad = stabilityPool.sweepInternalCoin();
    if (_exitedWad == 0) revert StabilityPoolSweepJob_NullSweepAmount();
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override(Job, Modifiable) {
    if (_param == 'stabilityPool') stabilityPool = IStabilityPool(_data.toAddress());
    else if (_param == 'shouldWork') shouldWork = _data.toBool();
    else Job._modifyParameters(_param, _data);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override(Job, Modifiable) {
    address(stabilityPool).assertHasCode();
    Job._validateParameters();
  }
}

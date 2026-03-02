// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityPoolCoverJob} from '@interfaces/jobs/IStabilityPoolCoverJob.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  StabilityPoolCoverJob
 * @notice This contract contains a rewarded method to run StabilityPool coverAndRepayDebt
 */
contract StabilityPoolCoverJob is Authorizable, Modifiable, Job, IStabilityPoolCoverJob {
  using Encoding for bytes;
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc IStabilityPoolCoverJob
  bool public shouldWork;

  // --- Registry ---

  /// @inheritdoc IStabilityPoolCoverJob
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

  /// @inheritdoc IStabilityPoolCoverJob
  function workCoverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) external reward returns (int256 _profit) {
    if (!shouldWork) revert NotWorkable();

    _profit = stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType);
    if (_profit <= 0) revert StabilityPoolCoverJob_NonPositiveProfit();
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

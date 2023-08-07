// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingJob} from '@interfaces/jobs/IAccountingJob.sol';
import {ILiquidationJob} from '@interfaces/jobs/ILiquidationJob.sol';
import {IOracleJob} from '@interfaces/jobs/IOracleJob.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title RewardedActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract RewardedActions is CommonActions {
  // --- AccountingJob ---

  function startDebtAuction(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workAuctionDebt();
    _exitReward(_accountingJob, _coinJoin);
  }

  function startSurplusAuction(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workAuctionSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  function popDebtFromQueue(address _accountingJob, address _coinJoin, uint256 _debtTimestamp) external delegateCall {
    IAccountingJob(_accountingJob).workPopDebtFromQueue(_debtTimestamp);
    _exitReward(_accountingJob, _coinJoin);
  }

  function transferExtraSurplus(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workTransferExtraSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  // --- LiquidationJob ---

  function liquidateSAFE(
    address _liquidationJob,
    address _coinJoin,
    bytes32 _cType,
    address _safe
  ) external delegateCall {
    ILiquidationJob(_liquidationJob).workLiquidation(_cType, _safe);
    _exitReward(_liquidationJob, _coinJoin);
  }

  // --- OracleJob ---

  function updateCollateralPrice(address _oracleJob, address _coinJoin, bytes32 _cType) external delegateCall {
    IOracleJob(_oracleJob).workUpdateCollateralPrice(_cType);
    _exitReward(_oracleJob, _coinJoin);
  }

  function updateRedemptionRate(address _oracleJob, address _coinJoin) external delegateCall {
    IOracleJob(_oracleJob).workUpdateRate();
    _exitReward(_oracleJob, _coinJoin);
  }

  function _exitReward(address _job, address _coinJoin) internal {
    uint256 _rewardAmount = IJob(_job).rewardAmount();
    _exitSystemCoins(_coinJoin, _rewardAmount);
  }
}

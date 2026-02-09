// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICurveStableSwapNGRelayerChild} from '@interfaces/factories/ICurveStableSwapNGRelayerChild.sol';

import {CurveStableSwapNGRelayer} from '@contracts/oracles/CurveStableSwapNGRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  CurveStableSwapNGRelayerChild
 * @notice This contract inherits all the functionality of CurveStableSwapNGRelayer to be factory deployed
 */
contract CurveStableSwapNGRelayerChild is CurveStableSwapNGRelayer, FactoryChild, ICurveStableSwapNGRelayerChild {
  // --- Init ---

  /**
   * @param  _pool Address of the CurveStableSwapNG pool
   * @param  _baseIndex Index of the base token in the pool (0 = coin0)
   * @param  _quoteIndex Index of the quote token in the pool (0 = coin0)
   */
  constructor(
    address _pool,
    uint256 _baseIndex,
    uint256 _quoteIndex
  ) CurveStableSwapNGRelayer(_pool, _baseIndex, _quoteIndex) {}
}

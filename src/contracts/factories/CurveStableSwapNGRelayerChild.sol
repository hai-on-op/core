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
   * @param  _oracleIndex Index used for Curve's price_oracle(i) (prices coin i+1 vs coin0)
   * @param  _inverted Whether to invert the oracle output (quote/base instead of base/quote)
   */
  constructor(
    address _pool,
    uint256 _oracleIndex,
    bool _inverted
  ) CurveStableSwapNGRelayer(_pool, _oracleIndex, _inverted) {}
}

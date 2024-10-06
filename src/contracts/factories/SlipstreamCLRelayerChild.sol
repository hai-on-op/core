// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IUniV3RelayerChild} from '@interfaces/factories/IUniV3RelayerChild.sol';

import {SlipstreamCLRelayer} from '@contracts/oracles/SlipstreamCLRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  SlipstreamCLRelayerChild
 * @notice This contract inherits all the functionality of SlipstreamCLRelayer to be factory deployed
 */
contract SlipstreamCLRelayerChild is SlipstreamCLRelayer, FactoryChild, IUniV3RelayerChild {
  // --- Init ---

  /**
   * @param  _baseToken Address of the base token to be quoted
   * @param  _quoteToken Address of the quote reference token
   * @param  _feeTier Fee tier used to identify the UniV3 pool
   * @param  _quotePeriod Length of the period used to calculate the TWAP quote
   */
  constructor(
    address _uniV3Factory,
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) SlipstreamCLRelayer(_uniV3Factory, _baseToken, _quoteToken, _feeTier, _quotePeriod) {}
}

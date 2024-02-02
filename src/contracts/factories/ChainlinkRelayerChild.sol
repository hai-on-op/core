// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayerChild} from '@interfaces/factories/IChainlinkRelayerChild.sol';
import {IChainlinkRelayerFactory} from '@interfaces/factories/IChainlinkRelayerFactory.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayer, IChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  ChainlinkRelayerChild
 * @notice This contract inherits all the functionality of ChainlinkRelayer to be factory deployed
 */
contract ChainlinkRelayerChild is ChainlinkRelayer, FactoryChild, IChainlinkRelayerChild {
  // --- Init ---

  /**
   * @param  _priceFeed The address of the price feed to relay
   * @param  __sequencerUptimeFeed The address of the sequencer uptime feed to relay
   * @param  _staleThreshold The threshold in seconds to consider the aggregator stale
   */
  constructor(
    address _priceFeed,
    address __sequencerUptimeFeed,
    uint256 _staleThreshold
  ) ChainlinkRelayer(_priceFeed, __sequencerUptimeFeed, _staleThreshold) {}

  // --- Overrides ---

  function sequencerUptimeFeed()
    public
    view
    override(ChainlinkRelayer, IChainlinkRelayer)
    returns (IChainlinkOracle __sequencerUptimeFeed)
  {
    return IChainlinkRelayerFactory(factory).sequencerUptimeFeed();
  }

  /**
   * @dev    Modifying sequencerUptimeFeed's address results in a no-operation (is read from factory)
   * @param  __sequencerUptimeFeed Ignored parameter (read from factory)
   * @inheritdoc ChainlinkRelayer
   */
  function _setSequencerUptimeFeed(address __sequencerUptimeFeed) internal override {}
}

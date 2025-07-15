// SPDX-License-Identifier: AGLP-3.0
pragma solidity ^0.8.19;

interface IChainLinkOracle {
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function decimals() external view returns (uint8);
}

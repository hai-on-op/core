// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPessimisticVeloLpOracle {
  function getCurrentPoolPrice(bool _usePessimisticPricing) external view returns (uint256 _price);
}

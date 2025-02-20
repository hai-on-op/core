// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPessimisticVeloLpOracle {
  function getCurrentPrice(address _pool) external view returns (uint256);
}

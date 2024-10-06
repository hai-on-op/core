// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface ISlipstreamCLFactory {
  function getPool(address _tokenA, address _tokenB, int24 _tickSpacing) external view returns (address _pool);
}

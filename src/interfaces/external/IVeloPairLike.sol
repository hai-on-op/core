// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IVeloPairLike {
  function token0() external view returns (address _token0);
  function token1() external view returns (address _token1);
  function totalSupply() external view returns (uint256 _totalSupply);
  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _timestampLast);
}

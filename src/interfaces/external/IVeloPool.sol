// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVeloPool {
  /**
   * @notice Returns the value of tokens in existence.
   */
  function totalSupply() external view returns (uint256 _totalSupply);
  /**
   * @notice Amount of token0 in pool
   */
  function reserve0() external view returns (uint256 _reserve0);
  /**
   * @notice Amount of token1 in pool
   */
  function reserve1() external view returns (uint256 _reserve1);
  function symbol() external view returns (string memory _symbol);
}

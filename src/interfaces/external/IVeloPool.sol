// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IVeloPool is IERC20 {
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

  function quote(address tokenIn, uint256 amountIn, uint256 granularity) external view returns (uint256);

  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);

  function metadata()
    external
    view
    returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1);

  function decimals() external view returns (uint8);

  function stable() external view returns (bool);

  function name() external view returns (string memory);
}

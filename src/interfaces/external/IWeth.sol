// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

interface IWeth is IERC20 {
  function deposit() external payable;
  function withdraw(uint256 _amount) external;
}

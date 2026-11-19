// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IYearnVaultWithdraw {
  function pricePerShare() external view returns (uint256 _pricePerShare);
  function withdraw(uint256 _shares) external returns (uint256 _withdrawn);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IBeefyVaultWithdraw {
  function getPricePerFullShare() external view returns (uint256 _pricePerFullShare);
  function withdraw(uint256 _shares) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IYearnVault {
  function pricePerShare() external view returns (uint256 _pricePerShare);
  function symbol() external view returns (string memory _symbol);
}

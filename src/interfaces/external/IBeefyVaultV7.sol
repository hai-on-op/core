// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IBeefyVaultV7 {
  function getPricePerFullShare() external view returns (uint256 _pricePerFullShare);
  function symbol() external view returns (string memory _symbol);
}

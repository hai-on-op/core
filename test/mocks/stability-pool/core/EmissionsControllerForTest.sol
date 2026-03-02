// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

contract MockOracleRelayerForTest {
  uint256 public redemptionPrice = 1e27;
  uint256 public marketPrice = 1e27;

  function calcRedemptionPrice() external view returns (uint256 _redemptionPrice) {
    return redemptionPrice;
  }

  function setPrices(uint256 _redemptionPrice, uint256 _marketPrice) external {
    redemptionPrice = _redemptionPrice;
    marketPrice = _marketPrice;
  }
}

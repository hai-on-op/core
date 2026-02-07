// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICurveStableSwapNG {
  function price_oracle(uint256 i) external view returns (uint256 _price);
  function coins(uint256 i) external view returns (address _coin);
}

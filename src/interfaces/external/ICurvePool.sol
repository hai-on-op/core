// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface ICurvePool {
  // solhint-disable-next-line func-name-mixedcase
  function get_dy(int128 _i, int128 _j, uint256 _dx) external view returns (uint256 _dy);
  function exchange(int128 _i, int128 _j, uint256 _dx, uint256 _minDy) external returns (uint256 _dy);
}

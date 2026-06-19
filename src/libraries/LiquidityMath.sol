// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

library LiquidityMath {
  error LiquidityMath_LiquiditySub();
  error LiquidityMath_LiquidityAdd();

  function addDelta(uint128 _x, int128 _y) internal pure returns (uint128 _z) {
    if (_y < 0) {
      _z = _x - uint128(uint128(-_y));
      if (_z >= _x) revert LiquidityMath_LiquiditySub();
    } else {
      _z = _x + uint128(uint128(_y));
      if (_z < _x) revert LiquidityMath_LiquidityAdd();
    }
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IVeloCLPoolLike {
  function token0() external view returns (address _token0);
  function token1() external view returns (address _token1);
  function fee() external view returns (uint24 _feePips);
  function tickSpacing() external view returns (int24 _tickSpacing);

  function slot0()
    external
    view
    returns (
      uint160 _sqrtPriceX96,
      int24 _tick,
      uint16 _observationIndex,
      uint16 _observationCardinality,
      uint16 _observationCardinalityNext,
      bool _unlocked
    );

  function liquidity() external view returns (uint128 _liquidity);
  function ticks(int24 _tick)
    external
    view
    returns (
      uint128 _liquidityGross,
      int128 _liquidityNet,
      int128 _stakedLiquidityNet,
      uint256 _feeGrowthOutside0X128,
      uint256 _feeGrowthOutside1X128,
      uint256 _rewardGrowthOutsideX128,
      int56 _tickCumulativeOutside,
      uint160 _secondsPerLiquidityOutsideX128,
      uint32 _secondsOutside,
      bool _initialized
    );

  function tickBitmap(int16 _wordPosition) external view returns (uint256 _bitmap);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AbstractVeloVaultRelayer} from '@contracts/oracles/AbstractVeloVaultRelayer.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

contract PessimisticVeloLpOracleForTest is IPessimisticVeloLpOracle {
  uint256 internal _price;

  constructor(uint256 __price) {
    _price = __price;
  }

  function getCurrentPoolPrice(bool) external view returns (uint256 _currentPoolPrice) {
    return _price;
  }
}

contract VeloVaultRelayerForTest is AbstractVeloVaultRelayer {
  uint256 internal _pricePerFullShare;

  constructor(
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle,
    uint256 __pricePerFullShare
  ) AbstractVeloVaultRelayer(_veloPool, _veloLpOracle, 'VeloVaultRelayerForTest') {
    _pricePerFullShare = __pricePerFullShare;
    _initializePricePerFullShare();
  }

  function setPricePerFullShare(uint256 __pricePerFullShare) external {
    _pricePerFullShare = __pricePerFullShare;
  }

  function _getPricePerFullShare() internal view override returns (uint256 __pricePerFullShare) {
    return _pricePerFullShare;
  }
}

contract Unit_AbstractVeloVaultRelayer is HaiTest {
  IVeloPool internal veloPool = IVeloPool(mockContract('VeloPool'));
  PessimisticVeloLpOracleForTest internal veloLpOracle;
  VeloVaultRelayerForTest internal relayer;

  function setUp() public {
    veloLpOracle = new PessimisticVeloLpOracleForTest(2e8);
    relayer = new VeloVaultRelayerForTest(veloPool, veloLpOracle, 1e18);
  }

  function test_Constructor_InitializesAcceptedPricePerFullShare() public view {
    assertEq(relayer.acceptedPricePerFullShare(), 1e18);
    assertEq(relayer.lastPricePerFullShareUpdateTime(), block.timestamp);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertTrue(valid);
    assertEq(result, 2e18);
  }

  function test_UpdatePricePerFullShare_AcceptsDecreaseImmediately() public {
    relayer.setPricePerFullShare(0.5e18);

    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 0.5e18);
    assertEq(relayer.lastPricePerFullShareUpdateTime(), block.timestamp);

    (uint256 result,) = relayer.getResultWithValidity();
    assertEq(result, 1e18);
  }

  function test_UpdatePricePerFullShare_DoesNotAcceptIncreaseBeforeDelay() public {
    relayer.setPricePerFullShare(10e18);

    bool updated = relayer.updatePricePerFullShare();

    assertFalse(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1e18);

    (uint256 result,) = relayer.getResultWithValidity();
    assertEq(result, 2e18);
  }

  function test_UpdatePricePerFullShare_CapsIncreaseAfterDelay() public {
    relayer.setPricePerFullShare(10e18);
    vm.warp(block.timestamp + relayer.PRICE_PER_FULL_SHARE_UPDATE_DELAY());

    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1.01e18);

    (uint256 result,) = relayer.getResultWithValidity();
    assertEq(result, 2.02e18);
  }

  function test_UpdatePricePerFullShare_AcceptsIncreaseBelowCapAfterDelay() public {
    relayer.setPricePerFullShare(1.005e18);
    vm.warp(block.timestamp + relayer.PRICE_PER_FULL_SHARE_UPDATE_DELAY());

    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1.005e18);
  }
}

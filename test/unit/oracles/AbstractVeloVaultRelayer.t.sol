// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AbstractVeloVaultRelayer} from '@contracts/oracles/AbstractVeloVaultRelayer.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IAbstractVeloVaultRelayer} from '@interfaces/oracles/IAbstractVeloVaultRelayer.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

contract PessimisticVeloLpOracleForTest is IPessimisticVeloLpOracle {
  error PriceUnavailable();

  uint256 internal _price;
  bool internal _revertOnRead;

  constructor(uint256 __price) {
    _price = __price;
  }

  function setPrice(uint256 __price) external {
    _price = __price;
  }

  function setRevertOnRead(bool __revertOnRead) external {
    _revertOnRead = __revertOnRead;
  }

  function getCurrentPoolPrice(bool) external view returns (uint256 _currentPoolPrice) {
    if (_revertOnRead) {
      revert PriceUnavailable();
    }

    return _price;
  }
}

contract VeloVaultRelayerForTest is AbstractVeloVaultRelayer {
  error PricePerFullShareUnavailable();

  uint256 internal _pricePerFullShare;
  bool internal _revertOnPricePerFullShare;

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

  function setRevertOnPricePerFullShare(bool __revertOnPricePerFullShare) external {
    _revertOnPricePerFullShare = __revertOnPricePerFullShare;
  }

  function _getPricePerFullShare() internal view override returns (uint256 __pricePerFullShare) {
    if (_revertOnPricePerFullShare) {
      revert PricePerFullShareUnavailable();
    }
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

  function test_GetResultWithValidity_ReturnsInvalidWhenLpOracleReverts() public {
    veloLpOracle.setRevertOnRead(true);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertEq(result, 0);
    assertFalse(valid);
  }

  function test_Read_RevertsWhenLpOracleReverts() public {
    veloLpOracle.setRevertOnRead(true);

    vm.expectRevert(PessimisticVeloLpOracleForTest.PriceUnavailable.selector);
    relayer.read();
  }

  function test_GetResultWithValidity_ReturnsInvalidWhenLpOraclePriceIsZero() public {
    veloLpOracle.setPrice(0);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertEq(result, 0);
    assertFalse(valid);
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

  function test_UpdatePricePerFullShare_AcceptsZeroAsInvalidatingDecrease() public {
    relayer.setPricePerFullShare(0);

    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 0);
    assertEq(relayer.lastPricePerFullShareUpdateTime(), block.timestamp);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertEq(result, 0);
    assertFalse(valid);

    vm.expectRevert(IAbstractVeloVaultRelayer.AbstractVeloVaultRelayer_ZeroPrice.selector);
    relayer.read();
  }

  function test_UpdatePricePerFullShare_RecoversFromAcceptedZeroPricePerFullShare() public {
    relayer.setPricePerFullShare(0);
    relayer.updatePricePerFullShare();

    relayer.setPricePerFullShare(1e18);

    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1e18);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertEq(result, 2e18);
    assertTrue(valid);
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

  // --- H-04: read path fails closed to the lower of cached and live share value ---

  function test_GetResultWithValidity_ReflectsVaultLossWithoutUpdate() public {
    // Vault loses half its value; nobody calls updatePricePerFullShare().
    relayer.setPricePerFullShare(0.5e18);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    // min(cached 1e18, live 0.5e18) * 2e8 / 1e8 = 1e18, not the stale 2e18.
    assertTrue(valid);
    assertEq(result, 1e18);
  }

  function test_Read_ReflectsVaultLossWithoutUpdate() public {
    relayer.setPricePerFullShare(0.5e18);

    assertEq(relayer.read(), 1e18);
  }

  function test_GetResultWithValidity_KeepsCachedValueWhenLiveIsHigher() public {
    // A live gain must not raise the reported price (upward cap preserved; M-12 defense intact).
    relayer.setPricePerFullShare(10e18);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    assertTrue(valid);
    assertEq(result, 2e18);
  }

  function test_GetResultWithValidity_FailsClosedWhenLiveReadReverts() public {
    relayer.setRevertOnPricePerFullShare(true);

    (uint256 result, bool valid) = relayer.getResultWithValidity();

    // Fail closed; do NOT fall back to the cached value (which would report 2e18).
    assertEq(result, 0);
    assertFalse(valid);
  }

  function test_Read_RevertsWhenLiveReadReverts() public {
    relayer.setRevertOnPricePerFullShare(true);

    vm.expectRevert(IAbstractVeloVaultRelayer.AbstractVeloVaultRelayer_ZeroPrice.selector);
    relayer.read();
  }

  // --- L-17: equal-value update is a true no-op and does not defer the next increase ---

  function test_UpdatePricePerFullShare_NoOpWhenLiveEqualsAccepted() public {
    uint256 _before = relayer.lastPricePerFullShareUpdateTime();
    vm.warp(block.timestamp + relayer.PRICE_PER_FULL_SHARE_UPDATE_DELAY() + 1);

    // live == accepted == 1e18
    bool updated = relayer.updatePricePerFullShare();

    assertFalse(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1e18);
    assertEq(relayer.lastPricePerFullShareUpdateTime(), _before);
  }

  function test_UpdatePricePerFullShare_NoOpDoesNotDeferNextIncrease() public {
    vm.warp(block.timestamp + relayer.PRICE_PER_FULL_SHARE_UPDATE_DELAY());

    // A no-op (live == accepted) during a flat window must not reset the timer.
    relayer.updatePricePerFullShare();

    // A real increase is therefore immediately eligible rather than being pushed out a full delay.
    relayer.setPricePerFullShare(1.005e18);
    bool updated = relayer.updatePricePerFullShare();

    assertTrue(updated);
    assertEq(relayer.acceptedPricePerFullShare(), 1.005e18);
  }
}

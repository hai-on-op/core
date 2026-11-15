// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';
import {HaiVeloV2Oracle} from '@contracts/oracles/HaiVeloV2Oracle.sol';
import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IHaiVeloV2Oracle} from '@interfaces/oracles/IHaiVeloV2Oracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

contract Unit_HaiVeloV2Oracle is HaiTest {
  OracleForTest internal aeroOracle;
  HaiVeloV2Oracle internal haiVeloOracle;

  function setUp() public {
    aeroOracle = new OracleForTest(1e18);
    haiVeloOracle = new HaiVeloV2Oracle(aeroOracle);
  }

  function test_Constructor() public view {
    assertEq(address(haiVeloOracle.priceSource()), address(aeroOracle));
    assertEq(haiVeloOracle.symbol(), 'haiVELOV2 / USD');
  }

  function test_Revert_Constructor_NullPriceSource() public {
    vm.expectRevert(IHaiVeloV2Oracle.HaiVeloV2Oracle_NullPriceSource.selector);
    new HaiVeloV2Oracle(IBaseOracle(address(0)));
  }

  function test_Quote_UsesFixedMigrationRatio() public view {
    _assertValidQuote(0.044e18);
  }

  function test_Quote_TracksSourceWithoutAnotherUpdate() public {
    aeroOracle.setPriceAndValidity(0.5e18, true);
    _assertValidQuote(0.022e18);

    aeroOracle.setPriceAndValidity(2e18, true);
    _assertValidQuote(0.088e18);
  }

  function test_Quote_RoundsDown() public {
    aeroOracle.setPriceAndValidity(999, true);
    _assertValidQuote(43);

    aeroOracle.setPriceAndValidity(23, true);
    _assertValidQuote(1);
  }

  function test_Quote_InvalidSource() public {
    aeroOracle.setPriceAndValidity(1e18, false);
    _assertInvalidQuote();
  }

  function test_Quote_ZeroSource() public {
    aeroOracle.setPriceAndValidity(0, true);
    _assertInvalidQuote();
  }

  function test_Quote_NonzeroSourceRoundsToZero() public {
    aeroOracle.setPriceAndValidity(22, true);
    _assertInvalidQuote();
  }

  function test_Quote_RevertingSource() public {
    aeroOracle.setThrowsError(true);
    _assertInvalidQuote();
  }

  function test_Quote_MaximumSourceDoesNotOverflow() public {
    aeroOracle.setPriceAndValidity(type(uint256).max, true);
    _assertValidQuote(_expectedPrice(type(uint256).max));
  }

  function test_Quote_FullUint256Range(uint256 _sourcePrice) public {
    aeroOracle.setPriceAndValidity(_sourcePrice, true);
    uint256 _expected = _expectedPrice(_sourcePrice);

    if (_expected == 0) _assertInvalidQuote();
    else _assertValidQuote(_expected);
  }

  function test_DelayedOracle_AppliesOneHourDelayOnce() public {
    DelayedOracle _delayed = new DelayedOracle(haiVeloOracle, 1 hours);
    uint256 _start = block.timestamp;

    assertEq(address(_delayed.priceSource()), address(haiVeloOracle));
    assertEq(_delayed.updateDelay(), 1 hours);
    assertEq(_delayed.read(), 0.044e18);

    aeroOracle.setPriceAndValidity(2e18, true);
    assertEq(haiVeloOracle.read(), 0.088e18);

    vm.warp(_start + 1 hours - 1);
    assertFalse(_delayed.shouldUpdate());
    vm.expectRevert(IDelayedOracle.DelayedOracle_DelayHasNotElapsed.selector);
    _delayed.updateResult();

    vm.warp(_start + 1 hours);
    assertTrue(_delayed.shouldUpdate());
    assertTrue(_delayed.updateResult());
    assertEq(_delayed.read(), 0.044e18);
    (uint256 _nextPrice, bool _nextValid) = _delayed.getNextResultWithValidity();
    assertEq(_nextPrice, 0.088e18);
    assertTrue(_nextValid);

    aeroOracle.setPriceAndValidity(3e18, true);
    vm.warp(_start + 2 hours);
    assertTrue(_delayed.updateResult());
    assertEq(_delayed.read(), 0.088e18);
    (_nextPrice, _nextValid) = _delayed.getNextResultWithValidity();
    assertEq(_nextPrice, 0.132e18);
    assertTrue(_nextValid);
    assertEq(_delayed.lastUpdateTime(), _start + 2 hours);
  }

  function test_DelayedOracle_QueuesInvalidSourceAndRecovers() public {
    DelayedOracle _delayed = new DelayedOracle(haiVeloOracle, 1 hours);
    uint256 _start = block.timestamp;
    aeroOracle.setPriceAndValidity(1e18, false);

    vm.warp(_start + 1 hours);
    assertFalse(_delayed.updateResult());
    assertEq(_delayed.read(), 0.044e18);
    (uint256 _nextPrice, bool _nextValid) = _delayed.getNextResultWithValidity();
    assertEq(_nextPrice, 0);
    assertFalse(_nextValid);
    assertEq(_delayed.lastUpdateTime(), _start + 1 hours);

    vm.warp(_start + 2 hours);
    assertFalse(_delayed.updateResult());
    (uint256 _currentPrice, bool _currentValid) = _delayed.getResultWithValidity();
    assertEq(_currentPrice, 0);
    assertFalse(_currentValid);
    vm.expectRevert(IDelayedOracle.DelayedOracle_NoCurrentValue.selector);
    _delayed.read();

    // A recovered quote enters the next cache; it cannot become current immediately.
    aeroOracle.setPriceAndValidity(2e18, true);
    assertTrue(_delayed.updateResult());
    (_currentPrice, _currentValid) = _delayed.getResultWithValidity();
    assertEq(_currentPrice, 0);
    assertFalse(_currentValid);

    vm.warp(_start + 3 hours);
    assertTrue(_delayed.updateResult());
    assertEq(_delayed.read(), 0.088e18);
  }

  function _assertValidQuote(uint256 _expected) internal view {
    (uint256 _result, bool _validity) = haiVeloOracle.getResultWithValidity();
    assertEq(_result, _expected);
    assertTrue(_validity);
    assertEq(haiVeloOracle.read(), _expected);
  }

  function _assertInvalidQuote() internal {
    (uint256 _result, bool _validity) = haiVeloOracle.getResultWithValidity();
    assertEq(_result, 0);
    assertFalse(_validity);
    vm.expectRevert(IBaseOracle.InvalidPriceFeed.selector);
    haiVeloOracle.read();
  }

  function _expectedPrice(uint256 _sourcePrice) internal pure returns (uint256 _expected) {
    // Independent quotient/remainder reference avoids overflowing even at uint256.max.
    return (_sourcePrice / 1000) * 44 + ((_sourcePrice % 1000) * 44) / 1000;
  }
}

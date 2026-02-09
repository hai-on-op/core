// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CurveStableSwapNGRelayer} from '@contracts/oracles/CurveStableSwapNGRelayer.sol';
import {ICurveStableSwapNGRelayer} from '@interfaces/oracles/ICurveStableSwapNGRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Math, WAD} from '@libraries/Math.sol';

abstract contract Base is HaiTest {
  using Math for uint256;

  ICurveStableSwapNG mockPool = ICurveStableSwapNG(mockContract('CurvePool'));
  IERC20Metadata mockBaseToken = IERC20Metadata(mockContract('BaseToken'));
  IERC20Metadata mockQuoteToken = IERC20Metadata(mockContract('QuoteToken'));

  CurveStableSwapNGRelayer relayer;

  function setUp() public virtual {
    _mockCoins(0, 1);
    _mockSymbol('BASE', 'QUOTE');
    _mockDecimals(18, 18);

    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);
  }

  function _mockCoins(uint256 _baseIndex, uint256 _quoteIndex) internal {
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.coins, (_baseIndex)), abi.encode(address(mockBaseToken)));
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.coins, (_quoteIndex)), abi.encode(address(mockQuoteToken)));
  }

  function _mockSymbol(string memory _baseSymbol, string memory _quoteSymbol) internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.symbol, ()), abi.encode(_baseSymbol));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.symbol, ()), abi.encode(_quoteSymbol));
  }

  function _mockDecimals(uint8 _baseDecimals, uint8 _quoteDecimals) internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.decimals, ()), abi.encode(_baseDecimals));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.decimals, ()), abi.encode(_quoteDecimals));
  }

  function _mockPriceOracle(uint256 _index, uint256 _price) internal {
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.price_oracle, (_index)), abi.encode(_price));
  }

  function _mockStoredRates(uint256[] memory _rates) internal {
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.stored_rates, ()), abi.encode(_rates));
  }

  function _buildRates(uint256 _baseRate, uint256 _quoteRate) internal pure returns (uint256[] memory _rates) {
    _rates = new uint256[](2);
    _rates[0] = _baseRate;
    _rates[1] = _quoteRate;
  }

  function _mockValues(uint256 _priceOracle, uint256 _baseRate, uint256 _quoteRate) internal {
    _mockPriceOracle(0, _priceOracle);
    _mockStoredRates(_buildRates(_baseRate, _quoteRate));
  }

  function _wdiv(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a.wdiv(_b);
  }

  function _wmul(uint256 _a, uint256 _b) internal pure returns (uint256) {
    return _a.wmul(_b);
  }
}

// --- Constructor ---

contract Unit_CurveStableSwapNGRelayer_Constructor is Base {
  function setUp() public override {
    // Do not deploy relayer in setUp; constructor tests deploy with specific params
  }

  function test_Set_RateMultipliers_18Decimals() public {
    _mockCoins(0, 1);
    _mockSymbol('BASE', 'QUOTE');
    _mockDecimals(18, 18);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);

    assertEq(relayer.baseRateMultiplier(), 1e18);
    assertEq(relayer.quoteRateMultiplier(), 1e18);
  }

  function test_Set_RateMultipliers_MixedDecimals() public {
    _mockCoins(0, 1);
    _mockSymbol('BASE', 'QUOTE');
    _mockDecimals(6, 18);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);

    assertEq(relayer.baseRateMultiplier(), 1e30);
    assertEq(relayer.quoteRateMultiplier(), 1e18);
  }

  function test_Set_RateMultipliers_BothNon18() public {
    _mockCoins(0, 1);
    _mockSymbol('BASE', 'QUOTE');
    _mockDecimals(6, 8);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);

    assertEq(relayer.baseRateMultiplier(), 1e30);
    assertEq(relayer.quoteRateMultiplier(), 1e28);
  }

  function test_Revert_NullPool() public {
    vm.expectRevert(ICurveStableSwapNGRelayer.CurveStableSwapNGRelayer_NullPool.selector);
    new CurveStableSwapNGRelayer(address(0), 0, 1);
  }

  function test_Revert_SameIndex() public {
    vm.expectRevert(ICurveStableSwapNGRelayer.CurveStableSwapNGRelayer_InvalidOracleIndex.selector);
    new CurveStableSwapNGRelayer(address(mockPool), 1, 1);
  }
}

// --- read() ---

contract Unit_CurveStableSwapNGRelayer_Read is Base {
  modifier happyPath(uint256 _priceOracle, uint256 _baseRate, uint256 _quoteRate) {
    _assumeHappyPath(_priceOracle);
    _mockValues(_priceOracle, _baseRate, _quoteRate);
    _;
  }

  function _assumeHappyPath(uint256 _priceOracle) internal pure {
    vm.assume(_priceOracle > 0);
  }

  // Both 18 decimals, plain tokens, 1:1 exchange
  function test_Read_PlainTokens_1to1() public happyPath(WAD, 1e18, 1e18) {
    assertEq(relayer.read(), WAD);
  }

  // Plain tokens with a non-unity virtual price
  function test_Read_PlainTokens_NonUnity() public happyPath(0.98e18, 1e18, 1e18) {
    uint256 _expected = _wdiv(WAD, 0.98e18);
    assertEq(relayer.read(), _expected);
  }

  // One token has oracle rate (like HAI with redemption price ~1.285)
  function test_Read_WithOracleRate() public happyPath(1_008_145_191_390_011_162, 1_285_144_371_268_559_684, 1e18) {
    uint256 _virtualPrice = _wdiv(WAD, 1_008_145_191_390_011_162);
    uint256 _baseOracleRate = 1_285_144_371_268_559_684 * WAD / 1e18;
    uint256 _expected = _wdiv(_wmul(_virtualPrice, _baseOracleRate), 1e18);

    assertEq(relayer.read(), _expected);
    // Sanity: result should be ~1.275 (HAI worth more than BOLD)
    assertGt(relayer.read(), 1.2e18);
    assertLt(relayer.read(), 1.4e18);
  }

  // Both tokens have oracle rates (ratio 1.3/1.1 ≈ 1.18)
  function test_Read_BothOracleRates() public happyPath(WAD, 1.3e18, 1.1e18) {
    uint256 _expected = _wdiv(_wmul(WAD, 1.3e18), 1.1e18);
    assertEq(relayer.read(), _expected);
  }

  // Mixed decimals (6 and 18), plain tokens — decimal factors must not leak through
  function test_Read_MixedDecimals_PlainTokens() public {
    _mockDecimals(6, 18);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);
    _mockValues(WAD, 1e30, 1e18);

    assertEq(relayer.read(), WAD);
  }

  // Mixed decimals with an oracle rate on the 6-decimal token
  function test_Read_MixedDecimals_WithOracleRate() public {
    _mockDecimals(6, 18);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 0, 1);
    uint256 _oracleRate = 1.285e18;
    uint256 _baseStoredRate = 1e30 * _oracleRate / 1e18;
    _mockValues(WAD, _baseStoredRate, 1e18);

    uint256 _expected = _wmul(WAD, _oracleRate);
    assertEq(relayer.read(), _expected);
  }

  // baseIndex=1, quoteIndex=0
  function test_Read_BaseIsNotCoin0() public {
    _mockCoins(1, 0);
    _mockDecimals(18, 18);
    relayer = new CurveStableSwapNGRelayer(address(mockPool), 1, 0);

    // price_oracle(0) gives coin[1] vs coin[0]
    // baseIndex=1 => priceBase = price_oracle(0), quoteIndex=0 => priceQuote = WAD
    // rates: index 0 (quote) has oracle rate 1.285, index 1 (base) is plain
    uint256 _po = 1.008e18;
    _mockPriceOracle(0, _po);
    uint256[] memory _rates = new uint256[](2);
    _rates[0] = 1.285e18; // quote (index 0) has oracle rate
    _rates[1] = 1e18; // base (index 1) is plain
    _mockStoredRates(_rates);

    uint256 _expected = _wdiv(_wmul(_po, 1e18), 1.285e18);
    assertEq(relayer.read(), _expected);
    assertLt(relayer.read(), WAD);
  }

  // Reverts when price_oracle returns 0
  function test_Revert_ZeroPrice() public {
    _mockValues(0, 1e18, 1e18);

    vm.expectRevert(IBaseOracle.InvalidPriceFeed.selector);
    relayer.read();
  }

  function test_Revert_ZeroBaseOracleRate() public {
    _mockValues(WAD, 0, 1e18);

    vm.expectRevert(IBaseOracle.InvalidPriceFeed.selector);
    relayer.read();
  }

  function test_Revert_ZeroQuoteOracleRate() public {
    _mockValues(WAD, 1e18, 0);

    vm.expectRevert(IBaseOracle.InvalidPriceFeed.selector);
    relayer.read();
  }
}

// --- getResultWithValidity() ---

contract Unit_CurveStableSwapNGRelayer_GetResultWithValidity is Base {
  modifier happyPath(uint256 _priceOracle, uint256 _baseRate, uint256 _quoteRate) {
    vm.assume(_priceOracle > 0);
    _mockValues(_priceOracle, _baseRate, _quoteRate);
    _;
  }

  function test_GetResultWithValidity_Valid() public happyPath(WAD, 1e18, 1e18) {
    (uint256 _result, bool _validity) = relayer.getResultWithValidity();
    assertTrue(_validity);
    assertEq(_result, WAD);
  }

  function test_GetResultWithValidity_WithOracleRate() public happyPath(1.008e18, 1.285e18, 1e18) {
    (uint256 _result, bool _validity) = relayer.getResultWithValidity();
    assertTrue(_validity);

    uint256 _virtualPrice = _wdiv(WAD, 1.008e18);
    uint256 _expected = _wdiv(_wmul(_virtualPrice, 1.285e18), 1e18);
    assertEq(_result, _expected);
  }

  function test_GetResultWithValidity_ZeroPrice_Invalid() public {
    _mockValues(0, 1e18, 1e18);

    (uint256 _result, bool _validity) = relayer.getResultWithValidity();
    assertFalse(_validity);
    assertEq(_result, 0);
  }

  function test_GetResultWithValidity_ZeroBaseOracleRate_Invalid() public {
    _mockValues(WAD, 0, 1e18);
    (uint256 _result, bool _validity) = relayer.getResultWithValidity();
    assertFalse(_validity);
    assertEq(_result, 0);
  }

  function test_GetResultWithValidity_ZeroQuoteOracleRate_Invalid() public {
    _mockValues(WAD, 1e18, 0);
    (uint256 _result, bool _validity) = relayer.getResultWithValidity();
    assertFalse(_validity);
    assertEq(_result, 0);
  }
}

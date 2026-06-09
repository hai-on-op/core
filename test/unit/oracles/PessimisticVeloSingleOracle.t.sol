// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {PessimisticVeloSingleOracle} from '@contracts/oracles/PessimisticVeloSingleOracle.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

contract ChainlinkOracleForTest is IChainlinkOracle {
  uint8 internal immutable _decimals;
  int256 internal _answer;
  uint256 internal _updatedAt;

  constructor(uint8 __decimals, int256 __answer, uint256 __updatedAt) {
    _decimals = __decimals;
    _answer = __answer;
    _updatedAt = __updatedAt;
  }

  function decimals() external view returns (uint8 __decimals) {
    return _decimals;
  }

  function description() external pure returns (string memory _description) {
    return 'ChainlinkOracleForTest';
  }

  function getAnswer(uint256) external view returns (int256 _latestAnswer) {
    return _answer;
  }

  function getRoundData(uint256)
    external
    view
    returns (uint256 _roundId, int256 __answer, uint256 _startedAt, uint256 __updatedAt, uint256 _answeredInRound)
  {
    return (1, _answer, _updatedAt, _updatedAt, 1);
  }

  function getTimestamp(uint256) external view returns (uint256 _timestamp) {
    return _updatedAt;
  }

  function latestAnswer() external view returns (int256 _latestAnswer) {
    return _answer;
  }

  function latestRound() external pure returns (uint256 _latestRound) {
    return 1;
  }

  function latestRoundData()
    external
    view
    returns (uint256 _roundId, int256 __answer, uint256 _startedAt, uint256 __updatedAt, uint256 _answeredInRound)
  {
    return (1, _answer, _updatedAt, _updatedAt, 1);
  }

  function latestTimestamp() external view returns (uint256 _latestTimestamp) {
    return _updatedAt;
  }

  function set(int256 __answer, uint256 __updatedAt) external {
    _answer = __answer;
    _updatedAt = __updatedAt;
  }
}

contract VeloPoolForTest is IVeloPool {
  error QuoteShouldNotBeCalled();

  string public name = 'VeloPoolForTest';
  string public symbol = 'VPT';
  uint8 public decimals = 18;
  uint256 public totalSupply = 1e18;
  uint256 public reserve0;
  uint256 public reserve1;
  bool public stable;
  address public token0;
  address public token1;
  uint256 internal _decimals0;
  uint256 internal _decimals1;
  Observation[] internal _observations;

  constructor(address _token0, address _token1, bool _stable, uint256 __decimals0, uint256 __decimals1) {
    token0 = _token0;
    token1 = _token1;
    stable = _stable;
    _decimals0 = __decimals0;
    _decimals1 = __decimals1;
  }

  function setConstantObservations(uint256 _reserve0, uint256 _reserve1, uint256 _observationCount) external {
    require(_observationCount > 0);
    delete _observations;
    reserve0 = _reserve0;
    reserve1 = _reserve1;

    uint256 firstTimestamp = block.timestamp - ((_observationCount - 1) * 30 minutes);

    for (uint256 i = 0; i < _observationCount;) {
      uint256 timestamp = firstTimestamp + (i * 30 minutes);
      _observations.push(
        Observation({
          timestamp: timestamp,
          reserve0Cumulative: _reserve0 * i * 30 minutes,
          reserve1Cumulative: _reserve1 * i * 30 minutes
        })
      );

      unchecked {
        i++;
      }
    }
  }

  function setObservationsWithReserves(
    uint256[] memory _reserve0,
    uint256[] memory _reserve1,
    uint256 _period
  ) external {
    require(_reserve0.length == _reserve1.length && _reserve0.length > 0 && _period > 0);
    delete _observations;

    uint256 timestamp = block.timestamp - (_reserve0.length * _period);
    uint256 reserve0Cumulative;
    uint256 reserve1Cumulative;
    _observations.push(
      Observation({timestamp: timestamp, reserve0Cumulative: reserve0Cumulative, reserve1Cumulative: reserve1Cumulative})
    );

    for (uint256 i = 0; i < _reserve0.length;) {
      timestamp += _period;
      reserve0Cumulative += _reserve0[i] * _period;
      reserve1Cumulative += _reserve1[i] * _period;
      _observations.push(
        Observation({
          timestamp: timestamp,
          reserve0Cumulative: reserve0Cumulative,
          reserve1Cumulative: reserve1Cumulative
        })
      );

      unchecked {
        i++;
      }
    }

    reserve0 = _reserve0[_reserve0.length - 1];
    reserve1 = _reserve1[_reserve1.length - 1];
  }

  function setObservationsWithPeriods(
    uint256[] memory _reserve0,
    uint256[] memory _reserve1,
    uint256[] memory _periods
  ) external {
    require(_reserve0.length == _reserve1.length && _reserve0.length == _periods.length && _reserve0.length > 0);
    delete _observations;

    uint256 window;
    for (uint256 i = 0; i < _periods.length;) {
      require(_periods[i] > 0);
      window += _periods[i];

      unchecked {
        i++;
      }
    }

    uint256 timestamp = block.timestamp - window;
    uint256 reserve0Cumulative;
    uint256 reserve1Cumulative;
    _observations.push(
      Observation({timestamp: timestamp, reserve0Cumulative: reserve0Cumulative, reserve1Cumulative: reserve1Cumulative})
    );

    for (uint256 i = 0; i < _reserve0.length;) {
      timestamp += _periods[i];
      reserve0Cumulative += _reserve0[i] * _periods[i];
      reserve1Cumulative += _reserve1[i] * _periods[i];
      _observations.push(
        Observation({
          timestamp: timestamp,
          reserve0Cumulative: reserve0Cumulative,
          reserve1Cumulative: reserve1Cumulative
        })
      );

      unchecked {
        i++;
      }
    }

    reserve0 = _reserve0[_reserve0.length - 1];
    reserve1 = _reserve1[_reserve1.length - 1];
  }

  function setReserves(uint256 _reserve0, uint256 _reserve1) external {
    reserve0 = _reserve0;
    reserve1 = _reserve1;
  }

  function setTotalSupply(uint256 _totalSupply) external {
    totalSupply = _totalSupply;
  }

  function balanceOf(address) external pure returns (uint256 _balance) {
    return 0;
  }

  function transfer(address, uint256) external pure returns (bool _success) {
    return true;
  }

  function allowance(address, address) external pure returns (uint256 _allowance) {
    return 0;
  }

  function approve(address, uint256) external pure returns (bool _success) {
    return true;
  }

  function transferFrom(address, address, uint256) external pure returns (bool _success) {
    return true;
  }

  function quote(address, uint256, uint256) external pure returns (uint256) {
    revert QuoteShouldNotBeCalled();
  }

  function observationLength() external view returns (uint256 _observationLength) {
    return _observations.length;
  }

  function observations(uint256 index) external view returns (Observation memory _observation) {
    return _observations[index];
  }

  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
    return (reserve0, reserve1, block.timestamp);
  }

  function metadata()
    external
    view
    returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)
  {
    return (_decimals0, _decimals1, reserve0, reserve1, stable, token0, token1);
  }
}

contract Erc4626VaultForTest {
  address public immutable asset;
  uint8 public immutable decimals;
  uint256 public immutable assetsPerShare;

  constructor(address _asset, uint8 _decimals, uint256 _assetsPerShare) {
    asset = _asset;
    decimals = _decimals;
    assetsPerShare = _assetsPerShare;
  }

  function convertToAssets(uint256 _shares) external view returns (uint256 _assets) {
    return (_shares * assetsPerShare) / (10 ** decimals);
  }

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets) {
    return (_shares * assetsPerShare) / (10 ** decimals);
  }
}

contract FeeChargingErc4626VaultForTest {
  address public immutable asset;
  uint8 public immutable decimals;
  uint256 public immutable assetsPerShare;
  uint256 public immutable redeemFeeBps;

  constructor(address _asset, uint8 _decimals, uint256 _assetsPerShare, uint256 _redeemFeeBps) {
    asset = _asset;
    decimals = _decimals;
    assetsPerShare = _assetsPerShare;
    redeemFeeBps = _redeemFeeBps;
  }

  function convertToAssets(uint256 _shares) external view returns (uint256 _assets) {
    return (_shares * assetsPerShare) / (10 ** decimals);
  }

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets) {
    uint256 grossAssets = (_shares * assetsPerShare) / (10 ** decimals);
    return (grossAssets * (10_000 - redeemFeeBps)) / 10_000;
  }
}

contract YearnV2VaultForTest {
  address public immutable token;
  uint256 public immutable decimals;
  uint256 public immutable totalSupply;
  uint256 public immutable totalAssets;
  uint256 public immutable lastReport;

  uint256 public constant lockedProfit = 0;
  uint256 public constant lockedProfitDegradation = 0;

  constructor(address _token, uint256 _decimals, uint256 _totalSupply, uint256 _totalAssets) {
    token = _token;
    decimals = _decimals;
    totalSupply = _totalSupply;
    totalAssets = _totalAssets;
    lastReport = block.timestamp;
  }

  function pricePerShare() external pure returns (uint256 _pricePerShare) {
    return 1e18;
  }
}

abstract contract PessimisticVeloSingleOracleTest is HaiTest {
  address internal constant SEQUENCER_UPTIME_FEED = 0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389;
  address internal token0 = label('token0');
  address internal token1 = label('token1');
  uint256 internal constant POINTS = 4;
  uint256 internal constant MAX_TWAP_OBSERVATION_INTERVAL = 1 hours;
  uint256 internal constant MAX_STABLE_PRICE_DEVIATION = 1.05e18;
  uint256 internal constant MAX_PESSIMISTIC_PRICE_AGE = 2 hours;

  ChainlinkOracleForTest internal token0Feed;
  ChainlinkOracleForTest internal token1Feed;
  VeloPoolForTest internal pool;
  PessimisticVeloSingleOracle internal oracle;

  function _deployOracle(bool _stable, uint256 _reserve0, uint256 _reserve1) internal {
    _deployOracle(_stable, 1e18, 1e18, _reserve0, _reserve1);
  }

  function _deployOracle(
    bool _stable,
    uint256 _decimals0,
    uint256 _decimals1,
    uint256 _reserve0,
    uint256 _reserve1
  ) internal {
    token0Feed = new ChainlinkOracleForTest(8, 200_000_000, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, _stable, _decimals0, _decimals1);
    pool.setConstantObservations(_reserve0, _reserve1, POINTS + 1);
    oracle = new PessimisticVeloSingleOracle(
      address(pool),
      address(token0Feed),
      address(0),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
  }

  function _deployOracleWithFeeds(
    bool _stable,
    uint256 _reserve0,
    uint256 _reserve1,
    int256 _price0,
    int256 _price1
  ) internal {
    token0Feed = new ChainlinkOracleForTest(8, _price0, block.timestamp);
    token1Feed = new ChainlinkOracleForTest(8, _price1, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, _stable, 1e18, 1e18);
    pool.setConstantObservations(_reserve0, _reserve1, POINTS + 1);
    oracle = new PessimisticVeloSingleOracle(
      address(pool),
      address(token0Feed),
      address(token1Feed),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
  }

  function _mockSequencerUp() internal {
    _mockSequencer(0, block.timestamp - 2 hours);
  }

  function _mockSequencer(int256 _answer, uint256 _startedAt) internal {
    vm.clearMockedCalls();
    vm.mockCall(
      SEQUENCER_UPTIME_FEED,
      abi.encodeCall(IChainlinkOracle.latestRoundData, ()),
      abi.encode(uint256(1), _answer, _startedAt, _startedAt, uint256(1))
    );
  }

  function _stableDerivative(uint256 x0, uint256 y) internal pure returns (uint256 derivative) {
    derivative = 3 * ((x0 * ((y * y) / 1e18)) / 1e18) + ((((x0 * x0) / 1e18) * x0) / 1e18);
  }

  function _mappingSlot(uint256 _key, uint256 _slot) internal pure returns (bytes32 _storageSlot) {
    _storageSlot = keccak256(abi.encode(_key, _slot));
  }
}

contract Unit_PessimisticVeloSingleOracle_GetTwapPrice is PessimisticVeloSingleOracleTest {
  function test_Constructor_RevertsWhenMaxTwapObservationIntervalTooShort() public {
    vm.expectRevert(PessimisticVeloSingleOracle.TwapObservationIntervalTooShort.selector);
    new PessimisticVeloSingleOracle(
      address(0),
      address(0),
      address(0),
      3600,
      3600,
      POINTS,
      30 minutes - 1,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
  }

  function test_Constructor_RevertsWhenMaxStablePriceDeviationTooLow() public {
    vm.expectRevert(PessimisticVeloSingleOracle.StablePriceDeviationTooLow.selector);
    new PessimisticVeloSingleOracle(
      address(0),
      address(0),
      address(0),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      1e18 - 1,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
  }

  function test_Constructor_RevertsWhenMaxPessimisticPriceAgeTooShort() public {
    vm.expectRevert(PessimisticVeloSingleOracle.PessimisticPriceAgeTooShort.selector);
    new PessimisticVeloSingleOracle(
      address(0), address(0), address(0), 3600, 3600, POINTS, MAX_TWAP_OBSERVATION_INTERVAL, 1e18, 0, address(this)
    );
  }

  function test_Volatile_ReturnsNoSlippageMarginalPrice() public {
    _deployOracle(false, 100e18, 200e18);

    assertEq(oracle.getTwapPrice(token0, 1e18), 2e18);
    assertEq(oracle.getTwapPrice(token0, 100e18), 200e18);
    assertEq(oracle.getTwapPrice(token1, 1e18), 0.5e18);
    assertEq(oracle.getTwapPrice(token1, 100e18), 50e18);
  }

  function test_Stable_ReturnsNoSlippageMarginalPrice() public {
    _deployOracle(true, 100e18, 200e18);

    uint256 expectedToken0ToToken1 = (1e18 * _stableDerivative(200e18, 100e18)) / _stableDerivative(100e18, 200e18);
    uint256 expectedToken1ToToken0 = (1e18 * _stableDerivative(100e18, 200e18)) / _stableDerivative(200e18, 100e18);

    assertEq(oracle.getTwapPrice(token0, 1e18), expectedToken0ToToken1);
    assertEq(oracle.getTwapPrice(token1, 1e18), expectedToken1ToToken0);
    assertApproxEqAbs(oracle.getTwapPrice(token0, 100e18), expectedToken0ToToken1 * 100, 100);
    assertApproxEqAbs(oracle.getTwapPrice(token1, 100e18), expectedToken1ToToken0 * 100, 100);
  }

  function test_Stable_HandlesDifferentTokenDecimals() public {
    _deployOracle(true, 1e6, 1e18, 1000e6, 2000e18);

    uint256 expectedToken0ToToken1 = (1e18 * _stableDerivative(2000e18, 1000e18)) / _stableDerivative(1000e18, 2000e18);

    assertEq(oracle.getTwapPrice(token0, 1e6), expectedToken0ToToken1);
    assertApproxEqAbs(oracle.getTwapPrice(token0, 100e6), expectedToken0ToToken1 * 100, 100);
  }

  function test_StableSingleFeedTwap_DoesNotOverflowForVeryLargeReserveObservations() public {
    uint256 largeReserve = 50_000_000_000_000e18;
    _deployOracle(true, largeReserve, largeReserve);
    _mockSequencerUp();

    assertEq(oracle.getTwapPrice(token0, 1e18), 1e18);

    (uint256 price0, uint256 price1) = oracle.getTokenPrices();
    assertEq(price0, 200_000_000);
    assertEq(price1, price0);
  }

  function test_GetTokenPrices_UsesNoSlippageTwapPrice() public {
    _deployOracle(false, 100e18, 200e18);
    _mockSequencerUp();

    (uint256 price0, uint256 price1) = oracle.getTokenPrices();

    assertEq(price0, 200_000_000);
    assertEq(price1, 100_000_000);
  }

  function test_GetTokenPrices_DerivesSingleFeedPriceWithoutTinyRawQuoteRounding() public {
    token0Feed = new ChainlinkOracleForTest(8, 100_000_000, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, false, 1e6, 1e8);
    pool.setConstantObservations(600_000e6, 1e8, POINTS + 1);
    oracle = new PessimisticVeloSingleOracle(
      address(pool),
      address(token0Feed),
      address(0),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
    _mockSequencerUp();

    uint256 tinyRawQuote = oracle.getTwapPrice(token0, 1e6 / 100);
    (, uint256 price1) = oracle.getTokenPrices();

    assertEq(tinyRawQuote, 1);
    assertEq(price1, 600_000e8);
    assertEq((uint256(100_000_000) * 1e8) / (tinyRawQuote * 100), 1_000_000e8);
  }

  function test_GetTokenPrices_RevertsWhenDerivedTokenPriceRoundsToZero() public {
    _deployOracle(false, 1e18, 1_000_000_000e18);
    _mockSequencerUp();

    vm.expectRevert(PessimisticVeloSingleOracle.InvalidDerivedPrice.selector);
    oracle.getTokenPrices();
  }

  function test_GetTokenPrices_AveragesDerivedTokenPricePerSample() public {
    _deployOracle(false, 1_000_000e18, 1_000_000e18);
    _mockSequencerUp();

    uint256[] memory reserve0 = new uint256[](POINTS);
    uint256[] memory reserve1 = new uint256[](POINTS);
    reserve0[0] = 10_000e18;
    reserve1[0] = 1_000_000e18;
    for (uint256 i = 1; i < POINTS;) {
      reserve0[i] = 1_000_000e18;
      reserve1[i] = 1_000_000e18;

      unchecked {
        i++;
      }
    }

    pool.setObservationsWithReserves(reserve0, reserve1, 30 minutes);

    (, uint256 price1) = oracle.getTokenPrices();

    uint256 token0Price = 200_000_000;
    uint256 amountIn = 1e18 / 100;
    uint256 expectedPrice1;
    uint256 averageQuote;
    for (uint256 i = 0; i < POINTS;) {
      uint256 amountOut = (amountIn * reserve1[i]) / reserve0[i];
      expectedPrice1 += (token0Price * 1e18) / (amountOut * 100);
      averageQuote += amountOut;

      unchecked {
        i++;
      }
    }
    expectedPrice1 /= POINTS;

    uint256 vulnerablePrice1 = (token0Price * 1e18) / ((averageQuote / POINTS) * 100);

    assertEq(price1, expectedPrice1);
    assertLt(vulnerablePrice1 * 10, expectedPrice1);
  }

  function test_GetCurrentPoolPrice_CapsVolatileSingleFeedToken0PricingByCurrentFedReserve() public {
    token0Feed = new ChainlinkOracleForTest(8, 100_000_000, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, false, 1e6, 1e18);
    pool.setConstantObservations(1000e6, 1e18, POINTS + 1);
    oracle = new PessimisticVeloSingleOracle(
      address(pool),
      address(token0Feed),
      address(0),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
    _mockSequencerUp();

    (, uint256 derivedToken1Price) = oracle.getTokenPrices();
    assertEq(derivedToken1Price, 1000e8);
    assertApproxEqAbs(oracle.getCurrentPoolPrice(false), 2000e8, 1);

    pool.setReserves(10e6, 100e18);

    assertEq(oracle.getCurrentPoolPrice(false), 20e8);
  }

  function test_GetCurrentPoolPrice_CapsVolatileSingleFeedToken1PricingByCurrentFedReserve() public {
    token1Feed = new ChainlinkOracleForTest(8, 100_000_000, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, false, 1e18, 1e6);
    pool.setConstantObservations(1e18, 1000e6, POINTS + 1);
    oracle = new PessimisticVeloSingleOracle(
      address(pool),
      address(0),
      address(token1Feed),
      3600,
      3600,
      POINTS,
      MAX_TWAP_OBSERVATION_INTERVAL,
      MAX_STABLE_PRICE_DEVIATION,
      MAX_PESSIMISTIC_PRICE_AGE,
      address(this)
    );
    _mockSequencerUp();

    (uint256 derivedToken0Price,) = oracle.getTokenPrices();
    assertEq(derivedToken0Price, 1000e8);
    assertApproxEqAbs(oracle.getCurrentPoolPrice(false), 2000e8, 1);

    pool.setReserves(100e18, 10e6);

    assertEq(oracle.getCurrentPoolPrice(false), 20e8);
  }

  function test_GetCurrentPoolPrice_DoesNotOverflowForHugeVolatileReserves() public {
    uint256 hugeReserve = (type(uint256).max / 1e18) + 1;
    _deployOracleWithFeeds(false, hugeReserve, hugeReserve, 100_000_000, 100_000_000);
    pool.setTotalSupply(2 * hugeReserve);
    _mockSequencerUp();

    assertApproxEqAbs(oracle.getCurrentPoolPrice(false), 1e8, 1);
  }

  function test_GetTokenPrices_RevertsWhenLatestTwapObservationIsTooOld() public {
    _deployOracle(false, 1_000_000e18, 1_000_000e18);
    vm.warp(block.timestamp + 1 hours + 1);
    token0Feed.set(200_000_000, block.timestamp);
    _mockSequencerUp();

    vm.expectRevert(PessimisticVeloSingleOracle.TwapObservationTooOld.selector);
    oracle.getTokenPrices();
  }

  function test_GetTokenPrices_RevertsWhenTwapObservationIntervalIsTooLong() public {
    _deployOracle(false, 1_000_000e18, 1_000_000e18);
    _mockSequencerUp();

    uint256[] memory reserve0 = new uint256[](POINTS);
    uint256[] memory reserve1 = new uint256[](POINTS);
    uint256[] memory periods = new uint256[](POINTS);
    reserve0[0] = 1_000_000e18;
    reserve1[0] = 1_000_000e18;
    periods[0] = 1 hours + 1;
    for (uint256 i = 1; i < POINTS;) {
      reserve0[i] = 1_000_000e18;
      reserve1[i] = 1_000_000e18;
      periods[i] = 30 minutes;

      unchecked {
        i++;
      }
    }

    pool.setObservationsWithPeriods(reserve0, reserve1, periods);

    vm.expectRevert(PessimisticVeloSingleOracle.TwapObservationIntervalTooLong.selector);
    oracle.getTokenPrices();
  }

  function test_GetCurrentPoolPrice_PessimisticRevertsDuringSequencerGracePeriod() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);
    oracle.updatePrice();

    _mockSequencer(0, block.timestamp - 30 minutes);

    vm.expectRevert(PessimisticVeloSingleOracle.GracePeriodNotOver.selector);
    oracle.getCurrentPoolPrice(true);
  }

  function test_GetCurrentPoolPrice_PessimisticRequiresPostSequencerRecoveryUpdate() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);
    oracle.updatePrice();

    vm.warp(block.timestamp + 2 hours);
    uint256 sequencerStartedAt = block.timestamp - 90 minutes;
    _mockSequencer(0, sequencerStartedAt);
    token0Feed.set(100_000_000, block.timestamp);
    token1Feed.set(100_000_000, block.timestamp);

    vm.expectRevert(PessimisticVeloSingleOracle.NoPostSequencerRecoveryPriceUpdate.selector);
    oracle.getCurrentPoolPrice(true);

    oracle.updatePrice();

    assertGt(oracle.lastPriceUpdateTime(), sequencerStartedAt);
    assertGt(oracle.getCurrentPoolPrice(true), 0);
  }

  function test_GetCurrentPoolPrice_PessimisticRevertsWhenLatestUpdateIsStale() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);
    oracle.updatePrice();
    uint256 lastPriceUpdateTime = oracle.lastPriceUpdateTime();

    vm.warp(block.timestamp + MAX_PESSIMISTIC_PRICE_AGE + 1);
    _mockSequencer(0, lastPriceUpdateTime - 2 hours);
    token0Feed.set(100_000_000, block.timestamp);
    token1Feed.set(100_000_000, block.timestamp);
    pool.setConstantObservations(1e18, 1e18, POINTS + 1);

    assertGt(oracle.getCurrentPoolPrice(false), 0);

    vm.expectRevert(PessimisticVeloSingleOracle.PessimisticPriceStale.selector);
    oracle.getCurrentPoolPrice(true);

    oracle.updatePrice();

    assertGt(oracle.getCurrentPoolPrice(true), 0);
  }

  function test_GetCurrentPoolPrice_ThreeDayLowRequiresFullWindow() public {
    vm.warp(10 days);
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);
    oracle.setUseThreeDayLow(true);

    oracle.updatePrice();

    vm.expectRevert(PessimisticVeloSingleOracle.PessimisticPriceWindowNotReady.selector);
    oracle.getCurrentPoolPrice(true);

    vm.warp(block.timestamp + 1 days);
    _mockSequencerUp();
    token0Feed.set(100_000_000, block.timestamp);
    token1Feed.set(100_000_000, block.timestamp);
    oracle.updatePrice();

    vm.expectRevert(PessimisticVeloSingleOracle.PessimisticPriceWindowNotReady.selector);
    oracle.getCurrentPoolPrice(true);

    vm.warp(block.timestamp + 1 days);
    _mockSequencerUp();
    token0Feed.set(100_000_000, block.timestamp);
    token1Feed.set(100_000_000, block.timestamp);
    oracle.updatePrice();

    assertEq(oracle.getCurrentPoolPrice(true), 200_000_000);
  }

  function test_UpdatePrice_RevertsBeforeRecordingZeroLpPrice() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);

    pool.setReserves(0, 1e18);
    vm.expectRevert(PessimisticVeloSingleOracle.InvalidLpPrice.selector);
    oracle.updatePrice();
    uint256 day = oracle.currentDay();

    assertEq(oracle.dailyUpdates(day), 0);
    assertEq(oracle.dailyLow(day), 0);

    pool.setReserves(1e18, 1e18);
    oracle.updatePrice();

    assertEq(oracle.dailyUpdates(day), 1);
    assertEq(oracle.dailyLow(day), 200_000_000);
    assertEq(oracle.getCurrentPoolPrice(true), 200_000_000);
  }

  function test_GetCurrentPoolPrice_PessimisticIgnoresLegacyZeroLow() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();
    oracle.setOperator(address(this), true);

    uint256 yesterday = oracle.currentDay();
    vm.store(address(oracle), _mappingSlot(yesterday, 3), bytes32(uint256(1)));
    vm.store(address(oracle), bytes32(uint256(4)), bytes32(block.timestamp));

    vm.expectRevert(PessimisticVeloSingleOracle.NoValidPriceUpdates.selector);
    oracle.getCurrentPoolPrice(true);

    vm.warp(block.timestamp + 1 days);
    _mockSequencerUp();
    token0Feed.set(100_000_000, block.timestamp);
    token1Feed.set(100_000_000, block.timestamp);
    pool.setConstantObservations(1e18, 1e18, POINTS + 1);
    oracle.updatePrice();
    uint256 today = oracle.currentDay();

    assertEq(today, yesterday + 1);
    assertEq(oracle.dailyLow(yesterday), 0);
    assertGt(oracle.dailyLow(today), 0);
    assertEq(oracle.getCurrentPoolPrice(true), oracle.dailyLow(today));
  }

  function test_GetCurrentVaultPriceV3_UsesVaultShareDecimals() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();

    Erc4626VaultForTest vault = new Erc4626VaultForTest(address(pool), 6, 1e18);
    uint256 poolPrice = oracle.getCurrentPoolPrice(false);

    assertEq(oracle.getCurrentVaultPriceV3(address(vault), false), poolPrice);
  }

  function test_GetCurrentVaultPriceV3_UsesPreviewRedeemNetOfFees() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();

    FeeChargingErc4626VaultForTest vault = new FeeChargingErc4626VaultForTest(address(pool), 18, 1e18, 1000);
    uint256 poolPrice = oracle.getCurrentPoolPrice(false);

    assertEq(vault.convertToAssets(1e18), 1e18);
    assertEq(vault.previewRedeem(1e18), 0.9e18);
    assertEq(oracle.getCurrentVaultPriceV3(address(vault), false), (poolPrice * 90) / 100);
  }

  function test_GetCurrentVaultPriceV2_UsesVaultShareDecimals() public {
    _deployOracleWithFeeds(false, 1e18, 1e18, 100_000_000, 100_000_000);
    _mockSequencerUp();

    YearnV2VaultForTest vault = new YearnV2VaultForTest(address(pool), 6, 1e6, 1e18);
    uint256 poolPrice = oracle.getCurrentPoolPrice(false);

    assertEq(oracle.getCurrentVaultPriceV2(address(vault), false), poolPrice);
  }

  function test_StableLpPrice_AllowsPriceDeviationAtThreshold() public {
    _deployOracleWithFeeds(true, 1e18, 1e18, 105_000_000, 100_000_000);
    _mockSequencerUp();

    assertGt(oracle.getCurrentPoolPrice(false), 0);
  }

  function test_StableLpPrice_RevertsWhenPriceDeviationExceedsThreshold() public {
    _deployOracleWithFeeds(true, 1e18, 1e18, 106_000_000, 100_000_000);
    _mockSequencerUp();

    vm.expectRevert(PessimisticVeloSingleOracle.StablePriceDeviation.selector);
    oracle.getCurrentPoolPrice(false);
  }

  function test_StableLpPrice_DoesNotOverflowForDeepHighPricedPool() public {
    _deployOracleWithFeeds(true, 100_000e18, 100_000e18, 3000e8, 3000e8);
    _mockSequencerUp();

    assertGt(oracle.getCurrentPoolPrice(false), 0);
  }

  function test_StableLpPrice_DoesNotOverflowWhenLargeReservesStillHaveRepresentableLpPrice() public {
    _deployOracleWithFeeds(true, 20_000_000_000e18, 20_000_000_000e18, 1e8, 1e8);
    pool.setTotalSupply(40_000_000_000e18);
    _mockSequencerUp();

    assertEq(oracle.getCurrentPoolPrice(false), 1e8);
  }

  function test_StableLpPrice_DoesNotRoundToZeroForSubMillidollarAssets() public {
    _deployOracleWithFeeds(true, 1e18, 1e18, 50_000, 50_000);
    _mockSequencerUp();

    assertEq(oracle.getCurrentPoolPrice(false), 100_000);
  }
}

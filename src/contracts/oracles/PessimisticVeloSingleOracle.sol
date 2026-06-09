// SPDX-License-Identifier: AGLP-3.0
pragma solidity ^0.8.20;

import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {Ownable2Step, Ownable} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IYearnVaultV2} from '@interfaces/external/IYearnVaultV2.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {ShareValueHelper} from '@libraries/ShareValueHelper.sol';
import {FixedPointMathLib} from '@libraries/FixedPointMathLib.sol';

/**
 * @title Velodrome LP Pessimistic Single Oracle
 * @author Yearn Finance
 * @notice This oracle may be used to price Velodrome-style LP pools (both vAMM and sAMM) in a manipulation-resistant
 *  manner. A pool must contain at least one asset with a Chainlink feed to be valid. If only one asset has a Chainlink
 *  feed, an internal TWAP may be used to price the other asset , with a minimum 2 hour window. Version 2.0.0 added
 *  view functions for pricing V2 and V3 Yearn vault tokens built on top of Velodrome LPs. Version 3.0.0 transitioned
 *  to a single oracle per pool architecture, meaning Chainlink feeds could be made immutable. The pessimistic oracle
 *  stores daily lows, and prices are checked over the past two (or three) days of data when calculating an LP's value.
 *
 *  With this oracle, price manipulation attacks are substantially more difficult, as an attacker needs to log
 *  artificially high lows for an extended period of time. Additionally, if three-day lows are used, the oracle becomes
 *  more robust for public price updates, as the minimum time covered by all observations jumps from two seconds
 *  (two-day window) to 24 hours (three-day window). However, using the pessimistic oracle does have the disadvantage of
 *  reducing borrow power of borrowers to a multi-day minimum value of their collateral, where the price also must have
 *  been seen by the oracle.
 *
 *  This work builds on that of Inverse Finance (pessimistic pricing oracle), Alpha Homora (x*y=k fair reserves) and
 *  VMEX (xy^3+yx^3=k fair reserves derivation).
 */
contract PessimisticVeloSingleOracle is Ownable2Step {
  /* ========== STATE VARIABLES ========== */

  /// @notice Daily low price.
  mapping(uint256 => uint256) public dailyLow; // day => price

  /// @notice Number of times our token's price was checked on a given day.
  mapping(uint256 => uint256) public dailyUpdates; // day => number of updates

  /// @notice Last time the daily low state was updated from live pricing.
  uint256 public lastPriceUpdateTime;

  /// @notice Whether we use a three-day low instead of a two-day low.
  /// @dev May only be updated by owner. Realistically most useful when price updating is public, as this
  ///  guarantees any price observations used must be at least 24 hours apart.
  bool public useThreeDayLow = false;

  /// @notice Custom number of periods our TWAP price should cover.
  /// @dev Set on deployment, minimum is 4 (2 hours).
  uint256 public immutable points;

  /// @notice Maximum age/gap allowed for Velodrome TWAP observations.
  /// @dev Set on deployment to allow pool-specific liveness/security tradeoffs.
  uint256 public immutable maxTwapObservationInterval;

  /// @notice Maximum token price ratio allowed for stable Velodrome pool pricing.
  /// @dev 18-decimal ratio where 1e18 means 1:1.
  uint256 public immutable maxStablePriceDeviation;

  /// @notice Maximum age allowed for the latest successful pessimistic price update.
  uint256 public immutable maxPessimisticPriceAge;

  /// @notice Chainlink feed to check that Optimism's sequencer is online.
  /// @dev This prevents transactions sent while the sequencer is down from being executed when it comes back online.
  IChainlinkOracle public constant sequencerUptimeFeed = IChainlinkOracle(0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389);

  /// @notice Check if an address can update our LP pricing.
  /// @dev May only be updated by owner.
  mapping(address => bool) public operator;

  /// @notice Address of the pool for this oracle.
  address public immutable pool;

  /// @notice Whether the pool is stable (true) or volatile (false).
  bool public immutable stable;

  /// @notice Address of the pool's token0.
  address public immutable token0;

  /// @notice Decimals of the pool's token0.
  /// @dev Note that this will be "1e18"", not "18"
  uint256 public immutable decimals0;

  /// @notice Address of the Chainlink price feed for token0.
  address public immutable token0Feed;

  /// @notice Heartbeat of the Chainlink price feed for token0.
  uint96 public immutable token0Heartbeat;

  /// @notice Address of the pool's token1.
  address public immutable token1;

  /// @notice Decimals of the pool's token1.
  /// @dev Note that this will be "1e18"", not "18"
  uint256 public immutable decimals1;

  /// @notice Address of the Chainlink price feed for token1.
  address public immutable token1Feed;

  /// @notice Heartbeat of the Chainlink price feed for token1.
  uint96 public immutable token1Heartbeat;

  /// @notice Used to track the deployed version of this contract.
  string public constant apiVersion = '3.0.0a';

  // our pool/LP token decimals, just in case velodrome has weird pools in the future with different decimals
  uint256 internal constant DECIMALS = 10 ** 18;

  /// @notice Velodrome observations are normally recorded after this period elapses.
  uint256 internal constant VELO_OBSERVATION_PERIOD = 30 minutes;

  /// @notice Maximum scaled reserve or reserve-value root used in stable LP fourth-power math.
  uint256 internal constant STABLE_LP_PRICING_SCALE_LIMIT = 1e27;

  /// @notice Maximum normalized reserve size used when computing stable TWAP derivative ratios.
  uint256 internal constant STABLE_DERIVATIVE_SCALE_LIMIT = 1e27;

  /// @notice Maximum normalized reserve size used before volatile geometric-mean scaling.
  uint256 internal constant VOLATILE_GEOMEAN_SCALE_LIMIT = 1e27;

  /* ========== CONSTRUCTOR ========== */
  /**
   * @dev Check Chainlink's documentation for heartbeat length of their various feeds.
   * @param _pool Address of the Velodrome pool this oracle is pricing.
   * @param _token0Feed The Chainlink feed for token0.
   * @param _token1Feed The Chainlink feed for token1.
   * @param _token0Heartbeat The heartbeat for our token0 feed (maximum time allowed before refresh).
   * @param _token1Heartbeat The heartbeat for our token1 feed (maximum time allowed before refresh).
   * @param _twapPoints Number of samples for TWAP pricing. Minimum is 4 (2 hours).
   * @param _maxTwapObservationInterval Maximum allowed age/gap for sampled Velodrome TWAP observations.
   * @param _maxStablePriceDeviation Maximum token price ratio allowed when pricing stable pools.
   * @param _maxPessimisticPriceAge Maximum age allowed for cached pessimistic pricing.
   * @param _owner Owner role. Can set operators and adjust 2 vs 3 day pessimistic pricing.
   */
  constructor(
    address _pool,
    address _token0Feed,
    address _token1Feed,
    uint96 _token0Heartbeat,
    uint96 _token1Heartbeat,
    uint256 _twapPoints,
    uint256 _maxTwapObservationInterval,
    uint256 _maxStablePriceDeviation,
    uint256 _maxPessimisticPriceAge,
    address _owner
  ) Ownable(_owner) {
    // The default number of periods (points) we look back in time for TWAP pricing.
    // Each period is 30 mins, so minimum is 2 hours.
    if (_twapPoints < 4) {
      revert TooFewTwapPoints();
    }
    points = _twapPoints;

    if (_maxTwapObservationInterval < VELO_OBSERVATION_PERIOD) {
      revert TwapObservationIntervalTooShort();
    }
    maxTwapObservationInterval = _maxTwapObservationInterval;

    if (_maxStablePriceDeviation < DECIMALS) {
      revert StablePriceDeviationTooLow();
    }
    maxStablePriceDeviation = _maxStablePriceDeviation;

    if (_maxPessimisticPriceAge == 0) {
      revert PessimisticPriceAgeTooShort();
    }
    maxPessimisticPriceAge = _maxPessimisticPriceAge;

    // A heartbeat is the amount of time after which we consider a chainlink feed's price to be stale. For major
    // assets like BTC and ETH, this value is 3600 (1 hour). For less actively traded assets, this can be as high as
    // 86400 (1 day). Note that chainlink price feeds update based on price movement of an asset or heartbeat,
    // whichever comes sooner.
    if (_token0Heartbeat < 3600 || _token1Heartbeat < 3600) {
      revert HeartbeatTooShort();
    }

    // set the pool in the constructor, pull token0 and token1 from that
    pool = _pool;
    IVeloPool poolContract = IVeloPool(_pool);
    (uint256 _decimals0, uint256 _decimals1,,, bool _stable, address _token0, address _token1) = poolContract.metadata();
    decimals0 = _decimals0;
    decimals1 = _decimals1;
    token0 = _token0;
    token1 = _token1;
    stable = _stable;

    if (poolContract.decimals() != 18) {
      revert NotLpDecimals();
    }

    if (_token0Feed == address(0) && _token1Feed == address(0)) {
      revert NoChainlinkOracle();
    }

    if (_token0Feed != address(0) && IChainlinkOracle(_token0Feed).decimals() != 8) {
      revert NotChainlinkDecimals();
    }

    if (_token1Feed != address(0) && IChainlinkOracle(_token1Feed).decimals() != 8) {
      revert NotChainlinkDecimals();
    }

    // set our feeds and heartbeat
    token0Feed = _token0Feed;
    token1Feed = _token1Feed;
    token0Heartbeat = _token0Heartbeat;
    token1Heartbeat = _token1Heartbeat;
  }

  /* ========== EVENTS/MODIFIERS/ERRORS ========== */

  event RecordDailyLow(uint256 price);
  event OperatorUpdated(address indexed account, bool canEndorse);
  event SetUseThreeDayLow(bool useThreeDayWindow);

  error TooFewTwapPoints();
  error HeartbeatTooShort();
  error NotLpDecimals();
  error NoChainlinkOracle();
  error NotChainlinkDecimals();
  error WrongVaultForPool();
  error PriceStale();
  error PriceInvalid();
  error SequencerDown();
  error GracePeriodNotOver();
  error NotOperator();
  error NoRecentPriceUpdates();
  error TwapObservationIntervalTooShort();
  error TwapObservationTooOld();
  error TwapObservationIntervalTooLong();
  error StablePriceDeviationTooLow();
  error StablePriceDeviation();
  error NoPostSequencerRecoveryPriceUpdate();
  error PessimisticPriceAgeTooShort();
  error PessimisticPriceStale();
  error InvalidDerivedPrice();
  error InvalidLpPrice();
  error NoValidPriceUpdates();
  error PessimisticPriceWindowNotReady();

  /* ========== VIEW FUNCTIONS ========== */

  /// @notice Name of the pool this oracle is pricing
  function poolName() public view returns (string memory) {
    return IVeloPool(pool).name();
  }

  /**
   * @notice Check the last time a token's Chainlink price was updated.
   * @dev Useful for external checks if a price is stale. Reverts if no Chainlink feed set.
   * @param _tokenIndex The index of the token to get the price of (0 or 1).
   * @return updatedAt The timestamp of our last price update.
   */
  function chainlinkPriceLastUpdated(uint256 _tokenIndex) external view returns (uint256 updatedAt) {
    if (_tokenIndex == 0) {
      (,,, updatedAt,) = IChainlinkOracle(token0Feed).latestRoundData();
    } else {
      (,,, updatedAt,) = IChainlinkOracle(token1Feed).latestRoundData();
    }
  }

  /// @notice Current day used for storing daily lows.
  /// @dev Note that this is in unix time.
  function currentDay() public view returns (uint256) {
    return block.timestamp / 1 days;
  }

  /*
     * @notice Gets the current price of Yearn V3 Velodrome vault token.
     * @dev Will use fair reserves and pessimistic pricing as desired, and account for vault profits.
     * @param _vault Vault token whose price we want to check.
     * @param _usePessimisticPricing Whether we use our pessimistic pricing or not.
     * @return The current price of one LP token.
     */
  function getCurrentVaultPriceV3(address _vault, bool _usePessimisticPricing) external view returns (uint256) {
    IERC4626 vault = IERC4626(_vault);
    address _pool = vault.asset();
    if (_pool != pool) {
      revert WrongVaultForPool();
    }

    uint256 assetsPerShare = vault.previewRedeem(10 ** vault.decimals());

    if (_usePessimisticPricing) {
      return (_getAdjustedPrice(_pool) * assetsPerShare) / DECIMALS;
    } else {
      return (_getFairReservesPricing(_pool) * assetsPerShare) / DECIMALS;
    }
  }

  /*
     * @notice Gets the current price of Yearn V2 Velodrome vault token.
     * @dev Will use fair reserves and pessimistic pricing as desired, and account for vault profits.
     * @param _vault Vault token whose price we want to check..
     * @param _usePessimisticPricing Whether we use our pessimistic pricing or not.
     * @return The current price of one LP token.
     */
  function getCurrentVaultPriceV2(address _vault, bool _usePessimisticPricing) external view returns (uint256) {
    IYearnVaultV2 vault = IYearnVaultV2(_vault);
    address _pool = vault.token();
    if (_pool != pool) {
      revert WrongVaultForPool();
    }

    uint256 assetsPerShare = ShareValueHelper.sharesToAmount(_vault, 10 ** vault.decimals());

    if (_usePessimisticPricing) {
      return (_getAdjustedPrice(_pool) * assetsPerShare) / DECIMALS;
    } else {
      return (_getFairReservesPricing(_pool) * assetsPerShare) / DECIMALS;
    }
  }

  /*
     * @notice Gets the current price of a our Velodrome LP token.
     * @dev Will use fair reserves and pessimistic pricing if enabled.
     * @param _usePessimisticPricing Whether we use our pessimistic pricing or not.
     * @return The current price of one LP token.
     */
  function getCurrentPoolPrice(bool _usePessimisticPricing) external view returns (uint256) {
    if (_usePessimisticPricing) {
      return _getAdjustedPrice(pool);
    } else {
      return _getFairReservesPricing(pool);
    }
  }

  /**
   * @notice Returns the Chainlink feed price of the given token address.
   * @dev Will revert if price is negative or feed is not added.
   * @param _tokenIndex The index of the token to get the price of (0 or 1).
   * @return currentPrice The current price of the underlying token.
   */
  function getChainlinkPrice(uint256 _tokenIndex) public view returns (uint256 currentPrice) {
    address feedAddress;
    uint256 heartbeat;
    if (_tokenIndex == 0) {
      feedAddress = token0Feed;
      heartbeat = token0Heartbeat;
    } else {
      feedAddress = token1Feed;
      heartbeat = token1Heartbeat;
    }

    // pull latest data
    (, int256 price,, uint256 updatedAt,) = IChainlinkOracle(feedAddress).latestRoundData();

    // if a price is older than our preset heartbeat, we're in trouble
    if (block.timestamp - updatedAt > heartbeat) {
      revert PriceStale();
    }

    // you mean we can't have negative prices?
    if (price <= 0) {
      revert PriceInvalid();
    }

    _checkSequencerUpAndGracePeriodOver();

    currentPrice = uint256(price);
  }

  /**
   * @notice Returns the no-slippage TWAP quote for a token relative to the other token in its pool.
   * @dev Samples Velodrome's stored observations like pool.quote(), but computes a marginal price from the sampled
   *  reserves instead of simulating a finite swap through the pool curve.
   * @param _token The address of the token to price, and that we are notionally inputting.
   * @param _tokenAmount Amount of the token we are pricing.
   * @return twapPrice Amount of other token implied by _tokenAmount over our TWAP period.
   */
  function getTwapPrice(address _token, uint256 _tokenAmount) public view returns (uint256 twapPrice) {
    IVeloPool poolContract = IVeloPool(pool);

    (uint256 i, uint256 length) = _getTwapStartIndex(poolContract);

    for (; i < length;) {
      (uint256 reserve0Average, uint256 reserve1Average) = _getAverageReserves(poolContract, i);
      twapPrice += _getMarginalAmountOut(_token, _tokenAmount, reserve0Average, reserve1Average);

      unchecked {
        i++;
      }
    }

    twapPrice /= points;
  }

  // derive missing token prices directly from TWAP reserve ratios to avoid precision loss from tiny raw quotes
  function getTokenPrices() public view returns (uint256 price0, uint256 price1) {
    // check if we have chainlink feeds or TWAP for each token
    if (token0Feed != address(0)) {
      price0 = getChainlinkPrice(0); // returned with 8 decimals
      if (token1Feed != address(0)) {
        price1 = getChainlinkPrice(1); // returned with 8 decimals
      } else {
        // derive token1's price by averaging each sampled token1/token0 price
        price1 = _getTwapDerivedTokenPrice(token0, price0);
        if (price1 == 0) {
          revert InvalidDerivedPrice();
        }
      }
    } else if (token1Feed != address(0)) {
      price1 = getChainlinkPrice(1); // returned with 8 decimals
      // derive token0's price by averaging each sampled token0/token1 price
      price0 = _getTwapDerivedTokenPrice(token1, price1);
      if (price0 == 0) {
        revert InvalidDerivedPrice();
      }
    }
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /// @notice Checks current token price and saves the price if it is the day's lowest.
  /// @dev This may only be called by approved addresses; the more frequently it is called the better.
  // @param _pool LP token to update pricing for.
  function updatePrice() external {
    // don't let just anyone update deez prices
    if (!operator[msg.sender]) {
      revert NotOperator();
    }
    _updatePrice();
  }

  // internal logic to update our stored daily low pool prices
  function _updatePrice() internal {
    // get current fair reserves pricing
    uint256 currentPrice = _getFairReservesPricing(pool);
    if (currentPrice == 0) {
      revert InvalidLpPrice();
    }

    // increment our counter whether we store the price or not
    uint256 day = currentDay();
    bool isFirstUpdate = dailyUpdates[day] == 0;
    dailyUpdates[day] += 1;
    lastPriceUpdateTime = block.timestamp;

    // store price if it's today's low
    uint256 todaysLow = dailyLow[day];
    if (isFirstUpdate || currentPrice < todaysLow) {
      dailyLow[day] = currentPrice;
      emit RecordDailyLow(currentPrice);
    }
  }

  /* ========== HELPER VIEW FUNCTIONS ========== */

  // since this is called on every check for pricing, a potential liquidator could manipulate the price downward to liquidate a user

  // adjust our reported pool price as needed for 48-hour lows and hard upper/lower limits
  function _getAdjustedPrice(address _pool) internal view returns (uint256 adjustedPrice) {
    uint256 sequencerStartedAt = _checkSequencerUpAndGracePeriodOver();
    if (lastPriceUpdateTime <= sequencerStartedAt) {
      revert NoPostSequencerRecoveryPriceUpdate();
    }
    if (block.timestamp - lastPriceUpdateTime > maxPessimisticPriceAge) {
      revert PessimisticPriceStale();
    }

    // start off with our standard price
    uint256 day = currentDay();

    // if we haven't updated yet today, pretend it's yesterday instead
    if (dailyUpdates[day] == 0) {
      if (day == 0) {
        revert NoRecentPriceUpdates();
      }
      day -= 1;
      if (dailyUpdates[day] == 0) {
        revert NoRecentPriceUpdates();
      }
    }

    _requirePopulatedPessimisticWindow(day);

    adjustedPrice = _minNonZeroPrice(adjustedPrice, dailyLow[day]);

    if (day > 0 && dailyUpdates[day - 1] > 0) {
      adjustedPrice = _minNonZeroPrice(adjustedPrice, dailyLow[day - 1]);
    }

    if (useThreeDayLow && day > 1 && dailyUpdates[day - 2] > 0) {
      adjustedPrice = _minNonZeroPrice(adjustedPrice, dailyLow[day - 2]);
    }

    if (adjustedPrice == 0) {
      revert NoValidPriceUpdates();
    }
  }

  function _checkSequencerUpAndGracePeriodOver() internal view returns (uint256 startedAt) {
    // uint80 roundID int256 sequencerAnswer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
    int256 sequencerAnswer;
    (, sequencerAnswer, startedAt,,) = sequencerUptimeFeed.latestRoundData();

    // Answer == 0: L2 Sequencer is up
    // Answer == 1: L2 Sequencer is down
    if (sequencerAnswer == 1) {
      revert SequencerDown();
    }

    // Make sure a grace period of one hour has passed after the sequencer is back up.
    uint256 timeSinceUp = block.timestamp - startedAt;
    if (timeSinceUp < 3600) {
      revert GracePeriodNotOver();
    }
  }

  // calculate price based on fair reserves, not spot reserves
  function _getFairReservesPricing(address _pool) internal view returns (uint256 fairReservesPricing) {
    // get what we need to calculate our reserves and pricing
    IVeloPool poolContract = IVeloPool(_pool);
    (uint256 reserve0, uint256 reserve1,) = poolContract.getReserves();

    // make sure our reserves are normalized to 18 decimals (looking at you, USDC)
    reserve0 = _normalizeReserve(reserve0, decimals0);
    reserve1 = _normalizeReserve(reserve1, decimals1);

    // pull our prices
    (uint256 price0, uint256 price1) = getTokenPrices();

    if (stable) {
      _validateStablePriceDeviation(price0, price1);
      fairReservesPricing =
        _calculate_stable_lp_token_price(poolContract.totalSupply(), price0, price1, reserve0, reserve1, 8);
    } else {
      uint256 k = _getVolatileGeometricMean(reserve0, reserve1); // xy = k, p0r0' = p1r1', this is in 1e18
      uint256 p = FixedPointMathLib.sqrt(price0 * 1e16 * price1); // boost this to 1e16 to give us more precision

      // we want k and total supply to have same number of decimals so price has decimals of chainlink oracle
      uint256 totalSupply = poolContract.totalSupply();
      fairReservesPricing = FixedPointMathLib.mulDivDownFullPrecision(2 * p, k, totalSupply) / 1e8;
      fairReservesPricing =
        _capVolatileSingleFeedPrice(fairReservesPricing, totalSupply, reserve0, reserve1, price0, price1);
    }
  }

  function _capVolatileSingleFeedPrice(
    uint256 _lpPrice,
    uint256 _totalSupply,
    uint256 _reserve0,
    uint256 _reserve1,
    uint256 _price0,
    uint256 _price1
  ) internal view returns (uint256 cappedPrice) {
    cappedPrice = _lpPrice;

    if (token0Feed != address(0) && token1Feed == address(0)) {
      uint256 cap = 2 * FixedPointMathLib.mulDivDownFullPrecision(_reserve0, _price0, _totalSupply);
      cappedPrice = _lpPrice > cap ? cap : _lpPrice;
    } else if (token1Feed != address(0) && token0Feed == address(0)) {
      uint256 cap = 2 * FixedPointMathLib.mulDivDownFullPrecision(_reserve1, _price1, _totalSupply);
      cappedPrice = _lpPrice > cap ? cap : _lpPrice;
    }
  }

  function _validateStablePriceDeviation(uint256 _price0, uint256 _price1) internal view {
    (uint256 higherPrice, uint256 lowerPrice) = _price0 > _price1 ? (_price0, _price1) : (_price1, _price0);
    uint256 priceDeviation = FixedPointMathLib.mulDivDownFullPrecision(higherPrice, DECIMALS, lowerPrice);

    if (priceDeviation > maxStablePriceDeviation) {
      revert StablePriceDeviation();
    }
  }

  function _minNonZeroPrice(uint256 _currentPrice, uint256 _candidatePrice) internal pure returns (uint256 _price) {
    if (_candidatePrice == 0) return _currentPrice;
    if (_currentPrice == 0 || _candidatePrice < _currentPrice) return _candidatePrice;
    return _currentPrice;
  }

  function _normalizeReserve(uint256 _reserve, uint256 _decimals) internal pure returns (uint256 _normalizedReserve) {
    _normalizedReserve = FixedPointMathLib.mulDivDownFullPrecision(_reserve, DECIMALS, _decimals);
  }

  function _getVolatileGeometricMean(uint256 _reserve0, uint256 _reserve1) internal pure returns (uint256 _k) {
    if (_reserve0 == 0 || _reserve1 == 0) return 0;

    uint256 maxReserve = _reserve0 > _reserve1 ? _reserve0 : _reserve1;
    uint256 scale = _ceilDiv(maxReserve, VOLATILE_GEOMEAN_SCALE_LIMIT);
    if (scale <= 1) return FixedPointMathLib.sqrt(_reserve0 * _reserve1);

    uint256 scaledReserve0 = _reserve0 / scale;
    uint256 scaledReserve1 = _reserve1 / scale;
    if (scaledReserve0 == 0 || scaledReserve1 == 0) return 0;

    _k = FixedPointMathLib.sqrt(scaledReserve0 * scaledReserve1) * scale;
  }

  function _requirePopulatedPessimisticWindow(uint256 _day) internal view {
    if (!useThreeDayLow) return;
    if (_day < 2 || !_hasValidDailyLow(_day) || !_hasValidDailyLow(_day - 1) || !_hasValidDailyLow(_day - 2)) {
      revert PessimisticPriceWindowNotReady();
    }
  }

  function _hasValidDailyLow(uint256 _day) internal view returns (bool _valid) {
    _valid = dailyUpdates[_day] > 0 && dailyLow[_day] > 0;
  }

  function _getMarginalAmountOut(
    address _token,
    uint256 _amountIn,
    uint256 _reserve0,
    uint256 _reserve1
  ) internal view returns (uint256 amountOut) {
    bool tokenInIsToken0 = _token == token0;

    if (stable) {
      uint256 normalizedReserve0 = _normalizeReserve(_reserve0, decimals0);
      uint256 normalizedReserve1 = _normalizeReserve(_reserve1, decimals1);
      (uint256 reserveA, uint256 reserveB) =
        tokenInIsToken0 ? (normalizedReserve0, normalizedReserve1) : (normalizedReserve1, normalizedReserve0);
      uint256 normalizedAmountIn = _normalizeReserve(_amountIn, tokenInIsToken0 ? decimals0 : decimals1);
      (uint256 derivativeA, uint256 derivativeB) = _getScaledStableDerivativePair(reserveA, reserveB);
      uint256 normalizedAmountOut = FixedPointMathLib.mulDivDown(normalizedAmountIn, derivativeB, derivativeA);

      amountOut = FixedPointMathLib.mulDivDownFullPrecision(
        normalizedAmountOut, tokenInIsToken0 ? decimals1 : decimals0, DECIMALS
      );
    } else {
      (uint256 reserveA, uint256 reserveB) = tokenInIsToken0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
      amountOut = FixedPointMathLib.mulDivDown(_amountIn, reserveB, reserveA);
    }
  }

  function _getTwapDerivedTokenPrice(
    address _knownToken,
    uint256 _knownTokenPrice
  ) internal view returns (uint256 twapPrice) {
    IVeloPool poolContract = IVeloPool(pool);
    bool knownTokenIsToken0 = _knownToken == token0;

    (uint256 i, uint256 length) = _getTwapStartIndex(poolContract);

    for (; i < length;) {
      (uint256 reserve0Average, uint256 reserve1Average) = _getAverageReserves(poolContract, i);
      (uint256 knownReserve, uint256 derivedReserve) =
        _getNormalizedReservePair(knownTokenIsToken0, reserve0Average, reserve1Average);

      if (stable) {
        (uint256 knownDerivative, uint256 derivedDerivative) =
          _getScaledStableDerivativePair(knownReserve, derivedReserve);
        twapPrice += FixedPointMathLib.mulDivDownFullPrecision(_knownTokenPrice, knownDerivative, derivedDerivative);
      } else {
        twapPrice += FixedPointMathLib.mulDivDownFullPrecision(_knownTokenPrice, knownReserve, derivedReserve);
      }

      unchecked {
        i++;
      }
    }

    twapPrice /= points;
  }

  function _getNormalizedReservePair(
    bool _knownTokenIsToken0,
    uint256 _reserve0,
    uint256 _reserve1
  ) internal view returns (uint256 knownReserve, uint256 derivedReserve) {
    uint256 normalizedReserve0 = _normalizeReserve(_reserve0, decimals0);
    uint256 normalizedReserve1 = _normalizeReserve(_reserve1, decimals1);
    (knownReserve, derivedReserve) =
      _knownTokenIsToken0 ? (normalizedReserve0, normalizedReserve1) : (normalizedReserve1, normalizedReserve0);
  }

  function _getTwapStartIndex(IVeloPool _poolContract) internal view returns (uint256 startIndex, uint256 length) {
    length = _poolContract.observationLength() - 1;
    startIndex = length - points;

    IVeloPool.Observation memory latestObservation = _poolContract.observations(length);
    if (block.timestamp - latestObservation.timestamp > maxTwapObservationInterval) {
      revert TwapObservationTooOld();
    }
  }

  function _getAverageReserves(
    IVeloPool _poolContract,
    uint256 _index
  ) internal view returns (uint256 reserve0Average, uint256 reserve1Average) {
    IVeloPool.Observation memory nextObservation = _poolContract.observations(_index + 1);
    IVeloPool.Observation memory currentObservation = _poolContract.observations(_index);
    uint256 timeElapsed = nextObservation.timestamp - currentObservation.timestamp;
    if (timeElapsed > maxTwapObservationInterval) {
      revert TwapObservationIntervalTooLong();
    }

    reserve0Average = (nextObservation.reserve0Cumulative - currentObservation.reserve0Cumulative) / timeElapsed;
    reserve1Average = (nextObservation.reserve1Cumulative - currentObservation.reserve1Cumulative) / timeElapsed;
  }

  // solves for cases where curve is x^3 * y + y^3 * x = k
  // fair reserves math formula author: @ksyao2002
  function _calculate_stable_lp_token_price(
    uint256 total_supply,
    uint256 price0,
    uint256 price1,
    uint256 reserve0,
    uint256 reserve1,
    uint256 priceDecimals
  ) internal pure returns (uint256) {
    // fair_reserves = ( (k * (price0 ** 3) * (price1 ** 3)) )^(1/4) / ((price0 ** 2) + (price1 ** 2));
    price0 *= 1e18 / (10 ** priceDecimals); // convert to 18 dec
    price1 *= 1e18 / (10 ** priceDecimals);
    uint256 stablePriceScale = _getStablePriceScale(price0, price1);
    price0 *= stablePriceScale;
    price1 *= stablePriceScale;

    uint256 stablePricingScale = _getStablePricingScale(reserve0, reserve1, price0, price1);
    reserve0 /= stablePricingScale;
    reserve1 /= stablePricingScale;

    uint256 frth_fair;
    {
      uint256 k = _getK(reserve0, reserve1);
      uint256 a = FixedPointMathLib.rpow(price0, 3, 1e18); // keep same decimals as chainlink
      uint256 b = FixedPointMathLib.rpow(price1, 3, 1e18);
      uint256 c = FixedPointMathLib.rpow(price0, 2, 1e18);
      uint256 d = FixedPointMathLib.rpow(price1, 2, 1e18);

      uint256 fair = _getStableFair(k, a, b, c + d);

      // each sqrt divides the num decimals by 2. So need to replenish the decimals midway through with another 1e18
      frth_fair = FixedPointMathLib.sqrt(FixedPointMathLib.sqrt(fair * 1e18) * 1e18); // number of decimals is 18
    }

    return _scaleStableLpTokenPrice(total_supply, frth_fair, stablePricingScale, stablePriceScale, priceDecimals);
  }

  function _scaleStableLpTokenPrice(
    uint256 _totalSupply,
    uint256 _frthFair,
    uint256 _stablePricingScale,
    uint256 _stablePriceScale,
    uint256 _priceDecimals
  ) internal pure returns (uint256 _price) {
    uint256 fairReserve =
      FixedPointMathLib.mulDivDownFullPrecision(2 * _frthFair, _stablePricingScale, _stablePriceScale);

    _price = FixedPointMathLib.mulDivDownFullPrecision(fairReserve, 10 ** _priceDecimals, _totalSupply);
  }

  function _getStableFair(
    uint256 _k,
    uint256 _a,
    uint256 _b,
    uint256 _denominator
  ) internal pure returns (uint256 _fair) {
    uint256 kTimesA = FixedPointMathLib.mulDivDownFullPrecision(_k, _a, _denominator);
    _fair = FixedPointMathLib.mulDivDownFullPrecision(kTimesA, _b, DECIMALS);
  }

  function _getStablePriceScale(uint256 _price0, uint256 _price1) internal pure returns (uint256 _stablePriceScale) {
    uint256 maxPrice = _price0 > _price1 ? _price0 : _price1;
    if (maxPrice >= DECIMALS) return 1;

    _stablePriceScale = _ceilDiv(DECIMALS, maxPrice);
  }

  function _getStablePricingScale(
    uint256 _reserve0,
    uint256 _reserve1,
    uint256 _price0,
    uint256 _price1
  ) internal pure returns (uint256 stablePricingScale) {
    uint256 maxReserve = _reserve0 > _reserve1 ? _reserve0 : _reserve1;
    uint256 maxPrice = _price0 > _price1 ? _price0 : _price1;
    uint256 maxReserveValue = FixedPointMathLib.mulDivDownFullPrecision(maxReserve, maxPrice, DECIMALS);

    stablePricingScale = _ceilDiv(maxReserve, STABLE_LP_PRICING_SCALE_LIMIT);
    uint256 valueScale = _ceilDiv(maxReserveValue, STABLE_LP_PRICING_SCALE_LIMIT);
    if (valueScale > stablePricingScale) stablePricingScale = valueScale;
    if (stablePricingScale == 0) stablePricingScale = 1;
  }

  function _ceilDiv(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    if (_x == 0) return 0;
    return ((_x - 1) / _y) + 1;
  }

  function _getScaledStableDerivativePair(
    uint256 _reserveA,
    uint256 _reserveB
  ) internal pure returns (uint256 derivativeA, uint256 derivativeB) {
    (uint256 scaledReserveA, uint256 scaledReserveB) = _scaleStableDerivativeReserves(_reserveA, _reserveB);

    derivativeA = _stableDerivative(scaledReserveA, scaledReserveB);
    derivativeB = _stableDerivative(scaledReserveB, scaledReserveA);
  }

  function _scaleStableDerivativeReserves(
    uint256 _reserveA,
    uint256 _reserveB
  ) internal pure returns (uint256 scaledReserveA, uint256 scaledReserveB) {
    uint256 maxReserve = _reserveA > _reserveB ? _reserveA : _reserveB;
    uint256 scale = _ceilDiv(maxReserve, STABLE_DERIVATIVE_SCALE_LIMIT);
    if (scale <= 1) return (_reserveA, _reserveB);

    scaledReserveA = _ceilDiv(_reserveA, scale);
    scaledReserveB = _ceilDiv(_reserveB, scale);
  }

  function _getK(uint256 x, uint256 y) internal pure returns (uint256) {
    //x, n, scalar
    uint256 x_cubed = FixedPointMathLib.rpow(x, 3, 1e18);
    uint256 newX = FixedPointMathLib.mulWadDown(x_cubed, y);
    uint256 y_cubed = FixedPointMathLib.rpow(y, 3, 1e18);
    uint256 newY = FixedPointMathLib.mulWadDown(y_cubed, x);

    return newX + newY; // 18 decimals
  }

  function _stableDerivative(uint256 x0, uint256 y) internal pure returns (uint256 derivative) {
    derivative = 3 * FixedPointMathLib.mulWadDown(x0, FixedPointMathLib.mulWadDown(y, y))
      + FixedPointMathLib.mulWadDown(FixedPointMathLib.mulWadDown(x0, x0), x0);
  }

  /* ========== SETTERS ========== */

  /*
     * @notice Set whether we look back two or three days when using pessimistic pricing.
     * @dev This may only be called by owner.
     * @param _useThreeDayLow True for three day window, false for two day window.
     */
  function setUseThreeDayLow(bool _useThreeDayLow) external onlyOwner {
    useThreeDayLow = _useThreeDayLow;
    emit SetUseThreeDayLow(_useThreeDayLow);
  }

  /**
   * @notice Set the ability of an address to update LP pricing.
   * @dev Throws if caller is not owner.
   * @param _addr The address to approve or deny access.
   * @param _approved Allowed to update prices
   */
  function setOperator(address _addr, bool _approved) external onlyOwner {
    operator[_addr] = _approved;
    emit OperatorUpdated(_addr, _approved);
  }
}

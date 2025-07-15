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

  /// @notice Whether we use a three-day low instead of a two-day low.
  /// @dev May only be updated by owner. Realistically most useful when price updating is public, as this
  ///  guarantees any price observations used must be at least 24 hours apart.
  bool public useThreeDayLow = false;

  /// @notice Custom number of periods our TWAP price should cover.
  /// @dev Set on deployment, minimum is 4 (2 hours).
  uint256 public immutable points;

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

  /* ========== CONSTRUCTOR ========== */
  /**
   * @dev Check Chainlink's documentation for heartbeat length of their various feeds.
   * @param _pool Address of the Velodrome pool this oracle is pricing.
   * @param _token0Feed The Chainlink feed for token0.
   * @param _token1Feed The Chainlink feed for token1.
   * @param _token0Heartbeat The heartbeat for our token0 feed (maximum time allowed before refresh).
   * @param _token1Heartbeat The heartbeat for our token1 feed (maximum time allowed before refresh).
   * @param _twapPoints Number of samples for TWAP pricing. Minimum is 4 (2 hours).
   * @param _owner Owner role. Can set operators and adjust 2 vs 3 day pessimistic pricing.
   */
  constructor(
    address _pool,
    address _token0Feed,
    address _token1Feed,
    uint96 _token0Heartbeat,
    uint96 _token1Heartbeat,
    uint256 _twapPoints,
    address _owner
  ) Ownable(_owner) {
    // The default number of periods (points) we look back in time for TWAP pricing.
    // Each period is 30 mins, so minimum is 2 hours.
    if (_twapPoints < 4) {
      revert TooFewTwapPoints();
    }
    points = _twapPoints;

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

    if (_usePessimisticPricing) {
      return (_getAdjustedPrice(_pool) * vault.convertToAssets(DECIMALS)) / DECIMALS;
    } else {
      return (_getFairReservesPricing(_pool) * vault.convertToAssets(DECIMALS)) / DECIMALS;
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

    if (_usePessimisticPricing) {
      return (_getAdjustedPrice(_pool) * ShareValueHelper.sharesToAmount(_vault, DECIMALS)) / DECIMALS;
    } else {
      return (_getFairReservesPricing(_pool) * ShareValueHelper.sharesToAmount(_vault, DECIMALS)) / DECIMALS;
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

    // make sure the sequencer is up
    // uint80 roundID int256 sequencerAnswer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound
    (, int256 sequencerAnswer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

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

    currentPrice = uint256(price);
  }

  /**
   * @notice Returns the TWAP price for a token relative to the other token in its pool.
   * @dev Note that we can customize the length of points but we default to 4 points (2 hours). Additionally, if a
   *  pool is very small, it may not be priced as accurately if we attempt to use 1 full token to price.
   * @param _token The address of the token to get the price of, and that we are swapping in.
   * @param _tokenAmount Amount of the token we are swapping in.
   * @return twapPrice Amount of other token we get when swapping in _tokenAmount looking back over our TWAP period.
   */
  function getTwapPrice(address _token, uint256 _tokenAmount) public view returns (uint256 twapPrice) {
    IVeloPool poolContract = IVeloPool(pool);

    // swapping one of our token gets us this many otherToken, returned in decimals of the other token
    twapPrice = poolContract.quote(_token, _tokenAmount, points);
  }

  // by default we use 0.01 tokens in this function to more accurately price small pools
  function getTokenPrices() public view returns (uint256 price0, uint256 price1) {
    // check if we have chainlink feeds or TWAP for each token
    if (token0Feed != address(0)) {
      price0 = getChainlinkPrice(0); // returned with 8 decimals
      if (token1Feed != address(0)) {
        price1 = getChainlinkPrice(1); // returned with 8 decimals
      } else {
        // get twap price for token1. this is the amount of token1 we would get from 0.01 token0
        price1 = (price0 * decimals1) / (getTwapPrice(token0, decimals0 / 100) * 100);
      }
    } else if (token1Feed != address(0)) {
      price1 = getChainlinkPrice(1); // returned with 8 decimals
      // get twap price for token0. this is the amount of token0 we would get from 0.01 token1
      price0 = (price1 * decimals0) / (getTwapPrice(token1, decimals1 / 100) * 100);
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

    // increment our counter whether we store the price or not
    uint256 day = currentDay();
    dailyUpdates[day] += 1;

    // store price if it's today's low
    uint256 todaysLow = dailyLow[day];
    if (todaysLow == 0 || currentPrice < todaysLow) {
      dailyLow[day] = currentPrice;
      emit RecordDailyLow(currentPrice);
    }
  }

  /* ========== HELPER VIEW FUNCTIONS ========== */

  // since this is called on every check for pricing, a potential liquidator could manipulate the price downward to liquidate a user

  // adjust our reported pool price as needed for 48-hour lows and hard upper/lower limits
  function _getAdjustedPrice(address _pool) internal view returns (uint256 adjustedPrice) {
    // start off with our standard price
    uint256 day = currentDay();

    // if we haven't updated yet today, pretend it's yesterday instead
    if (dailyUpdates[day] == 0) {
      day -= 1;
      if (dailyUpdates[day] == 0) {
        revert NoRecentPriceUpdates();
      }
    }

    // get today's low
    uint256 todaysLow = dailyLow[day];

    // get yesterday's low
    uint256 yesterdaysLow = dailyLow[day - 1];

    // calculate price based on two-day low
    adjustedPrice = todaysLow > yesterdaysLow && yesterdaysLow > 0 ? yesterdaysLow : todaysLow;

    // if using three-day low, compare again
    if (useThreeDayLow) {
      uint256 dayBeforeYesterdaysLow = dailyLow[day - 2];
      adjustedPrice =
        adjustedPrice > dayBeforeYesterdaysLow && dayBeforeYesterdaysLow > 0 ? dayBeforeYesterdaysLow : adjustedPrice;
    }
  }

  // calculate price based on fair reserves, not spot reserves
  function _getFairReservesPricing(address _pool) internal view returns (uint256 fairReservesPricing) {
    // get what we need to calculate our reserves and pricing
    IVeloPool poolContract = IVeloPool(_pool);
    (uint256 reserve0, uint256 reserve1,) = poolContract.getReserves();

    // make sure our reserves are normalized to 18 decimals (looking at you, USDC)
    reserve0 = (reserve0 * DECIMALS) / decimals0;
    reserve1 = (reserve1 * DECIMALS) / decimals1;

    // pull our prices
    (uint256 price0, uint256 price1) = getTokenPrices();

    if (stable) {
      fairReservesPricing =
        _calculate_stable_lp_token_price(poolContract.totalSupply(), price0, price1, reserve0, reserve1, 8);
    } else {
      uint256 k = FixedPointMathLib.sqrt(reserve0 * reserve1); // xy = k, p0r0' = p1r1', this is in 1e18
      uint256 p = FixedPointMathLib.sqrt(price0 * 1e16 * price1); // boost this to 1e16 to give us more precision

      // we want k and total supply to have same number of decimals so price has decimals of chainlink oracle
      fairReservesPricing = (2 * p * k) / (1e8 * poolContract.totalSupply());
    }
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
    uint256 k = _getK(reserve0, reserve1);
    // fair_reserves = ( (k * (price0 ** 3) * (price1 ** 3)) )^(1/4) / ((price0 ** 2) + (price1 ** 2));
    price0 *= 1e18 / (10 ** priceDecimals); // convert to 18 dec
    price1 *= 1e18 / (10 ** priceDecimals);
    uint256 a = FixedPointMathLib.rpow(price0, 3, 1e18); // keep same decimals as chainlink
    uint256 b = FixedPointMathLib.rpow(price1, 3, 1e18);
    uint256 c = FixedPointMathLib.rpow(price0, 2, 1e18);
    uint256 d = FixedPointMathLib.rpow(price1, 2, 1e18);

    uint256 p0 = k * FixedPointMathLib.mulWadDown(a, b); // 2*18 decimals

    uint256 fair = p0 / (c + d); // number of decimals is 18

    // each sqrt divides the num decimals by 2. So need to replenish the decimals midway through with another 1e18
    uint256 frth_fair = FixedPointMathLib.sqrt(FixedPointMathLib.sqrt(fair * 1e18) * 1e18); // number of decimals is 18

    return 2 * ((frth_fair * (10 ** priceDecimals)) / total_supply); // converts to chainlink decimals
  }

  function _getK(uint256 x, uint256 y) internal pure returns (uint256) {
    //x, n, scalar
    uint256 x_cubed = FixedPointMathLib.rpow(x, 3, 1e18);
    uint256 newX = FixedPointMathLib.mulWadDown(x_cubed, y);
    uint256 y_cubed = FixedPointMathLib.rpow(y, 3, 1e18);
    uint256 newY = FixedPointMathLib.mulWadDown(y_cubed, x);

    return newX + newY; // 18 decimals
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

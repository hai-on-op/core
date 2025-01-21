// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayer, IBaseOracle} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';
import {SlipstreamCLRelayer} from '@contracts/oracles/SlipstreamCLRelayer.sol';

import {DenominatedOracle, IDenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {
  OP_CHAINLINK_ETH_USD_FEED,
  OP_CHAINLINK_WSTETH_ETH_FEED,
  OP_CHAINLINK_SEQUENCER_UPTIME_FEED,
  OP_WETH,
  OP_WBTC,
  OP_OPTIMISM,
  OP_USDC,
  UNISWAP_V3_FACTORY,
  SLIPSTREAM_CL_FACTORY
} from '@script/Registry.s.sol';

import {Math, WAD} from '@libraries/Math.sol';

contract E2EOracleSetup is HaiTest {
  using Math for uint256;

  uint256 FORK_BLOCK = 126_000_000;

  uint256 CHAINLINK_ETH_USD_PRICE = 263_603_000_000;
  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS = 2_636_030_000_000_000_000_000;

  uint256 NEW_ETH_USD_PRICE = 200_000_000_000;
  uint256 NEW_ETH_USD_PRICE_18_DECIMALS = 2_000_000_000_000_000_000_000;

  uint256 CHAINLINK_WSTETH_ETH_PRICE = 1_179_700_000_000_000_000; // NOTE: 18 decimals
  uint256 WSTETH_USD_PRICE = CHAINLINK_WSTETH_ETH_PRICE.wmul(CHAINLINK_ETH_USD_PRICE_18_DECIMALS);
  uint256 SLIPSTREAM_WETH_USD_PRICE = 2_642_045_442_000_000_000_000;

  uint24 TICK_SPACING_100 = 100;
  uint24 FEE_TIER_0_5 = 500;

  uint256 WBTC_ETH_PRICE = 24_555_546_428_219_269_979; // 1 BTC = 24.55555 ETH
  uint256 WBTC_USD_PRICE = 64_729_157_051_178_842_242_743; // 1 BTC = 64,729 USD

  IBaseOracle public wethUsdPriceSource;
  IBaseOracle public wstethEthPriceSource;
  IBaseOracle public wbtcWethPriceSource;
  IBaseOracle public wethUsdcVelodromePriceSource;

  IDenominatedOracle public wstethUsdPriceSource;
  IDenominatedOracle public wbtcUsdPriceSource;

  IDelayedOracle public wethUsdDelayedOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    // --- Chainlink ---
    wethUsdPriceSource = new ChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);
    wstethEthPriceSource =
      new ChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);

    // --- UniV3 ---
    wbtcWethPriceSource = new UniV3Relayer(UNISWAP_V3_FACTORY, OP_WBTC, OP_WETH, FEE_TIER_0_5, 1 days);

    // --- Slipstream ---
    wethUsdcVelodromePriceSource =
      new SlipstreamCLRelayer(SLIPSTREAM_CL_FACTORY, OP_WETH, OP_USDC, TICK_SPACING_100, 3600);

    // --- Denominated ---
    wstethUsdPriceSource = new DenominatedOracle(wstethEthPriceSource, wethUsdPriceSource, false);
    wbtcUsdPriceSource = new DenominatedOracle(wbtcWethPriceSource, wethUsdPriceSource, false);

    // --- Delayed ---
    wethUsdDelayedOracle = new DelayedOracle(wethUsdPriceSource, 1 hours);
  }

  function test_OptimismFork() public {
    assertEq(block.number, FORK_BLOCK);
  }

  // --- Chainlink ---

  function test_ChainlinkOracle() public {
    assertEq(IChainlinkOracle(OP_CHAINLINK_ETH_USD_FEED).latestAnswer(), int256(CHAINLINK_ETH_USD_PRICE));
  }

  function test_ChainlinkRelayer() public {
    assertEq(CHAINLINK_ETH_USD_PRICE_18_DECIMALS / 1e18, 2636);
    assertEq(wethUsdPriceSource.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_ChainlinkRelayerStalePrice() public {
    vm.warp(block.timestamp + 1 days);
    vm.expectRevert();

    wethUsdPriceSource.read();
  }

  function test_ChainlinkRelayerSymbol() public {
    assertEq(wethUsdPriceSource.symbol(), 'ETH / USD');
  }

  // --- UniV3 ---

  function test_UniV3Relayer() public {
    assertEq(wbtcWethPriceSource.read(), WBTC_ETH_PRICE);
  }

  function test_UniV3RelayerSymbol() public {
    assertEq(wbtcWethPriceSource.symbol(), 'WBTC / WETH');
  }

  // --- Slipstream CL ---
  function test_SlipstreamCLRelayer() public {
    assertEq(wethUsdcVelodromePriceSource.read(), SLIPSTREAM_WETH_USD_PRICE);
  }

  function test_SlipstreamCLRelayerSymbol() public {
    assertEq(wethUsdcVelodromePriceSource.symbol(), 'WETH / USDC');
  }

  // --- Denominated ---

  /**
   * NOTE: deployer needs to check that the symbols of the two oracles
   *       concatenate in the right order, e.g WSTETH/ETH - ETH/USD
   */
  function test_DenominatedOracle() public {
    assertEq(WSTETH_USD_PRICE / 1e18, 3109); // 2636.03 * 1.1797 = 3109
    assertEq(wstethUsdPriceSource.read(), WSTETH_USD_PRICE);
  }

  function test_DenominatedOracleUniV3() public {
    assertEq(WBTC_USD_PRICE / 1e18, 64_729); // 24.555 * 2636.03 = ~64727
    assertEq(wbtcUsdPriceSource.read(), WBTC_USD_PRICE);
  }

  function test_DenominatedOracleSymbol() public {
    assertEq(wstethUsdPriceSource.symbol(), '(WSTETH / ETH) * (ETH / USD)');
  }

  /**
   * NOTE: In this case, the symbols are ETH/USD - ETH/USD
   *       Using inverted = true, the resulting symbols are USD/ETH - ETH/USD
   */
  function test_DenominatedOracleInverted() public {
    IDenominatedOracle usdPriceSource = new DenominatedOracle(wethUsdPriceSource, wethUsdPriceSource, true);

    assertApproxEqAbs(usdPriceSource.read(), WAD, 1e9); // 1 USD = 1 USD (with 18 decimals)
  }

  function test_DenominatedOracleInvertedSymbol() public {
    IDenominatedOracle usdPriceSource = new DenominatedOracle(wethUsdPriceSource, wethUsdPriceSource, true);

    assertEq(usdPriceSource.symbol(), '(ETH / USD)^-1 * (ETH / USD)'); // USD / USD
  }

  // --- Delayed ---

  function test_DelayedOracle() public {
    assertEq(wethUsdDelayedOracle.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _result, bool _validity) = wethUsdDelayedOracle.getResultWithValidity();
    assertTrue(_validity);
    assertEq(_result, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _nextResult, bool _nextValidity) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertTrue(_nextValidity);
    assertEq(_nextResult, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_DelayedOracleUpdateResult() public {
    vm.mockCall(
      OP_CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp, uint80(0))
    );

    assertEq(wethUsdPriceSource.read(), NEW_ETH_USD_PRICE_18_DECIMALS);
    assertEq(wethUsdDelayedOracle.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    (uint256 _result,) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_result, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _nextResult,) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_nextResult, NEW_ETH_USD_PRICE_18_DECIMALS);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    (_result,) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_result, NEW_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_DelayedOracleUpdateInvalidResult() public {
    // The next update returns an invalid result
    vm.mockCall(
      OP_CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp - 1 days, uint80(0))
    );

    bool _valid;
    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    // The 'next' feed is now the current feed, which will be valid
    (, _valid) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_valid, true);
    // The upcoming feed however is invalid
    (, _valid) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_valid, false);

    // The next update returns a valid result
    vm.mockCall(
      OP_CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp, uint80(0))
    );

    vm.warp(block.timestamp + 10 minutes);
    wethUsdDelayedOracle.updateResult();

    // The current feed should stay valid
    (, _valid) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_valid, true);
    // Check that the next feed now has also become valid
    (, _valid) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_valid, true);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();
  }

  function test_DelayedOracleSymbol() public {
    assertEq(wethUsdDelayedOracle.symbol(), 'ETH / USD');
  }
}

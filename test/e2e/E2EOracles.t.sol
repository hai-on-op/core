// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayer, IBaseOracle} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {DenominatedOracle, IDenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {
  BeefyVeloVaultRelayer,
  IBeefyVeloVaultRelayer,
  IBeefyVaultV7,
  IVeloPool,
  IPessimisticVeloLpOracle
} from '@contracts/oracles/BeefyVeloVaultRelayer.sol';
import {
  YearnVeloVaultRelayer, IYearnVeloVaultRelayer, IYearnVault
} from '@contracts/oracles/YearnVeloVaultRelayer.sol';
import {CurveStableSwapNGRelayer, ICurveStableSwapNGRelayer} from '@contracts/oracles/CurveStableSwapNGRelayer.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';

import {
  OP_CHAINLINK_ETH_USD_FEED,
  OP_CHAINLINK_WSTETH_ETH_FEED,
  OP_CHAINLINK_SEQUENCER_UPTIME_FEED,
  OP_WETH,
  OP_WBTC,
  UNISWAP_V3_FACTORY,
  OP_VELO_POOL,
  OP_BEEFY_VAULT,
  OP_YEARN_VAULT,
  OP_PESSIMISTIC_VELODROME_LP_ORACLE,
  OP_CURVE_BOLD_HAI_POOL
} from '@script/Registry.s.sol';

import {Math, WAD} from '@libraries/Math.sol';

contract E2EOracleSetup is HaiTest {
  using Math for uint256;

  uint256 FORK_BLOCK = 147_000_000;

  uint256 CHAINLINK_ETH_USD_PRICE = 301_784_000_000;
  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS = 3_017_840_000_000_000_000_000;

  uint256 NEW_ETH_USD_PRICE = 200_000_000_000;
  uint256 NEW_ETH_USD_PRICE_18_DECIMALS = 2_000_000_000_000_000_000_000;

  uint256 CHAINLINK_WSTETH_ETH_PRICE = 1_225_335_706_320_530_300; // NOTE: 18 decimals

  uint256 WSTETH_USD_PRICE = CHAINLINK_WSTETH_ETH_PRICE.wmul(CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

  uint24 FEE_TIER = 500;

  uint256 WBTC_ETH_PRICE = 29_690_533_514_417_004_569; // 1 BTC = 29.7 ETH
  uint256 WBTC_USD_PRICE = 89_601_279_661_148_213_068_510;

  uint256 BEEFY_VAULT_USD_PRICE = 6_342_856_314_505_064_975_101;
  uint256 YEARN_VAULT_USD_PRICE = 6_226_372_298_411_693_851_171;

  uint256 CURVE_BOLD_HAI_ORACLE_INDEX = 0;
  bool CURVE_BOLD_HAI_INVERTED = true;

  IBaseOracle public wethUsdPriceSource;
  IBaseOracle public wstethEthPriceSource;
  IBaseOracle public wbtcWethPriceSource;

  IDenominatedOracle public wstethUsdPriceSource;
  IDenominatedOracle public wbtcUsdPriceSource;

  IDelayedOracle public wethUsdDelayedOracle;

  IBeefyVeloVaultRelayer public beefyVeloVaultRelayerOracle;
  IYearnVeloVaultRelayer public yearnVeloVaultRelayerOracle;
  ICurveStableSwapNGRelayer public haiBoldRelayerOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    // --- Chainlink ---
    wethUsdPriceSource = new ChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);
    wstethEthPriceSource =
      new ChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);

    // --- UniV3 ---
    wbtcWethPriceSource = new UniV3Relayer(UNISWAP_V3_FACTORY, OP_WBTC, OP_WETH, FEE_TIER, 1 days);

    // --- Denominated ---
    wstethUsdPriceSource = new DenominatedOracle(wstethEthPriceSource, wethUsdPriceSource, false);
    wbtcUsdPriceSource = new DenominatedOracle(wbtcWethPriceSource, wethUsdPriceSource, false);

    // --- Delayed ---
    wethUsdDelayedOracle = new DelayedOracle(wethUsdPriceSource, 1 hours);

    // --- Pessimistic Velo Oracle ---
    uint256 pricePerFullShare = IBeefyVaultV7(OP_BEEFY_VAULT).getPricePerFullShare();
    uint256 seededVeloLpPrice = (BEEFY_VAULT_USD_PRICE * 1e8 + pricePerFullShare - 1) / pricePerFullShare;
    vm.mockCall(
      OP_PESSIMISTIC_VELODROME_LP_ORACLE,
      abi.encodeWithSelector(IPessimisticVeloLpOracle.getCurrentPoolPrice.selector, true),
      abi.encode(seededVeloLpPrice)
    );

    // --- Vaults ---
    beefyVeloVaultRelayerOracle = new BeefyVeloVaultRelayer(
      IBeefyVaultV7(OP_BEEFY_VAULT),
      IVeloPool(OP_VELO_POOL),
      IPessimisticVeloLpOracle(OP_PESSIMISTIC_VELODROME_LP_ORACLE)
    );

    yearnVeloVaultRelayerOracle = new YearnVeloVaultRelayer(
      IYearnVault(OP_YEARN_VAULT), IVeloPool(OP_VELO_POOL), IPessimisticVeloLpOracle(OP_PESSIMISTIC_VELODROME_LP_ORACLE)
    );

    // --- Curve StableSwap-NG ---
    haiBoldRelayerOracle =
      new CurveStableSwapNGRelayer(OP_CURVE_BOLD_HAI_POOL, CURVE_BOLD_HAI_ORACLE_INDEX, CURVE_BOLD_HAI_INVERTED);
  }

  function test_OptimismFork() public {
    assertEq(block.number, FORK_BLOCK);
  }

  // --- Chainlink ---

  function test_ChainlinkOracle() public {
    assertEq(IChainlinkOracle(OP_CHAINLINK_ETH_USD_FEED).latestAnswer(), int256(CHAINLINK_ETH_USD_PRICE));
  }

  function test_ChainlinkRelayer() public {
    assertEq(CHAINLINK_ETH_USD_PRICE_18_DECIMALS / 1e18, 3017);
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

  // --- Denominated ---

  /**
   * NOTE: deployer needs to check that the symbols of the two oracles
   *       concatenate in the right order, e.g WSTETH/ETH - ETH/USD
   */
  function test_DenominatedOracle() public {
    assertEq(WSTETH_USD_PRICE / 1e18, 3697); // 3017.84 * 1.2253 = 3697
    assertEq(wstethUsdPriceSource.read(), WSTETH_USD_PRICE);
  }

  function test_DenominatedOracleUniV3() public {
    assertEq(WBTC_USD_PRICE / 1e18, 89_601); // 29.690 * 3017.84 = 89601
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

  // --- Vaults ---

  function test_BeefyVeloVaultRelayer() public {
    assertEq(beefyVeloVaultRelayerOracle.read(), BEEFY_VAULT_USD_PRICE);
  }

  function test_BeefyVeloVaultRelayerSymbol() public {
    assertEq(beefyVeloVaultRelayerOracle.symbol(), 'mooVeloV2wstETH-WETH / USD');
  }

  function test_YearnVeloVaultRelayer() public {
    assertEq(yearnVeloVaultRelayerOracle.read(), YEARN_VAULT_USD_PRICE);
  }

  function test_YearnVeloVaultRelayerSymbol() public {
    assertEq(yearnVeloVaultRelayerOracle.symbol(), 'yvVelo-wstETH-WETH-f / USD');
  }

  // --- Curve StableSwap-NG ---

  function test_CurveStableSwapNGRelayer() public {
    uint256 _price = ICurveStableSwapNG(OP_CURVE_BOLD_HAI_POOL).price_oracle(CURVE_BOLD_HAI_ORACLE_INDEX);
    uint256 _expected = CURVE_BOLD_HAI_INVERTED ? (1e36 / _price) : _price;
    assertEq(haiBoldRelayerOracle.read(), _expected);
  }

  function test_CurveStableSwapNGRelayerSymbol() public {
    assertEq(haiBoldRelayerOracle.symbol(), 'HAI / BOLD');
  }
}

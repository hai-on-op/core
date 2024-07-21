// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@script/Registry.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {TestnetParams} from '@script/TestnetParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';

abstract contract Deploy is Common, Script {
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    // Deploy tokens used to setup the environment
    deployTokens();

    // Deploy governance contracts
    deployGovernance();

    // Environment may be different for each network
    setupEnvironment();

    // Common deployment routine for all networks
    deployContracts();
    deployTaxModule();
    _setupContracts();

    deployGlobalSettlement();
    _setupGlobalSettlement();

    // PID Controller contracts
    deployPIDController();
    _setupPIDController();

    // Rewarded Actions contracts
    deployJobContracts();
    _setupJobContracts();

    // Deploy collateral contracts
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      deployCollateralContracts(_cType);
      _setupCollateral(_cType);
    }

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts(address(safeEngine));

    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    // Deploy Merkle tree claim contract and mint protocol tokens to it
    // deployTokenDistributor();

    if (delegate == address(0)) {
      _revokeDeployerToAll(governor);
    } else if (delegate == deployer) {
      _delegateToAll(governor);
    } else {
      _delegateToAll(delegate);
      _revokeDeployerToAll(governor);
    }

    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
  }

  function setupEnvironment() public virtual override updateParams {
    // Deploy oracle factories
    chainlinkRelayerFactory = new ChainlinkRelayerFactory(OP_CHAINLINK_SEQUENCER_UPTIME_FEED);
    uniV3RelayerFactory = new UniV3RelayerFactory(UNISWAP_V3_FACTORY);
    denominatedOracleFactory = new DenominatedOracleFactory();
    delayedOracleFactory = new DelayedOracleFactory();

    // Setup oracle feeds
    IBaseOracle _ethUSDPriceFeed = chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, 1 hours);
    IBaseOracle _wstethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, 1 hours);
    IBaseOracle _opUSDPriceFeed = chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_OP_USD_FEED, 1 hours);

    IBaseOracle _wstethUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, 1 hours);
    delayedOracle[OP] = delayedOracleFactory.deployDelayedOracle(_opUSDPriceFeed, 1 hours);

    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
    collateralTypes.push(OP);

    // NOTE: Deploying the PID Controller turned off until governance action
    systemCoinOracle = new HardcodedOracle('HAI / USD', HAI_USD_INITIAL_PRICE); // 1 HAI = 1 USD
  }

  function setupPostEnvironment() public virtual override updateParams {
    // Deploy HAI/WETH UniV3 pool (uninitialized)
    IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool({
      tokenA: address(systemCoin),
      tokenB: address(collateral[WETH]),
      fee: HAI_POOL_FEE_TIER
    });

    // Setup HAI/WETH oracle feed
    IBaseOracle _haiWethOracle = uniV3RelayerFactory.deployUniV3Relayer({
      _baseToken: address(systemCoin),
      _quoteToken: address(collateral[WETH]),
      _feeTier: HAI_POOL_FEE_TIER,
      _quotePeriod: 1 days
    });

    // Setup HAI/USD oracle feed
    denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _haiWethOracle,
      _denominationPriceSource: delayedOracle[WETH].priceSource(),
      _inverted: false
    });
  }
}

contract DeployTestnet is TestnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_SEPOLIA_DEPLOYER_PK'));
  }

  function setupEnvironment() public virtual override updateParams {
    delegate = 0x8125aAa8F7912aEb500553a5b1710BB16f7A6C65; // EOA

    // Deploy oracle factories
    denominatedOracleFactory = new DenominatedOracleFactory();
    delayedOracleFactory = new DelayedOracleFactory();

    // Setup oracle feeds

    // HAI
    systemCoinOracle = new HardcodedOracle('HAI / USD', HAI_USD_INITIAL_PRICE); // 1 HAI = 1 USD

    // Test tokens
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = new MintableERC20('Wrapped BTC', 'wBTC', 8);
    collateral[STONES] = new MintableERC20('Stones', 'STN', 3);
    collateral[TOTEM] = new MintableERC20('Totem', 'TTM', 0);

    // Hardcoded feeds
    IBaseOracle _ethUSDPriceFeed = new HardcodedOracle('ETH / USD', 2000e18);
    IBaseOracle _opUSDPriceFeed = new HardcodedOracle('OP / USD', 4.2e18);
    IBaseOracle _wbtcUsdOracle = new HardcodedOracle('WBTC / USD', 45_000e18);
    IBaseOracle _stonesOracle = new HardcodedOracle('STN / USD', 1e18);
    IBaseOracle _totemOracle = new HardcodedOracle('TTM / USD', 100e18);

    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[OP] = delayedOracleFactory.deployDelayedOracle(_opUSDPriceFeed, 1 hours);
    delayedOracle[WBTC] = delayedOracleFactory.deployDelayedOracle(_wbtcUsdOracle, 1 hours);
    delayedOracle[STONES] = delayedOracleFactory.deployDelayedOracle(_stonesOracle, 1 hours);
    delayedOracle[TOTEM] = delayedOracleFactory.deployDelayedOracle(_totemOracle, 1 hours);

    // Setup collateral types
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);
  }

  function setupPostEnvironment() public virtual override updateParams {
    // Setup deviated oracle
    systemCoinOracle = new DeviatedOracle({
      _symbol: 'HAI / USD',
      _oracleRelayer: address(oracleRelayer),
      _deviation: OP_SEPOLIA_HAI_PRICE_DEVIATION
    });

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
  }
}

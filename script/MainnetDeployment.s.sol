// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {MainnetParams, WETH, WSTETH, OP} from '@script/MainnetParams.s.sol';
import {OP_WETH, OP_WSTETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract MainnetDeployment is Contracts, MainnetParams {
  // NOTE: The last significant change in the Mainnet deployment, to be used in the test scenarios
  uint256 constant MAINNET_DEPLOYMENT_BLOCK = 0; // TODO: update this

  /**
   * @notice All the addresses that were deployed in the Mainnet deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
    collateralTypes.push(OP);

    // --- utils ---
    governor = 0x0000000000000000000000000000000000000000;
    delegatee[OP] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    systemCoin = SystemCoin(0x0000000000000000000000000000000000000000);
    protocolToken = ProtocolToken(0x0000000000000000000000000000000000000000);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x0000000000000000000000000000000000000000);
    oracleRelayer = OracleRelayer(0x0000000000000000000000000000000000000000);
    surplusAuctionHouse = SurplusAuctionHouse(0x0000000000000000000000000000000000000000);
    debtAuctionHouse = DebtAuctionHouse(0x0000000000000000000000000000000000000000);
    accountingEngine = AccountingEngine(0x0000000000000000000000000000000000000000);
    liquidationEngine = LiquidationEngine(0x0000000000000000000000000000000000000000);
    coinJoin = CoinJoin(0x0000000000000000000000000000000000000000);
    taxCollector = TaxCollector(0x0000000000000000000000000000000000000000);
    stabilityFeeTreasury = StabilityFeeTreasury(0x0000000000000000000000000000000000000000);
    pidController = PIDController(0x0000000000000000000000000000000000000000);
    pidRateSetter = PIDRateSetter(0x0000000000000000000000000000000000000000);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x0000000000000000000000000000000000000000);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x0000000000000000000000000000000000000000);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x0000000000000000000000000000000000000000);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x0000000000000000000000000000000000000000);
    uniV3RelayerFactory = UniV3RelayerFactory(0x0000000000000000000000000000000000000000);
    denominatedOracleFactory = DenominatedOracleFactory(0x0000000000000000000000000000000000000000);
    delayedOracleFactory = DelayedOracleFactory(0x0000000000000000000000000000000000000000);

    collateralJoinFactory = CollateralJoinFactory(0x0000000000000000000000000000000000000000);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x0000000000000000000000000000000000000000);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x0000000000000000000000000000000000000000);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x0000000000000000000000000000000000000000);

    collateralJoin[WSTETH] = CollateralJoin(0x0000000000000000000000000000000000000000);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(0x0000000000000000000000000000000000000000);

    collateralJoin[OP] = CollateralJoin(0x0000000000000000000000000000000000000000);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x0000000000000000000000000000000000000000);

    // --- jobs ---
    accountingJob = AccountingJob(0x0000000000000000000000000000000000000000);
    liquidationJob = LiquidationJob(0x0000000000000000000000000000000000000000);
    oracleJob = OracleJob(0x0000000000000000000000000000000000000000);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x0000000000000000000000000000000000000000);
    safeManager = HaiSafeManager(0x0000000000000000000000000000000000000000);

    basicActions = BasicActions(0x0000000000000000000000000000000000000000);
    debtBidActions = DebtBidActions(0x0000000000000000000000000000000000000000);
    surplusBidActions = SurplusBidActions(0x0000000000000000000000000000000000000000);
    collateralBidActions = CollateralBidActions(0x0000000000000000000000000000000000000000);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x0000000000000000000000000000000000000000);
    globalSettlementActions = GlobalSettlementActions(0x0000000000000000000000000000000000000000);
    rewardedActions = RewardedActions(0x0000000000000000000000000000000000000000);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x0000000000000000000000000000000000000000);
    delayedOracle[WETH] = IDelayedOracle(0x0000000000000000000000000000000000000000);
    delayedOracle[WSTETH] = IDelayedOracle(0x0000000000000000000000000000000000000000);
    delayedOracle[OP] = IDelayedOracle(0x0000000000000000000000000000000000000000);

    // --- governance ---
    timelock = TimelockController(payable(0x0000000000000000000000000000000000000000));
    haiGovernor = HaiGovernor(payable(0x0000000000000000000000000000000000000000));
    tokenDistributor = TokenDistributor(0x0000000000000000000000000000000000000000);
  }
}

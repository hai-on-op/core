// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {MainnetParams, WETH, WSTETH, OP} from '@script/MainnetParams.s.sol';
import {OP_WETH, OP_WSTETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract MainnetDeployment is Contracts, MainnetParams {
  // NOTE: The last significant change in the Mainnet deployment, to be used in the test scenarios
  uint256 constant MAINNET_DEPLOYMENT_BLOCK = 117_961_164;

  /**
   * @notice All the addresses that were deployed in the Mainnet deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
    collateralTypes.push(OP);

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    systemCoin = SystemCoin(0x10398AbC267496E49106B07dd6BE13364D10dC71);
    protocolToken = ProtocolToken(0xf467C7d5a4A9C4687fFc7986aC6aD5A4c81E1404);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x9Ff826860689483181C5FAc9628fd2F70275A700);
    oracleRelayer = OracleRelayer(0x6270403b908505F02Da05BE5c1956aBB59FDb3A6);
    surplusAuctionHouse = SurplusAuctionHouse(0x096125Fa7E2181DbA78136782365a39c3a1778E9);
    debtAuctionHouse = DebtAuctionHouse(0x7CdE0d7296725aFB80EA091Eca8D06A377f617b3);
    accountingEngine = AccountingEngine(0xa4900795EbFfadc12790f05f7c4AC42CD765Bd10);
    liquidationEngine = LiquidationEngine(0x8Be588895BE9B75F9a9dAee185e0c2ad89891b56);
    coinJoin = CoinJoin(0x30Ce72230A47A0967B7e52A1bAE0178DbD7c6eA3);
    taxCollector = TaxCollector(0x62B82ccE08f8F2D808348409E9418c65EB1973C3);
    stabilityFeeTreasury = StabilityFeeTreasury(0xE9E54c55d41D6622933F9F736e0c55484b3c4f6f);
    pidController = PIDController(0x6f9aeC3c0DF4DF7A0Da66453a38B8C767972f609);
    pidRateSetter = PIDRateSetter(0x1F76F20C9D9075dc160d0E47cd214dF0B7434d2f);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x75880aca7230462a630Ad65ad5444cb1E1864218);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x1fa281EA8d0e9DB78bEAA1F5b1a452058F956d66);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x7EDaD06B56bbEC6A1C5Dd95b8D00aebc803afe43);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0xBf81945a08bE132e0a2EAc42662Fcd7661BA23B8);
    uniV3RelayerFactory = UniV3RelayerFactory(0xB6A352636588D833d2795E67EAaFdC5b6F3948c1);
    denominatedOracleFactory = DenominatedOracleFactory(0xC3a0035bcD3fcBB84A4874b19f7170Bfe167fd35);
    delayedOracleFactory = DelayedOracleFactory(0x41A600E03eaa8D208B9230a219e0c4594897b3bB);

    collateralJoinFactory = CollateralJoinFactory(0xfE7987b1Ee45a8d592B15e8E924d50BFC8536143);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x81c5C2DA8C1a74c6077B03aD69ca04b74b94B427);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xbE57D71e81F83a536937f07E0B3f48dd6f55376B);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x2c6c978B3e707482236De7d23E3A375270F41175);

    collateralJoin[WSTETH] = CollateralJoin(0x77a82b65F8FA7da357A047B897C0339bD0B0B361);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(0x375686A4cD77DD8e86dD06353E0b42bC53cB3704);

    collateralJoin[OP] = CollateralJoin(0x994fa61F9305Bdd6e5E6bA84015Ee28b109C827A);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x6b5c2deA8b9b13A043DDc25C6581cD6D87a2A881);

    // --- jobs ---
    accountingJob = AccountingJob(0xc256C3aa404Ab74cE050Bcf8A05256B6A1729EF0);
    liquidationJob = LiquidationJob(0x5EF15750b5672CD6217E4E184cEAD440cB1b3638);
    oracleJob = OracleJob(0xF4F18205D8D46638489865e42c0a71a3d4F9FC22);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xBAfbCDbFbB1569722253ED4D491D2fB3b5E03a27);
    safeManager = HaiSafeManager(0xB0FF82D8322f6Fa9C28Ec46eF0A5C343e95106C3);

    basicActions = BasicActions(0x7Bd5fBa59E6FF3ad5c6937CdD83f5cAf7aA49669);
    debtBidActions = DebtBidActions(0xFC55B886a2619bd8645549f7Cb672872479F8117);
    surplusBidActions = SurplusBidActions(0x632229A0A849bde3A1f1200cF23118b33A925cEc);
    collateralBidActions = CollateralBidActions(0xbFAc170711DFE2043f47b34F118E9FCDA8FC694D);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x48c3416097529944946D08486f10185F18463640);
    globalSettlementActions = GlobalSettlementActions(0xA0A78899Cd5c093F563EF22e86B68bBC44845Fa1);
    rewardedActions = RewardedActions(0xB688d73B58e5004341f855f3E71177316281cDE7);

    // --- oracles ---
    // NOTE: HAI/USD(UniV3+Chainlink)@0x2e97fF3AB68D806324c10794f8a75B887C375312
    systemCoinOracle = IBaseOracle(0x8c212bCaE328669c8b045D467CB78b88e0BE0D39);
    delayedOracle[WETH] = IDelayedOracle(0x2fC0cb2c5065a79bC2db79e4fbD537b7CaCF6f36);
    delayedOracle[WSTETH] = IDelayedOracle(0xB64c0f551C006d932484a6F86Ea7A20D73e4f77C);
    delayedOracle[OP] = IDelayedOracle(0x519011D32806f324364201C5C98579aEC55D9011);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0xe807f3282f3391d237BA8B9bECb0d8Ea3ba23777));
    timelock = TimelockController(payable(0xd68e7D20008a223dD48A6076AAf5EDd4fe80a899));
    haiDelegatee = HaiDelegatee(0x2C6c638b93bA5a11DBD419305F14749Fc8AA2B63);

    tokenDistributor = TokenDistributor(0xCb96543b9f3657bE103Ba6371aaeD8a711Cc9E02);

    // --- utils ---
    governor = address(timelock);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {MainnetParams, WETH, WSTETH, OP} from '@script/MainnetParams.s.sol';
import {OP_WETH, OP_WSTETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract MainnetDeployment is Contracts, MainnetParams {
  // NOTE: The last significant change in the Mainnet deployment, to be used in the test scenarios
  uint256 constant MAINNET_DEPLOYMENT_BLOCK = 0; // TODO: update this when deployed

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
    governor = 0x7F9c9f7817a8915A103Bd4A1Bb7f841aA038327f;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    systemCoin = SystemCoin(0x791b01f273317a75d33382Ca9e44D286Ee175be3);
    protocolToken = ProtocolToken(0x996F113630C946d1fc44c3490864B1cEdf3EA8C8);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x117Bf57765D60f7f97C1bd03BBF636ABC36c6E13);
    oracleRelayer = OracleRelayer(0xef52D7b9e1cF25838dBfcdbB0Ef981B8368E4673);
    surplusAuctionHouse = SurplusAuctionHouse(0x450Fd0595bEc27526Cf0B850b424c7F7d42Ee121);
    debtAuctionHouse = DebtAuctionHouse(0x00261190A0EaeAb575940008428A87cA6a2eAB6e);
    accountingEngine = AccountingEngine(0x765736F1B36e8DDf2F220EfE512403308F9AB3DB);
    liquidationEngine = LiquidationEngine(0x73176E031C08220781AA3D182a31215C3BCcc155);
    coinJoin = CoinJoin(0xB3cebea43Bd0918aFDC57C64cda99fdAeB6CC56a);
    taxCollector = TaxCollector(0x16745793c46B905c08F1dCee362954B4Ef2e78c4);
    stabilityFeeTreasury = StabilityFeeTreasury(0xcCb8Eade63b567FaAb7498abc6150463F196585F);
    pidController = PIDController(0x2b30b94362B265dbBE8dD9a17e971b223baECF1D);
    pidRateSetter = PIDRateSetter(0x18754Df672C9aFB4cd588d174aBC78f7b8d94475);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x850C8d80455c2714F735cc4D504F9dD9241883eC);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x979D7aEB7f62f648Df774D43F67184715682ced3);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x9550465484cA23d2bE3d54024E6D41f7E491a0Aa);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x223a154d76dB92F42794CA4D2e585275bf3880C4);
    uniV3RelayerFactory = UniV3RelayerFactory(0x410d03c5f5dCcef7d006b8567dB17b11148b89Bb);
    denominatedOracleFactory = DenominatedOracleFactory(0xa59eeb6e4a402f9c22B0FEbc5A6503447B35BC32);
    delayedOracleFactory = DelayedOracleFactory(0xbA8D2AB61B78E529C2Feb5f3634C9FFA26277E43);

    collateralJoinFactory = CollateralJoinFactory(0x3758C1036149468b9418B67a1ee0ea8a0aB30F40);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x0E1E985EBb705B215be4Ec20fE72d86B729E731c);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xDbf42B5Fc7CBDF6A8917dDF72037138077cD25BA);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x1A0f6fA7c19271ee4506809D991a1E0e4DCde0b4);

    collateralJoin[WSTETH] = CollateralJoin(0x47EcEe0DAb2B28c1dD926Cdf55451058cfB187Da);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(0xe1B8BD057A731837CF127546826063E92955c2f1);

    collateralJoin[OP] = CollateralJoin(0xEA976c6F2283696d3F417Fb912b0B6d6b0eeF4A0);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x94bbE2108a0B2FBf8777fC63190B6405bea0251e);

    // --- jobs ---
    accountingJob = AccountingJob(0x3eE1B9d2fE0681E132612BC6C78A317a750f7E7d);
    liquidationJob = LiquidationJob(0x6b7dc78AE561Efb7A620079419acAc38d470A153);
    oracleJob = OracleJob(0xC554dA40871255AC342aC1463B5b4EB028eb8eB6);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x11eaabfd0f2Ef29C4c6Cd58b4a1FD55676dBAA6E);
    safeManager = HaiSafeManager(0xA5D7B29493944712B21323833A9096177Da8e224);

    basicActions = BasicActions(0x52AAd56812BC260925a22d99ae9877dF3f021fA9);
    debtBidActions = DebtBidActions(0x26da52b2000814b44aD0E25148995C9B768951A8);
    surplusBidActions = SurplusBidActions(0x28e4EC79B368D72Ea61e39ad80B73b39aB56186c);
    collateralBidActions = CollateralBidActions(0xBE87f102430DdeD7d1B87DF1ad6697766a796182);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0xc2Ee25E1E298466B1F8764c39d070C9c60daECBd);
    globalSettlementActions = GlobalSettlementActions(0x850f31Fc74338f8E562f844ce822f75C8cf7C5B0);
    rewardedActions = RewardedActions(0xAfc5B1Cdb8cc2f2570C555331b2E07Fc48648E73);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x6D2FC11B1563c94Ae77cEe6a2A1b0253b59db445);
    delayedOracle[WETH] = IDelayedOracle(0xC545B9E172D114277f2f5FB14Ba81eCc00Ae838f);
    delayedOracle[WSTETH] = IDelayedOracle(0x697dBE98801FdA53F2C888074638AB7B9055781D);
    delayedOracle[OP] = IDelayedOracle(0x247271e46Eb3AD1006Cd4b6D79D9cCB5126Be3E5);

    // --- governance ---
    timelock = TimelockController(payable(0x7F9c9f7817a8915A103Bd4A1Bb7f841aA038327f));
    haiGovernor = HaiGovernor(payable(0x92e2973f4941eB4B8fa2fd334e630fEAd25454cF));
    haiDelegatee = HaiDelegatee(0x325d7E58DA540F81665a50c638ea2C65Edc666B0);
    
    tokenDistributor = TokenDistributor(0xB3339246086412Def028bB2212843a81c898606E);
  }
}

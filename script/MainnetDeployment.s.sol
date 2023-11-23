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
    governor = 0x92e2973f4941eB4B8fa2fd334e630fEAd25454cF;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    systemCoin = SystemCoin(0x791b01f273317a75d33382Ca9e44D286Ee175be3);
    protocolToken = ProtocolToken(0x996F113630C946d1fc44c3490864B1cEdf3EA8C8);

    // --- base contracts ---
    safeEngine = SAFEEngine(0xbA8D2AB61B78E529C2Feb5f3634C9FFA26277E43);
    oracleRelayer = OracleRelayer(0x8535cD5e26942B5408dDE0aaCdc23066Cb9987f0);
    surplusAuctionHouse = SurplusAuctionHouse(0xC0c523E5c5cf5d8B64454A8ff3e99e7953875D3F);
    debtAuctionHouse = DebtAuctionHouse(0xa6b7eBd4611d16BB6C991B5853CFce77671d5A3c);
    accountingEngine = AccountingEngine(0x2a7164C571f011FB9FEA3F2397356B790C0f9d3A);
    liquidationEngine = LiquidationEngine(0xEBfA9358ac6F6a486BA6C5bD5d8262d8bFB61B16);
    coinJoin = CoinJoin(0x97590366CebCBD6D4d8034Ba8533c25EDe9ed298);
    taxCollector = TaxCollector(0x117Bf57765D60f7f97C1bd03BBF636ABC36c6E13);
    stabilityFeeTreasury = StabilityFeeTreasury(0xef52D7b9e1cF25838dBfcdbB0Ef981B8368E4673);
    pidController = PIDController(0x73176E031C08220781AA3D182a31215C3BCcc155);
    pidRateSetter = PIDRateSetter(0x0E1E985EBb705B215be4Ec20fE72d86B729E731c);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x450Fd0595bEc27526Cf0B850b424c7F7d42Ee121);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x00261190A0EaeAb575940008428A87cA6a2eAB6e);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x765736F1B36e8DDf2F220EfE512403308F9AB3DB);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x325d7E58DA540F81665a50c638ea2C65Edc666B0);
    uniV3RelayerFactory = UniV3RelayerFactory(0x223a154d76dB92F42794CA4D2e585275bf3880C4);
    denominatedOracleFactory = DenominatedOracleFactory(0x410d03c5f5dCcef7d006b8567dB17b11148b89Bb);
    delayedOracleFactory = DelayedOracleFactory(0xa59eeb6e4a402f9c22B0FEbc5A6503447B35BC32);

    collateralJoinFactory = CollateralJoinFactory(0x6D2FC11B1563c94Ae77cEe6a2A1b0253b59db445);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x511f9969E10dE4f18844A4930E6eA174eEb8619b);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x4430ba5Bf0C131B10c244b48064c81b82bEd2A8a);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x726cED5b161f45b9Ab86a0F6f62c5Abc575A3F74);

    collateralJoin[WSTETH] = CollateralJoin(0x4a839de2df18E92437Ae018f04C64fb1607e9604);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(0xCCD662A603B574aF687cB75d3F53A3eFcaaeD3b2);

    collateralJoin[OP] = CollateralJoin(0x640ffad5AB1178F854bC780784661dAf7520b49B);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0xa2D06d606fAfd952934990AD256E5861d51bD7B0);

    // --- jobs ---
    accountingJob = AccountingJob(0xB3cebea43Bd0918aFDC57C64cda99fdAeB6CC56a);
    liquidationJob = LiquidationJob(0x3758C1036149468b9418B67a1ee0ea8a0aB30F40);
    oracleJob = OracleJob(0x16745793c46B905c08F1dCee362954B4Ef2e78c4);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xcCb8Eade63b567FaAb7498abc6150463F196585F);
    safeManager = HaiSafeManager(0xe29027B24C9956FA3eE5955512Be0eaF5e17C623);

    basicActions = BasicActions(0x1323bA873dde69a60BDd45C533e3C2CF064535c1);
    debtBidActions = DebtBidActions(0x2492D4df29dED542367F9E429A8E9f8009eF1B3C);
    surplusBidActions = SurplusBidActions(0xa0F08B2CA89976088D2ae82287F1Ef8705392a58);
    collateralBidActions = CollateralBidActions(0x8172aD4Fd0cd1A1e05CA4115D88e51E2F03ea27A);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x3B5c182Fa18584a7AcFfF8c83B6C7B2F609786B6);
    globalSettlementActions = GlobalSettlementActions(0x7e67F357c01FdCF8aCb0C67DcdB74E5335FA08bF);
    rewardedActions = RewardedActions(0xEfED0875360b2060EDdE0F0c15B051846fcBA54B);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x10567Cc03ffb0313a31925Cf1fdF20fd4cB73942);
    delayedOracle[WETH] = IDelayedOracle(0x1F4084dc7a6F619aCD09b28bD4Bbf52779DEB661);
    delayedOracle[WSTETH] = IDelayedOracle(0x8eFF0F808b76Ce6b3f40058617480ABa658C7702);
    delayedOracle[OP] = IDelayedOracle(0xF4f698cd4C293DA15b3F2cf631bDdA7eB4159Fb9);

    // --- governance ---
    timelock = TimelockController(payable(0x92e2973f4941eB4B8fa2fd334e630fEAd25454cF));
    haiGovernor = HaiGovernor(payable(0x7F9c9f7817a8915A103Bd4A1Bb7f841aA038327f));
    tokenDistributor = TokenDistributor(0x3b2fcC752b80EB91Be9dea3087B7C21F3749eB28);
    haiDelegatee = 0x0000000000000000000000000000000000000420;
  }
}

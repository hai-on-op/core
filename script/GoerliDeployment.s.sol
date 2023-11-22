// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  // NOTE: The last significant change in the Goerli deployment, to be used in the test scenarios
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 17_538_871;

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    governor = 0x5bc1c8783b729eaCeEBfe01C220A12A8Dd704C15;
    delegatee[OP] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = IERC20Metadata(0x72Bf28D2E3dfE44a7dD0BFE265fCc381fF8A74C8);
    collateral[STONES] = IERC20Metadata(0x41944Bebe7Bfd3C708DBf96F4eE2d0c3b91843CA);
    collateral[TOTEM] = IERC20Metadata(0xdCfd86628e5e5eC7f7c1d8Ae9894E57dDF86c1f1);

    systemCoin = SystemCoin(0xb2d541BDd0037e03d6B43490c9A72594a6c37A0f);
    protocolToken = ProtocolToken(0x05CBD1C19Af83Ab7929C8cA5000076cc0D3CeD62);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x8CD47C308BE756F3721D2B25d73D372312fC58e3);
    oracleRelayer = OracleRelayer(0xC87db8Fc544b9d12c10CA68e0D396598ecECF310);
    surplusAuctionHouse = SurplusAuctionHouse(0x80e05a7ade7C1D0f82635764C6a90c6473Fc3a9c);
    debtAuctionHouse = DebtAuctionHouse(0x2b6227a6ee0DD1C51AD849675E688195cE9bB203);
    accountingEngine = AccountingEngine(0xeeD607FC8c614f75B12524e7a04f62B8257fAB33);
    liquidationEngine = LiquidationEngine(0x602F40EC23763994d5a6Dd26b240f4BeC39C7001);
    coinJoin = CoinJoin(0xf439248215b6668018272bcF4B03E6E172472b52);
    taxCollector = TaxCollector(0x4d551Fb5132bfDf04f4e3742b244989A70F6098d);
    stabilityFeeTreasury = StabilityFeeTreasury(0x1411F0833Bc05DA16a959b3De21D5Fb7f1E0881f);
    pidController = PIDController(0xb5559E17879225eAe5001de5Bc998123A1503DA6);
    pidRateSetter = PIDRateSetter(0x35448044AA20592F10Bef31e4aeD57E5A25B65Fc);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0xB9C85D0887d210fd39d22fB26EeC87705feA35a6);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x1b3D1a8A08d9d675A519E6B2fAbC56E553c90Fb5);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0xAA36fd0627Ce73a338e60418DB392F3323B88372);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x6bcccebe4c1C7E7DDB30a6a1415553d008555c5a);
    uniV3RelayerFactory = UniV3RelayerFactory(0x756d6fb87c5F5562Af55E72317A3aF44090f2796);
    denominatedOracleFactory = DenominatedOracleFactory(0x56Ab7ddB91f40125Ed1DC93dDC77c33c9c88f5BA);
    delayedOracleFactory = DelayedOracleFactory(0xDB1E529d264Be050EA9903Ff73f340479CDBc32A);

    collateralJoinFactory = CollateralJoinFactory(0xFCCdD4B18dD2Ab02D8F0721130195e8C9C394261);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0xa4B2f6Cd5287bF04435C9a0Fb7B7aefF71b99eF1);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xC0888B3d49073E84A00FE341104FB0756d9142E6);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0xE3c748B71bc75FA8E188E487f03a0E2741a7cb77);

    collateralJoin[OP] = CollateralJoin(0xD11e8a5eB973E3b4b613171b5745261fcF83ec7B);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0xbD2a307BBbd07e9E83BAf61BbB7f88F27B227C8C);

    collateralJoin[WBTC] = CollateralJoin(0x4A025ac49E92e8fC62871E56129b90612a7D8647);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0xb5aFbD1f748F22D4EaC9e7F43c709942eE6F0500);

    collateralJoin[STONES] = CollateralJoin(0xa192df7b5e9e67731b2dc2793749B36ef1f254fc);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x37941361EA0769823811a2D95aA59158277Bc82A);

    collateralJoin[TOTEM] = CollateralJoin(0x93667E2b8437a747604caC0e3716605C8a37BAa8);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0xeb3AfaE71446FBac3d97F572cE56475Cbd5a33Bc);

    // --- jobs ---
    accountingJob = AccountingJob(0xCeCc0253fA03786031A4df8DB940728543D01Fb6);
    liquidationJob = LiquidationJob(0x1Bea51CDcc5E5713A7b5eca4F1B27D90b3F0ddB5);
    oracleJob = OracleJob(0x1F517889F899A3792c4ED0D6Ae8f1A69e89E3d40);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xCE03C307d005c26d3Ee83Ff2B5341179df380887);
    safeManager = HaiSafeManager(0xd582Cb7e38503D584E7872B18B5451AbcA2527Ac);

    basicActions = BasicActions(0x61C2510325c89D6A244E2b5D84C2a2e66bFd067A);
    debtBidActions = DebtBidActions(0xDeCCaAFEbfCF2C1210ac2d7115E5E043f27071E5);
    surplusBidActions = SurplusBidActions(0xd1E276F8CEC64016e962a2c5B7D7B47aa611004b);
    collateralBidActions = CollateralBidActions(0x81b52C669ce1751c73C50945d95bbAe27ee8180D);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x14976A0bF941e9e56779F3F1Ed699865A3AF5Ea5);
    globalSettlementActions = GlobalSettlementActions(0x7ca73B3b9be083f5323804B5054BC4323ab383a3);
    rewardedActions = RewardedActions(0xB07204A37722B929198ce22C7b8015e6e7601Da7);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x8D1E17E988C3ec01b54f9A70Cb2d446108910f78);
    delayedOracle[WETH] = IDelayedOracle(0xde278930f3e971Bca639A5CF1096a884CD1E73fa);
    delayedOracle[OP] = IDelayedOracle(0x159E808BE20173A3b983bE3B55EF0a0AC959f963);
    delayedOracle[WBTC] = IDelayedOracle(0x224f560C3Eb3aaAF341f195198D07CF318E0D581);
    delayedOracle[STONES] = IDelayedOracle(0x4ad29dC70770f5D9a847a4A248b9A56a9c7F860F);
    delayedOracle[TOTEM] = IDelayedOracle(0x98007eDE26BFc17CABfA634C12D35D33D70ab8E1);

    // --- governance ---
    timelock = TimelockController(payable(0x5bc1c8783b729eaCeEBfe01C220A12A8Dd704C15));
    haiGovernor = HaiGovernor(payable(0x894114C09E237A7e4Cc2E48E5ccA32C18D3917D9));
    tokenDistributor = TokenDistributor(0xA81B4cf40Da3B25f0706983DAb8059257b11E75e);
  }
}

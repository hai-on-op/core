// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {MainnetParams, WETH, WSTETH, OP} from '@script/MainnetParams.s.sol';
import {OP_WETH, OP_WSTETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract MainnetDeployment is Contracts, MainnetParams {
  // NOTE: The last significant change in the Mainnet deployment, to be used in the test scenarios
  uint256 constant MAINNET_DEPLOYMENT_BLOCK = 112_709_963; // TODO: update this when deployed

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

    systemCoin = SystemCoin(0x8DF9703E3Bb8c43f6C1CD6916dF6394C394fc0eF);
    protocolToken = ProtocolToken(0x1BDf43597E9aCD371e88C8f76A24ebb311519f2b);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x749Af3E7407A07fba76347A9967f21A7a396335a);
    oracleRelayer = OracleRelayer(0x3441f3B0EBEC600C3048B08Bfd7F98bf50FaAD76);
    surplusAuctionHouse = SurplusAuctionHouse(0xAF6b71084BdbA44D07e52f692d8923c103D09975);
    debtAuctionHouse = DebtAuctionHouse(0xdbD0ba419692fF699cC5e33D99c00aDe1A428ac9);
    accountingEngine = AccountingEngine(0x01025ddfbC205b10a4CeE7A6904733F3C2E8CA92);
    liquidationEngine = LiquidationEngine(0x62D2B21D258c43F6e4f8DD34E8F744a3C268f21b);
    coinJoin = CoinJoin(0x2a75Aed026BBC73FeCdAa1acCE38b427fEa529D0);
    taxCollector = TaxCollector(0x7a0FEE04c49bFA4F42993ab47Ef1ddc18F7AA31a);
    stabilityFeeTreasury = StabilityFeeTreasury(0xA8c86916BB1bA4d4D04D585d48a34bD713dAd830);
    pidController = PIDController(0x4376017BF255beEFeceb4506379e6d8A3C69b4b3);
    pidRateSetter = PIDRateSetter(0xFE087fb1f729E65c6AC8E5DE3fF9e8dd7c1b0C45);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x6BEf230B891024Aa69d01d004e8768b3B9eA9312);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xfe80435B94473d196B9d1E614D9c15Da9284003E);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0xC220946cE8Efb7e4F3A96aeE141aBE7af3d07192);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0xA42fD2513e587A943f543e39D837eC04B408D07f);
    uniV3RelayerFactory = UniV3RelayerFactory(0x0fd9843e71Aa86984b34184713a3f6DF7B214153);
    denominatedOracleFactory = DenominatedOracleFactory(0x26F59Ec38a18Ce66e85d93430d84df6ca234FF80);
    delayedOracleFactory = DelayedOracleFactory(0xcf1e4119c51D2d384Ea978D169Eaf23c01abf680);

    collateralJoinFactory = CollateralJoinFactory(0xBD1E162E1d6cb1758142658b672eAF843Bf921B7);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x9d41872a185eD15A47371b6F8C0C02B8a7B1E96b);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xd3370757a381eCf763c2EF5FaA30a01aC67b9C89);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x849B288989A39A8F0FaE9691E3a4F1e660302B59);

    collateralJoin[WSTETH] = CollateralJoin(0x2Aa724EE4B72A7F8D2334d2Ba0e3ca8532f0ba12);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(0xFD17D6e7B5bb3B34B2e950523Db9252d6b34CA76);

    collateralJoin[OP] = CollateralJoin(0xAF36a722f8B599E3509e6bfd81279DAe6f79fe1E);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x71431C9c2dFB83f5E37477a697EB5Bf7422204a5);

    // --- jobs ---
    accountingJob = AccountingJob(0xe40Da1Eb3c1095c1719d9F852448E9985B8B291B);
    liquidationJob = LiquidationJob(0xdAa625CD0cDE46cb41D97B894Cf18B43Eb8a9D9E);
    oracleJob = OracleJob(0x0be8fC16A5d0a40ABD8Aa3F3F2BF3ba872a5E377);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xe8d5A5f3191735FcDf7adC33DEd20b0EF6E6d975);
    safeManager = HaiSafeManager(0x1615062482fa2426C651e42e4656a64e2738A875);

    basicActions = BasicActions(0xBEdA825f517E8ef74F571bf3Ae47d004Fd4BB9DE);
    debtBidActions = DebtBidActions(0x3408D78C69F9654C04087a412b0315663919E3a5);
    surplusBidActions = SurplusBidActions(0xa935428b62b13bFCBcd2F7b0F78C5FBfE96788DF);
    collateralBidActions = CollateralBidActions(0xf7d33E181F478C708c59D7a37066cDc273746904);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x2d346E3cB40ca1858Bdc137Fd82f801168113799);
    globalSettlementActions = GlobalSettlementActions(0x67e919F00723C735e6233276D418E7C593484065);
    rewardedActions = RewardedActions(0x3e7413CdE1Ba6443b8707AeE2b99d1bb99BBf8fd);

    // --- oracles ---
    // NOTE: HAI/USD(UniV3+Chainlink)@0x7d42BfcbbDE65bA4FB236F3435fC9985D68240DB
    systemCoinOracle = IBaseOracle(0x4F80557Cf288A535Cf04c436fEa897e5EB1f329d);
    delayedOracle[WETH] = IDelayedOracle(0xF03Db2c15127Fa96374b11eef9CbAC6C56898d35);
    delayedOracle[WSTETH] = IDelayedOracle(0x5B09578387c9FbcFc8a8817514af0407b4917122);
    delayedOracle[OP] = IDelayedOracle(0x2A9Bd515c3378e4c17067f8DDA2d384fAadC8A31);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0x44d13EA297942a49E2A0b0112D21FD132A65a06a));
    timelock = TimelockController(payable(0x43404E093C234463Fcf40dBA803ACa4FD95dFE63));
    haiDelegatee = HaiDelegatee(0xF56F8273a85Ce0D866B648632832F95F1B438726);

    tokenDistributor = TokenDistributor(0xe6F457652364a126276847Df6B75426D1B2AeADa);

    // --- utils ---
    governor = address(timelock);
  }
}

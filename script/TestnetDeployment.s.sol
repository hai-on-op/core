// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {TestnetParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/TestnetParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract TestnetDeployment is Contracts, TestnetParams {
  // NOTE: The last significant change in the Testnet deployment, to be used in the test scenarios
  uint256 constant SEPOLIA_DEPLOYMENT_BLOCK = 9_855_276;

  /**
   * @notice All the addresses that were deployed in the Testnet deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = IERC20Metadata(0xdC0EE5C3248Eac059997259c2DfC0e4bF8943097);
    collateral[STONES] = IERC20Metadata(0x056411ecF73C5be6fCeCF20330Ce3acd722aBD68);
    collateral[TOTEM] = IERC20Metadata(0x8831ee67C3aE92c35034155E6B8fb57817f337EE);

    systemCoin = SystemCoin(0xb2d541BDd0037e03d6B43490c9A72594a6c37A0f);
    protocolToken = ProtocolToken(0x05CBD1C19Af83Ab7929C8cA5000076cc0D3CeD62);

    // --- base contracts ---
    safeEngine = SAFEEngine(0xf0F6a019eDa4A0809A2Ec07d8bDB22530C8Cb9Ea);
    oracleRelayer = OracleRelayer(0x404fca0DA6C5af0bF0429153c577B05622A130aC);
    surplusAuctionHouse = SurplusAuctionHouse(0x98aAD5b0B5FAe3633d7eb38323a3DbfAFb533B23);
    debtAuctionHouse = DebtAuctionHouse(0xa81AAD12b2E18A104988F2598A53AF750B89B179);
    accountingEngine = AccountingEngine(0xb189A796cC055B5B601AD843AB1BC4Dc2d86bb70);
    liquidationEngine = LiquidationEngine(0x2F67cA5989240C651460Bafe51527Ee6aF61c511);
    coinJoin = CoinJoin(0x36942790dfe8ac1B3a9A195B1782585eceB6B70F);
    taxCollector = TaxCollector(0x37e23C8F5104398B057A6A8d00425703F7aA69aD);
    stabilityFeeTreasury = StabilityFeeTreasury(0xd07D47402bE609459059Cebaa05286D24c882fB9);
    pidController = PIDController(0x73ddca9131c5CB54227a1Ded9e84A83D4D6a958b);
    pidRateSetter = PIDRateSetter(0x3122224d48f38c4952489af9dba4f097E9fca1e3);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0xf439248215b6668018272bcF4B03E6E172472b52);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xFCCdD4B18dD2Ab02D8F0721130195e8C9C394261);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x4d551Fb5132bfDf04f4e3742b244989A70F6098d);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(address(0)); // not deployable in OP Sepolia
    uniV3RelayerFactory = UniV3RelayerFactory(address(0)); // not deployable in OP Sepolia
    denominatedOracleFactory = DenominatedOracleFactory(0x756d6fb87c5F5562Af55E72317A3aF44090f2796);
    delayedOracleFactory = DelayedOracleFactory(0x56Ab7ddB91f40125Ed1DC93dDC77c33c9c88f5BA);

    collateralJoinFactory = CollateralJoinFactory(0x13982e53958c66b0E258FB56d73bFEA95a73083B);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0xC3D1D41C1030b2B356C0f70514Cd52D4749466fe);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x1CbD8E6F6371F84ec09Ae8fA5e5E0C29B5934E61);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0xa09B2b6D4022723EE28163B944511ecfabe83cF1);

    collateralJoin[OP] = CollateralJoin(0x6057388b102A1796423F83D6B7cD28582C5B4233);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0xdEf2706aC13Ec06b1f37D7c7A07D46498b885c26);

    collateralJoin[WBTC] = CollateralJoin(0xE18BFd3Eb02D513872259D3D215AC5a50108fb03);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0xbF313874E534dD5D7D21941f735aa2BFeCDdddea);

    collateralJoin[STONES] = CollateralJoin(0xD67aDFEA76eC8A2F452fa8A8461C65DCCa694D34);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xc7a625030E3e390E89D181ef20Ac14b6B2BB77FD);

    collateralJoin[TOTEM] = CollateralJoin(0x76Cffc65Ed29D7b9E0DBD1ff6b4E14Fb4C76cAc8);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x6a2715B8f93387e17D756fe42b36CB31e45c1f2A);

    // --- jobs ---
    accountingJob = AccountingJob(0xAA36fd0627Ce73a338e60418DB392F3323B88372);
    liquidationJob = LiquidationJob(0xa4C377a782EA842537cbEa61d2d9aBe37d7D5f11);
    oracleJob = OracleJob(0x1Ba2430B65c02004f6DDD7A6b00f609F7887A074);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xc7EfEa8899fe64fC281a6f4DAC4BEF71F62bb3D5);
    safeManager = HaiSafeManager(0xaCfBe6A0321963c4F225142E5066dE520d57e7FF);

    basicActions = BasicActions(0x8131Cf71e652F783D6f7393435F68FC095044E78);
    debtBidActions = DebtBidActions(0xec1B7a4f80EfD8fB00B806Db5d2e7d1715A4D3Db);
    surplusBidActions = SurplusBidActions(0x6DaF29f356B597453b7B14e3e1E27787e732DBB2);
    collateralBidActions = CollateralBidActions(0x03E559F5E319251dd64c90505faF076230B389ce);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x6A7d730e7bb42f44eEFe02A2eC4FC9546eA887Ed);
    globalSettlementActions = GlobalSettlementActions(0xA4c6fC56aeB6F49FDba34d0C4a35AeA6570119cc);
    rewardedActions = RewardedActions(0x1516E34E02175fB3C9dE6CC2C26D4660887450B6);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0xD6f33b8bB362D5492773Fa8413b241BF6FCE21c0);
    delayedOracle[WETH] = IDelayedOracle(0x31749E86e725C8920A73e851911eB9AcE7e35506);
    delayedOracle[OP] = IDelayedOracle(0x7bD14cFC2ABfade984FF4784BF443774026E8b8a);
    delayedOracle[WBTC] = IDelayedOracle(0x00ded7f541799b80143b2d590353F745De4082c7);
    delayedOracle[STONES] = IDelayedOracle(0x0c7f6af7280E69c9Cbc5a3f86feAb0e91228DF96);
    delayedOracle[TOTEM] = IDelayedOracle(0xB14793EB180d552878d1F75DccA2911B6095dA8D);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0x894114C09E237A7e4Cc2E48E5ccA32C18D3917D9));
    timelock = TimelockController(payable(0x5bc1c8783b729eaCeEBfe01C220A12A8Dd704C15));
    haiDelegatee = HaiDelegatee(0x6bcccebe4c1C7E7DDB30a6a1415553d008555c5a);

    tokenDistributor = TokenDistributor(0xd582Cb7e38503D584E7872B18B5451AbcA2527Ac);

    // --- utils ---
    governor = address(timelock);
  }
}

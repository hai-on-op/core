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
    collateral[WBTC] = IERC20Metadata(0x83ADb8fc025D3F74Fb29D87A0aF62c3F8d5ed513);
    collateral[STONES] = IERC20Metadata(0x8d8B01B53d75da4F1D4d251b0f064d37279164C4);
    collateral[TOTEM] = IERC20Metadata(0x10FE3a8c67d9d44C57CF109f5D8F5F190D1F1f6A);

    systemCoin = SystemCoin(0xd87Dd8e541BB8027f5d7292b2096a59DCa056C76);
    protocolToken = ProtocolToken(0xbEa0B991DfA52b6935F968fEf4279ba8472326E2);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x2e7DdAddFa10E0b88fE084e2Cc2Cd8BD6c5d6a98);
    oracleRelayer = OracleRelayer(0x1c76E151DB66cD6940934E04e6a497764d335600);
    surplusAuctionHouse = SurplusAuctionHouse(0x0df99181289acB1Fc3659B008651eC510c67d342);
    debtAuctionHouse = DebtAuctionHouse(0x26ff852b0Cd3f3d202E81F177f96d0BD3A4FFF39);
    accountingEngine = AccountingEngine(0xC2F02F28228DD8DAd40AADa1DC2313073b27Ee7b);
    liquidationEngine = LiquidationEngine(0xF31A62ab4FAba23348d943ca4E4FB9394d6B8A6A);
    coinJoin = CoinJoin(0xdA31dE7569F96A435B7D1ad8c297fc89c871C228);
    taxCollector = TaxCollector(0xF444E49eA0e4026030655F55547aA65baEfcc905);
    stabilityFeeTreasury = StabilityFeeTreasury(0xAB641b9907B2daf4642B08267A0DD669213248aC);
    pidController = PIDController(0x5bB4292c97523c01C2E949c24b6E09eCF65b54c5);
    pidRateSetter = PIDRateSetter(0xC9Db770BE435457Feb4A64E4A12a08b9Fb1A9A03);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x82893F9d9e0295264B4Cc74279F7C4aF3F100d13);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x120103d3f8c35d2d283DEB689F25Ae4a27CD58E4);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x5486d6a98231d977AD5Ab90A5C3150fe304bD6C8);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(address(0)); // not deployable in OP Sepolia
    uniV3RelayerFactory = UniV3RelayerFactory(address(0)); // not deployable in OP Sepolia
    denominatedOracleFactory = DenominatedOracleFactory(0x6A54CE3F2bEf71c3bF78790bf9cCb553a9316b53);
    delayedOracleFactory = DelayedOracleFactory(0xB1ACf87611924Ad7B520dA6969C755bc9e4B8B00);

    collateralJoinFactory = CollateralJoinFactory(0x7F7a790424AC07394FC673A50746876a5aA58f4d);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x8CD7a993F6c3263b09c32686A111a0F9E8D53d45);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x49C1b389167A19e72D8840faAEDa18Fa715F3578);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x4D720Ef81C6d2e887bEFFac1392023930E863565);

    collateralJoin[OP] = CollateralJoin(0xbBCE0894Fa82497b752c9C2a8D510C6B3AA20682);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x8E2353D4A265D08EB1A2fcAF5868F79dbE7bea60);

    collateralJoin[WBTC] = CollateralJoin(0x46C4ffF889aD94793287cB9A577FeDF635a88FAE);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0xCC33Fce1cbFa9c4636D57c76ce78aF9846590E07);

    collateralJoin[STONES] = CollateralJoin(0x70d3e62C0ab3184a68CD38DA7Fe4391813283C16);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xac7B5800208A2e096F0CA1eeBa224E2740f6d87c);

    collateralJoin[TOTEM] = CollateralJoin(0x9a6E15A16E92451106D79045F5DD785F0a478680);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x1c349B5eD9e5797098419821cE777A407BE805cb);

    // --- jobs ---
    accountingJob = AccountingJob(0xF5d979D2Cc638b0d3464b699ce89fcE6d7eE5675);
    liquidationJob = LiquidationJob(0x60878b8206C9e568B1B7f81a1Cd2A0e15Fa85a73);
    oracleJob = OracleJob(0xe771c28dC4b9955f5750EBD0141a0673D1110981);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x9fc5d3Be336FFdf0A1a5e1F9ac94340Aaa66d278);
    safeManager = HaiSafeManager(0x1463a2D373111ace4A13b4B8147AE70789996556);

    basicActions = BasicActions(0x8131Cf71e652F783D6f7393435F68FC095044E78);
    debtBidActions = DebtBidActions(0x312C5DcCd2D63b3bD29342219Dcc1dE2C4aE86d4);
    surplusBidActions = SurplusBidActions(0x2EA2f271b6C0Ad3fE5412B020B6657ef158dcb57);
    collateralBidActions = CollateralBidActions(0x172931C396292ca8133c9a616a48E9252c3Be1b0);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x573025eF6dDD61f813E50b13b3730fB72d71B7B3);
    globalSettlementActions = GlobalSettlementActions(0xe7B516F27cebD5FDCCDf519E12688Ee8878356Ef);
    rewardedActions = RewardedActions(0xD1ca8E9EB98388C86e0780c0990f2a4880129ab6);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x9C4ebFF1D8fD22C111dd062EC059121538305a7d);
    delayedOracle[WETH] = IDelayedOracle(0xe5359c0F0c5A417748fd19501D79405366f6570e);
    delayedOracle[OP] = IDelayedOracle(0x94700C6f3Ae1bABd85c98255fE22fc72c90E1A47);
    delayedOracle[WBTC] = IDelayedOracle(0xa69fc9f7D8A495e8E11978a4533b003e30cb0992);
    delayedOracle[STONES] = IDelayedOracle(0x913EE0530431829a2bF42dd1Dc2E8346b6ca2510);
    delayedOracle[TOTEM] = IDelayedOracle(0x7A35bC018DF72be5ECfa5146faEAABd5cc6C1A31);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0xDEf4ee3B4Fb0df03517d457d235C4bD067659A18));
    timelock = TimelockController(payable(0xF5eB8AE7A36B1F179eF884A769c1524100173D5b));
    haiDelegatee = HaiDelegatee(0xdF19D3e87d8b60d82303Ed26C42cA6D0793E3D8F);

    tokenDistributor = TokenDistributor(0x5C7b2Cf624d94E549Ee4E419d72C8736d7B0A0CA);

    // --- utils ---
    governor = address(timelock);
  }
}

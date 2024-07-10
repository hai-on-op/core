// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {TestnetParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/TestnetParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract TestnetDeployment is Contracts, TestnetParams {
  // NOTE: The last significant change in the Testnet deployment, to be used in the test scenarios
  uint256 constant SEPOLIA_DEPLOYMENT_BLOCK = 14_257_588;

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
    collateral[WBTC] = IERC20Metadata(0x51510090D0781DD5Eab18005d22F9818d3918AE8);
    collateral[STONES] = IERC20Metadata(0x7FC853f36bA6E28FA0EBb545C0Fcda8Df5Be233e);
    collateral[TOTEM] = IERC20Metadata(0x8d6312F55Fd6401F051BeE61078554EDA53Ed77c);

    systemCoin = SystemCoin(0xc5945ac1642D592aad9076e934A7277b0a7FBAd5);
    protocolToken = ProtocolToken(0xc18dEAB90869f8F6b487B728d7DEd4AA0011663E);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x916f5FE145f963A517579354C8966e2eCe54Eb10);
    oracleRelayer = OracleRelayer(0x4dfF5A7E7D11Cb44bDAf440c8666a6dbdf48F423);
    surplusAuctionHouse = SurplusAuctionHouse(0xc0b3914534FA2754B5eADdA7Bcbad2EF82a563C2);
    debtAuctionHouse = DebtAuctionHouse(0xCb5b81fF58a86cF433A91315eC08D7f6a980Cf01);
    accountingEngine = AccountingEngine(0xE01422481eEBaD994d360a0E224e39C43c28c7b7);
    liquidationEngine = LiquidationEngine(0x4a23457c184C043420AFc796981733A5D0241Cef);
    coinJoin = CoinJoin(0x3456DD39924BBB346A07D3aD033FB5Aed3BCFBf9);
    taxCollector = TaxCollector(0x254A719Cb89f60f4966282689122a2cd2942DAFA);
    stabilityFeeTreasury = StabilityFeeTreasury(0x6B27773853b515f8B87a21b621BBA11c6968D407);
    pidController = PIDController(0x6e4F49ad9F53c043e76414A1ec03BDE165f98A8c);
    pidRateSetter = PIDRateSetter(0x939545BdEd1cB3c1658deE16D897f1C859aF10D8);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x42211672A7043a8a700A39E66295F04832742c7D);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xc6782799eA470A9A9a7EF628F12C4aA76FE9C7f0);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x8cAb67B822fFEeA8a4367c091005e6fae35Eb1af);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(address(0)); // not deployable in OP Sepolia
    uniV3RelayerFactory = UniV3RelayerFactory(address(0)); // not deployable in OP Sepolia
    denominatedOracleFactory = DenominatedOracleFactory(0xaE2C1F289e672C4F8F715F64fa5A4D18357c559B);
    delayedOracleFactory = DelayedOracleFactory(0x413F8FAA36EdB5328Fba345fb8A5309AdFb7Eba6);
    collateralJoinFactory = CollateralJoinFactory(0x8803E2cA51E83996Dc7449190Cc3b728aF072D79);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x09737e4dEBCFFA564aDA013A02E4f2293cAc901f);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xF552640005d3A81f5A0228fA6572EB661DFB59E6);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x9E2A692D9FaeD58B9a2715bBAAC34D3D2Fb94FBd);

    collateralJoin[OP] = CollateralJoin(0x7c9aBB1A0CFe9276785d1CA4C2ee523657138780);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x365ABf0DbA732fA3d4a9FF6De79ae471290F73b9);

    collateralJoin[WBTC] = CollateralJoin(0xe237c9F0A5AAab5F6bdE98d7b2bbF499014F8b8A);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x7Ec3c9E7698aAB393530206dCb11331B36F87aA3);

    collateralJoin[STONES] = CollateralJoin(0xd11e827753ef60E1bC261c52f7159C41e369D8a9);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x97Fd718BA9E0e48aD6E7995f8081f56c41cC5BF2);

    collateralJoin[TOTEM] = CollateralJoin(0xDD372fE76358726a72685d090a57db74f59432dd);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x63D705e52C118a6355a2884aa6a9B7FECee7f309);

    // --- jobs ---
    accountingJob = AccountingJob(0x6CB3bb854EcFfdF50368D6b2E079C0791425c924);
    liquidationJob = LiquidationJob(0xAF866fF6ee85f1477A4D8b194cE8f4ed386ADB42);
    oracleJob = OracleJob(0x0Ee2087F053Bb1A9B2403E7E0d9121461E5023d9);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x162E742A0f50F4abbf48e649E9404A28cdeBb980);
    safeManager = HaiSafeManager(0x013792235067658020062F01f6Fd7A5A0FC11738);

    basicActions = BasicActions(0x20FEdE658D03649d8A305b62a8B4cce82602530d);
    debtBidActions = DebtBidActions(0xB4771bF8c5Ab7DB0dEb6F7A8e3999b402d50c332);
    surplusBidActions = SurplusBidActions(0x88b68089A7696ba6C64211AbE0637BCF522d8506);
    collateralBidActions = CollateralBidActions(0xD929c49FECFA7d79fEE00b73Eff40fDEcD851F9e);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0x2aFD36f6aA9C5EA981bB345e22783De14576bCcc);
    globalSettlementActions = GlobalSettlementActions(0x2445D40DAd8722Dfb6b8269538686063c6c717f9);
    rewardedActions = RewardedActions(0xD165902e8497BE65bf57138308eAD33F95e7D0D1);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0xA6FC40713Cb3AD1d014FA5348225111E02e5be69);
    delayedOracle[WETH] = IDelayedOracle(0x2Dbb0E7566D2eD4149C43635C64d7b9D351d3361);
    delayedOracle[OP] = IDelayedOracle(0x8A7F8c60cEEcdA5774b2E969717D9197f81C5459);
    delayedOracle[WBTC] = IDelayedOracle(0x04c0901C6Ad6DCAD9466D9574f0A39800f28D916);
    delayedOracle[STONES] = IDelayedOracle(0xDbBA4efC5690e47f41F4158a1986fcB1F464ba44);
    delayedOracle[TOTEM] = IDelayedOracle(0x9DD348FD3039E674C3201A8DDF95e968FBc47aa7);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0x07D6819ADeeA2C621C8a1A3ee15eA4E219eE254b));
    timelock = TimelockController(payable(0x6de4b1B7DB22De76839F4503862A2D0810a73324));
    haiDelegatee = HaiDelegatee(0xb4ff92543Fad09B391693e7623Ef76337f1216D2);

    tokenDistributor = TokenDistributor(0x936eD7Eb6cD1F8D070C864F67f0CC860Da05D1FD);

    // --- utils ---
    governor = address(timelock);
  }
}

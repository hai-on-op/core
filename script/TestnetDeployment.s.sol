// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {TestnetParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/TestnetParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract TestnetDeployment is Contracts, TestnetParams {
  // NOTE: The last significant change in the Testnet deployment, to be used in the test scenarios
  uint256 constant SEPOLIA_DEPLOYMENT_BLOCK = 14_646_568;

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
    collateral[WBTC] = IERC20Metadata(0xbb2d454b459581E2B5F4860Dd2762C5C3C1069A5);
    collateral[STONES] = IERC20Metadata(0xB72Ff173E0B022d36604673378d450c52f438C3A);
    collateral[TOTEM] = IERC20Metadata(0x15f0AD2FacA0FB11462109a781a38d35D778324a);

    systemCoin = SystemCoin(0xd8485245e56f56B53e0c4AF4C7D7C81C76747b2e);
    protocolToken = ProtocolToken(0x47c6ae06686D35DD7656bE6AF3091Fcd626bbB2f);

    safeEngine = SAFEEngine(0x7dDB1BCEDf6b3c615768d130588Ed0fd471Fa66f);
    oracleRelayer = OracleRelayer(0x7C44077BCa5BDEB5B4123b3f25510053F7687A81);
    surplusAuctionHouse = SurplusAuctionHouse(0x2729b135f37ef272C14E1688b4FE9bF368Ba59F4);
    debtAuctionHouse = DebtAuctionHouse(0xC64D0CB32bE0c7E84720162Ec97Fd5C3201fc53b);
    accountingEngine = AccountingEngine(0x805a26C46eBf8B6815d8B81e1c488EAe4c217d47);
    liquidationEngine = LiquidationEngine(0x5c9842e9FcEf99b19E6Ec086f32C2809108a44Db);
    coinJoin = CoinJoin(0xBd68D4fc30EE2a071F85186B5240c80bCE8bC50B);
    taxCollector = TaxCollector(0x3cCC004e68886B75f27AE3f715ef02e0cE55d6aB);
    stabilityFeeTreasury = StabilityFeeTreasury(0x90dE1e1d3961A30046563Fe774b3d998b58D7741);

    pidController = PIDController(0x3bAF7CB0AF84007230295F7528BAa0f1CB17ed94);
    pidRateSetter = PIDRateSetter(0xc16cacc473A3E7c9483e3CB39a39fa4F88ACaD9e);

    globalSettlement = GlobalSettlement(0xE1514605cfd551E5c501D2538b327429881462Af);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xE1d1692a4e8a6014725eFB38E775B2425C7b80cE);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x1c48bbb32D7A5c799842d5dcFB13c1E95eD2EE02);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(address(0)); // not deployable in OP Sepolia
    uniV3RelayerFactory = UniV3RelayerFactory(address(0)); // not deployable in OP Sepolia
    denominatedOracleFactory = DenominatedOracleFactory(0x76E84f616678F3B95ED31E172ca044037A704b3D);
    delayedOracleFactory = DelayedOracleFactory(0x52FBd1B0Cab3aAd0076AaacE11c61c236D6647Ed);
    collateralJoinFactory = CollateralJoinFactory(0xfE3A12779886c32D2Ba269cf1BA5cf29Ca5528e6);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x8DEFBD846f0183acdda0Faf71701D6D5fa97ad1a);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x0078fb65304e9E047925B25a84F302e9709a36a4);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x721823161466fB9C03c03861Fa32153Acf7FfcaF);

    collateralJoin[OP] = CollateralJoin(0x2d57b9205957484839D830A38d7d7e1bd6d506F6);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x13d0d98a0e7973B034E12e239aD6BBc29E3d9Ec8);

    collateralJoin[WBTC] = CollateralJoin(0x226e60c2513C4DB44E21a4b783E0010b45Dd6A0B);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0xcd7680876f72c206fD305C30323C16A16BD6BE85);

    collateralJoin[STONES] = CollateralJoin(0xC199756dd05f99831C11ac668B5C4a44A3f56Ea3);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x318c360d491dad661DDD502d1E99A9D35BcD270b);

    collateralJoin[TOTEM] = CollateralJoin(0x6353621ed493108D104c65ab98F550Fb758055Fc);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0xF9d7F8433986D3bc468861e8668912bD29d48F4A);

    // --- jobs ---
    accountingJob = AccountingJob(0x4fcD90Ee6a041C631B6B93a52B4d94e0cEdCb1Ad);
    liquidationJob = LiquidationJob(0x50d758E014C972E73166eA87a6a7D96868Bf2859);
    oracleJob = OracleJob(0xAACc036c505370918e4A89567a636D561833bD21);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xB97a5f055285244bf11252178fb1053f035A77E5);
    safeManager = HaiSafeManager(0x0ef96c66767942ed561e4C028905D683943B7a39);

    basicActions = BasicActions(0x1929cFCB27C9cb384925B51bA6D0b53ff31eBEE5);
    debtBidActions = DebtBidActions(0x910271788cEFa5F0D4F6824bC4706d4452e25613);
    surplusBidActions = SurplusBidActions(0x6aE75AD162f5c528d65810073AB6882399877cF6);
    collateralBidActions = CollateralBidActions(0xc75F3a3EA5Bf1682219817d67e2a99cbE8a1A3DB);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0xc9D5C49B6f2020890Bc5757c35700136ef890785);
    globalSettlementActions = GlobalSettlementActions(0xf2A4303F34E35C2A36fd327096266805Dc70E2e2);
    rewardedActions = RewardedActions(0x92F42A009e0e34c1E23Bc1f08A7183EeB5D2c6Ac);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x943AdD9DBfb2F288002D4Ff9404C0b78024d81f3);
    delayedOracle[WETH] = IDelayedOracle(0xA1f4B05BC7dfde1cB1B5CC5343cFf0a93fEf9492);
    delayedOracle[OP] = IDelayedOracle(0x79960dBE32450337c7D23558f71E2e863Ce56F13);
    delayedOracle[WBTC] = IDelayedOracle(0x3097E4b364393a51fDeAb31d1423aD40668ACF6c);
    delayedOracle[STONES] = IDelayedOracle(0xd14220dE339DEACF14486c0f3293228E756aE630);
    delayedOracle[TOTEM] = IDelayedOracle(0x458057eB20175895D2598ABC313d8F2Ab0b2230a);

    // --- governance ---
    haiGovernor = HaiGovernor(payable(0x34C0CdCe8D66A559CcCCcBeB2AeabCF68182e8B9));
    timelock = TimelockController(payable(0x06F2bC32144aAbEfb5FaaB498356c9ADc56EEEaa));
    haiDelegatee = HaiDelegatee(0x8bdBebfDFb82C1A8315A8Ebe00E53b87944D7526);

    tokenDistributor = TokenDistributor(0x5684Ea6cf4A323F410a1Eb25B4A6ec8D8a93Cf24);

    // --- utils ---
    governor = address(timelock);
  }
}

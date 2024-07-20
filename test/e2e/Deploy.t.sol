// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployTestnet} from '@script/Deploy.s.sol';

import {
  ParamChecker,
  WETH,
  WSTETH,
  OP,
  WBTC,
  STONES,
  HAI_POOL_FEE_TIER,
  HAI_POOL_OBSERVATION_CARDINALITY,
  HAI_ETH_INITIAL_TICK
} from '@script/Params.s.sol';
import {UNISWAP_V3_FACTORY, OP_OPTIMISM, OP_CHAINLINK_ETH_USD_FEED} from '@script/Registry.s.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import '@script/Contracts.s.sol';
import {TestnetDeployment} from '@script/TestnetDeployment.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import 'forge-std/console.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
  uint256 _governorAccounts;

  // SAFEEngine
  // function test_SAFEEngine_Bytecode() public {
  //   assertEq(address(safeEngine).code, type(SAFEEngine).runtimeCode);
  // }

  function test_SAFEEngine_Auth() public {
    assertEq(safeEngine.authorizedAccounts(address(oracleRelayer)), true);
    assertEq(safeEngine.authorizedAccounts(address(taxCollector)), true);
    assertEq(safeEngine.authorizedAccounts(address(debtAuctionHouse)), true);
    assertEq(safeEngine.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(safeEngine.authorizedAccounts(address(globalSettlement)), true);

    assertEq(safeEngine.authorizedAccounts(address(coinJoin)), true);
    assertEq(safeEngine.authorizedAccounts(address(collateralJoinFactory)), true);

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      assertEq(safeEngine.authorizedAccounts(address(collateralJoin[collateralTypes[_i]])), true);
    }

    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));

    // 7 contracts + 1 for each collateral type (cJoin) + governor accounts
    assertEq(safeEngine.authorizedAccounts().length, 7 + collateralTypes.length + _governorAccounts);
  }

  function test_SAFEEngine_Params() public view {
    ParamChecker._checkParams(address(safeEngine), abi.encode(_safeEngineParams));
  }

  function test_SAFEEngine_CParams() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(address(safeEngine), _cType, abi.encode(_safeEngineCParams[_cType]));
    }
  }

  // OracleRelayer
  // function test_OracleRelayer_Bytecode() public {
  //     assertEq(address(oracleRelayer).code, type(OracleRelayer).runtimeCode);
  // }

  function test_OracleRelayer_Auth() public {
    assertEq(oracleRelayer.authorizedAccounts(address(pidRateSetter)), true);
    assertEq(oracleRelayer.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(oracleRelayer.authorizedAccounts().length, 2 + _governorAccounts);
  }

  function test_OracleRelayer_Params() public view {
    ParamChecker._checkParams(address(oracleRelayer), abi.encode(_oracleRelayerParams));
  }

  function test_OracleRelayer_CParams() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(address(oracleRelayer), _cType, abi.encode(_oracleRelayerCParams[_cType]));
    }
  }

  // AccountingEngine
  // function test_AccountingEngine_Bytecode() public {
  //     assertEq(
  //         address(accountingEngine).code,
  //         type(AccountingEngine).runtimeCode
  //     );
  // }

  function test_AccountingEngine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(accountingEngine.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(accountingEngine.authorizedAccounts().length, 2 + _governorAccounts);
  }

  function test_AccountingEntine_Params() public view {
    ParamChecker._checkParams(address(accountingEngine), abi.encode(_accountingEngineParams));
  }

  // SystemCoin
  // function test_SystemCoin_Bytecode_MANUAL_CHECK() public {
  //     // Not possible to check bytecode because it has immutable storage
  //     // Needs to be manually checked
  // }

  function test_SystemCoin_Auth() public {
    assertEq(systemCoin.authorizedAccounts(address(coinJoin)), true);

    // 1 contract + governor accounts
    assertEq(systemCoin.authorizedAccounts().length, 1 + _governorAccounts);
  }

  // ProtocolToken
  // function test_ProtocolToken_Bytecode_MANUAL_CHECK() public {
  //     // Not possible to check bytecode because it has immutable storage
  //     // Needs to be manually checked
  // }

  function test_ProtocolToken_Auth() public {
    assertEq(protocolToken.authorizedAccounts(address(debtAuctionHouse)), true);
    // assertEq(
    //     protocolToken.authorizedAccounts(address(tokenDistributor)),
    //     true
    // );

    // 2 contracts + governor accounts
    // NOTE: Modified to 1 from removing tokenDistributor
    // assertEq(
    //     protocolToken.authorizedAccounts().length,
    //     1 + _governorAccounts
    // );
  }

  // function test_ProtocolToken_Pausable(uint256 _wad) public {
  //     vm.assume(_wad <= type(uint208).max);

  //     vm.startPrank(deployer);
  //     protocolToken.approve(governor, _wad);
  //     changePrank(governor);

  //     protocolToken.mint(governor, _wad);

  //     vm.expectRevert(Pausable.EnforcedPause.selector);
  //     protocolToken.transfer(deployer, _wad);
  //     vm.expectRevert(Pausable.EnforcedPause.selector);
  //     protocolToken.transferFrom(deployer, governor, _wad);
  //     vm.expectRevert(Pausable.EnforcedPause.selector);
  //     protocolToken.burn(_wad);

  //     protocolToken.unpause();

  //     protocolToken.transfer(deployer, _wad);
  //     assertEq(protocolToken.balanceOf(deployer), _wad);
  //     protocolToken.transferFrom(deployer, governor, _wad);
  //     assertEq(protocolToken.balanceOf(governor), _wad);
  //     protocolToken.burn(_wad);
  //     assertEq(protocolToken.balanceOf(governor), 0);
  // }

  // SurplusAuctionHouse
  // function test_SurplusAuctionHouse_Bytecode() public {
  //     assertEq(
  //         address(surplusAuctionHouse).code,
  //         type(SurplusAuctionHouse).runtimeCode
  //     );
  // }

  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), true);

    // 1 contract + governor accounts
    assertEq(surplusAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_SurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(surplusAuctionHouse), abi.encode(_surplusAuctionHouseParams));
  }

  // DebtAuctionHouse
  // function test_DebtAuctionHouse_Bytecode() public {
  //     assertEq(
  //         address(debtAuctionHouse).code,
  //         type(DebtAuctionHouse).runtimeCode
  //     );
  // }

  function test_DebtAuctionHouse_Auth() public {
    assertEq(debtAuctionHouse.authorizedAccounts(address(accountingEngine)), true);

    // 1 contract + governor accounts
    assertEq(debtAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_DebtAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(debtAuctionHouse), abi.encode(_debtAuctionHouseParams));
  }

  // CollateralAuctionHouse
  // function test_CollateralAuctionHouseFactory_Bytecode() public {
  //     assertEq(
  //         address(collateralAuctionHouseFactory).code,
  //         type(CollateralAuctionHouseFactory).runtimeCode
  //     );
  // }

  function test_CollateralAuctionHouseFactory_Auth() public {
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(address(liquidationEngine)), true);
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(address(globalSettlement)), true);

    // 2 contracts + governor accounts
    assertEq(collateralAuctionHouseFactory.authorizedAccounts().length, 2 + _governorAccounts);
  }

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(collateralAuctionHouseFactory)), true);

      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), true);
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(governor)), true);

      // 1 contract (liquidation engine and governor are authorized in the factory)
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts().length, 1);
    }
  }

  function test_CollateralAuctionHouse_Params() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(
        address(collateralAuctionHouseFactory), _cType, abi.encode(_collateralAuctionHouseParams[_cType])
      );
    }
  }

  // CollateralJoin

  // function test_CollateralJoinFactory_Bytecode() public {
  //     assertEq(
  //         address(collateralAuctionHouseFactory).code,
  //         type(CollateralAuctionHouseFactory).runtimeCode
  //     );
  // }

  function test_CollateralJoinFactory_Auth() public {
    assertEq(collateralJoinFactory.authorizedAccounts(address(globalSettlement)), true);

    // 1 contracts + governor accounts
    assertEq(collateralJoinFactory.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_CollateralJoin_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralJoin[_cType].authorizedAccounts(address(collateralJoinFactory)), true);

      // 1 contract
      assertEq(collateralJoin[_cType].authorizedAccounts().length, 1);
    }
  }

  function test_CollateralJoin_Params() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(address(collateralJoin[_cType].collateral()), address(collateral[_cType]));
    }
  }

  // CoinJoin
  function test_CoinJoin_Auth() public {
    assertEq(coinJoin.authorizedAccounts(address(globalSettlement)), true);

    // 1 contract + governor accounts
    assertEq(coinJoin.authorizedAccounts().length, 1 + _governorAccounts);
  }

  // LiquidationEngine
  // function test_LiquidationEngine_Bytecode() public {
  //     assertEq(
  //         address(liquidationEngine).code,
  //         type(LiquidationEngine).runtimeCode
  //     );
  // }

  function test_LiquidationEngine_Auth() public {
    assertEq(liquidationEngine.authorizedAccounts(address(globalSettlement)), true);

    // 1 contract + 1 per collateralType + governor accounts
    assertEq(liquidationEngine.authorizedAccounts().length, 1 + collateralTypes.length + _governorAccounts);
  }

  function test_LiquidationEngine_Params() public view {
    ParamChecker._checkParams(address(liquidationEngine), abi.encode(_liquidationEngineParams));
  }

  function test_LiquidationEngine_CParams() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(address(liquidationEngine), _cType, abi.encode(_liquidationEngineCParams[_cType]));
    }
  }

  // PIDController
  // function test_PIDController_Bytecode() public {
  //     assertEq(address(pidController).code, type(PIDController).runtimeCode);
  // }

  function test_PIDController_Auth() public {
    // only governor
    assertEq(pidController.authorizedAccounts().length, _governorAccounts);
  }

  function test_PIDController_Params() public view {
    ParamChecker._checkParams(address(pidController), abi.encode(_pidControllerParams));
  }

  // PIDRateSetter
  // function test_PIDRateSetter_Bytecode() public {
  //     assertEq(address(pidRateSetter).code, type(PIDRateSetter).runtimeCode);
  // }

  function test_PIDRateSetter_Auth() public {
    // only governor
    assertEq(pidRateSetter.authorizedAccounts().length, _governorAccounts);
  }

  function test_PIDRateSetter_Params() public view {
    ParamChecker._checkParams(address(pidRateSetter), abi.encode(_pidRateSetterParams));
  }

  // TaxCollector
  // function test_TaxCollector_Bytecode() public {
  //     assertEq(address(taxCollector).code, type(TaxCollector).runtimeCode);
  // }

  function test_TaxCollector_Auth() public {
    // only governor
    assertEq(taxCollector.authorizedAccounts().length, _governorAccounts);
  }

  function test_TaxCollector_Params() public view {
    ParamChecker._checkParams(address(taxCollector), abi.encode(_taxCollectorParams));
  }

  function test_TaxCollector_CParams() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(address(taxCollector), _cType, abi.encode(_taxCollectorCParams[_cType]));
    }
  }

  // StabilityFeeTreasury
  // function test_StabilityFeeTreasury_Bytecode() public {
  //     assertEq(
  //         address(stabilityFeeTreasury).code,
  //         type(StabilityFeeTreasury).runtimeCode
  //     );
  // }

  function test_StabilityFeeTreasury_Auth() public {
    assertEq(stabilityFeeTreasury.authorizedAccounts(address(globalSettlement)), true);

    // 1 contract + governor accounts
    assertEq(stabilityFeeTreasury.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_StabilityFeeTreasury_Params() public view {
    ParamChecker._checkParams(address(stabilityFeeTreasury), abi.encode(_stabilityFeeTreasuryParams));
  }

  // GlobalSettlement
  // function test_GlobalSettlement_Bytecode() public {
  //     assertEq(
  //         address(globalSettlement).code,
  //         type(GlobalSettlement).runtimeCode
  //     );
  // }

  function test_GlobalSettlement_Auth() public {
    // only governor
    assertEq(globalSettlement.authorizedAccounts().length, _governorAccounts);
  }

  function test_GlobalSettlement_Params() public view {
    ParamChecker._checkParams(address(globalSettlement), abi.encode(_globalSettlementParams));
  }

  // PostSettlementSurplusAuctionHouse
  // function test_PostSettlementSurplusAuctionHouse_Bytecode() public {
  //     assertEq(
  //         address(postSettlementSurplusAuctionHouse).code,
  //         type(PostSettlementSurplusAuctionHouse).runtimeCode
  //     );
  // }

  function test_PostSettlementSurplusAuctionHouse_Auth() public {
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts(address(settlementSurplusAuctioneer)), true);

    // 1 contract + governor accounts
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts().length, 1 + _governorAccounts);
  }

  function test_PostSettlementSurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(postSettlementSurplusAuctionHouse), abi.encode(_postSettlementSAHParams));
  }

  // PostSettlementAuctioneer
  // function test_PostSettlementAuctioneer_Bytecode() public {
  //     assertEq(
  //         address(settlementSurplusAuctioneer).code,
  //         type(SettlementSurplusAuctioneer).runtimeCode
  //     );
  // }

  function test_PostSettlementAuctioneer_Auth() public {
    // only governor
    assertEq(settlementSurplusAuctioneer.authorizedAccounts().length, _governorAccounts);
  }

  // Governance checks
  function test_Grant_Auth() public {
    _test_Authorizations(governor, true);
    if (delegate != address(0)) _test_Authorizations(delegate, true);
    _test_Authorizations(deployer, false);
  }

  // function test_Timelock_Bytecode() public {
  //     assertEq(address(timelock).code, type(TimelockController).runtimeCode);
  // }

  function test_Timelock_Auth() public {
    assertEq(timelock.hasRole(keccak256('PROPOSER_ROLE'), address(haiGovernor)), true);
    assertEq(timelock.hasRole(keccak256('CANCELLER_ROLE'), address(haiGovernor)), true);
    assertEq(timelock.hasRole(keccak256('EXECUTOR_ROLE'), address(haiGovernor)), true);
  }

  function test_Timelock_Params() public {
    assertEq(timelock.getMinDelay(), _governorParams.timelockMinDelay);
  }

  // function test_HaiGovernor_Bytecode_MANUAL_CHECK() public {
  //     // Not possible to check bytecode because it has immutable storage
  //     // Needs to be manually checked
  // }

  function test_HaiGovernor_Params() public {
    assertEq(haiGovernor.votingDelay(), _governorParams.votingDelay);
    assertEq(haiGovernor.votingPeriod(), _governorParams.votingPeriod);
    assertEq(haiGovernor.proposalThreshold(), _governorParams.proposalThreshold);

    assertEq(address(haiGovernor.token()), address(protocolToken));
    assertEq(address(haiGovernor.timelock()), address(timelock));
  }

  // TokenDistributor
  // function test_TokenDistributor_Bytecode() public {
  //     assertEq(
  //         address(tokenDistributor).code,
  //         type(TokenDistributor).runtimeCode
  //     );
  // }

  // function test_TokenDistributor_Params() public {
  //     assertEq(tokenDistributor.root(), _tokenDistributorParams.root);
  //     assertEq(
  //         tokenDistributor.totalClaimable(),
  //         _tokenDistributorParams.totalClaimable
  //     );
  //     // NOTE: (deployment)block.timestamp + 1 days (cannot be tested)
  //     // assertEq(tokenDistributor.claimPeriodStart(), _tokenDistributorParams.claimPeriodStart);
  //     assertEq(
  //         tokenDistributor.claimPeriodEnd(),
  //         _tokenDistributorParams.claimPeriodEnd
  //     );
  // }

  function test_Delegated_OP() public {
    assertEq(ERC20Votes(OP_OPTIMISM).delegates(address(collateralJoin[OP])), address(haiDelegatee));
  }

  function _test_Authorizations(address _target, bool _permission) internal {
    if (_permission) {
      _toAllAuthorizableContracts(_fn_HasAuthorizations, _target);
    } else {
      _toAllAuthorizableContracts(_fn_NoAuthorizations, _target);
    }
  }

  function _fn_NoAuthorizations(IAuthorizable _contract, address _target) internal {
    assertEq(_contract.authorizedAccounts(_target), false);
  }

  function _fn_HasAuthorizations(IAuthorizable _contract, address _target) internal {
    assertEq(_contract.authorizedAccounts(_target), true);
  }
}

contract E2EDeploymentMainnetTest is DeployMainnet, CommonDeploymentTest {
  uint256 FORK_BLOCK = 122_704_223;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    super.setUp();
    run();

    // Initialize HAI/WETH UniV3 pool (already deployed in _setupPostEnvironment)
    _deployUniV3Pool(
      UNISWAP_V3_FACTORY,
      address(collateral[WETH]),
      address(systemCoin),
      HAI_POOL_FEE_TIER,
      HAI_POOL_OBSERVATION_CARDINALITY,
      HAI_ETH_INITIAL_TICK // 2000 HAI = 1 ETH
    );

    // NOTE: setup [ UniV3 HAI/WETH + Chainlink ETH/USD ] oracle through governance actions
    vm.startPrank(governor);
    // grab the last denominated oracle deployed (in _setupPostEnvironment)
    address[] memory _denominatedOracles = denominatedOracleFactory.denominatedOraclesList();
    systemCoinOracle = IBaseOracle(_denominatedOracles[_denominatedOracles.length - 1]);
    // assert we grabbed the correct oracle
    assertEq(systemCoinOracle.symbol(), '(HAI / WETH) * (ETH / USD)');

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));

    vm.stopPrank();

    _governorAccounts = 1; // no delegate on production
  }

  function setupEnvironment() public override(DeployMainnet, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeployMainnet, Deploy) {
    super.setupPostEnvironment();
  }

  function test_pid_update_rate() public {
    _refreshChainlinkFeed(OP_CHAINLINK_ETH_USD_FEED, 2000e8);

    vm.expectRevert(IPIDRateSetter.PIDRateSetter_InvalidPriceFeed.selector);
    pidRateSetter.updateRate();

    skip(1 days);
    _refreshChainlinkFeed(OP_CHAINLINK_ETH_USD_FEED, 2000e8);

    pidRateSetter.updateRate();

    vm.expectRevert(IPIDRateSetter.PIDRateSetter_RateSetterCooldown.selector);
    pidRateSetter.updateRate();

    uint256 _updateRateDelay = pidRateSetter.params().updateRateDelay;
    skip(_updateRateDelay);
    _refreshChainlinkFeed(OP_CHAINLINK_ETH_USD_FEED, 2000e8);

    pidRateSetter.updateRate();
  }

  function test_system_coin_oracle() public {
    vm.warp(block.timestamp + 1 days);
    (uint256 _quote,) = systemCoinOracle.getResultWithValidity();

    assertEq(systemCoinOracle.symbol(), '(HAI / WETH) * (ETH / USD)');

    // NOTE: Temporarily disabled
    // assertEq(_quote > 1e18 ? _quote / 1e17 : 1e19 / _quote, 10); // 1.0 HAI = 1.0 USD
  }

  function _refreshChainlinkFeed(address _chainlinkFeed, uint256 _quote) internal {
    vm.mockCall(
      _chainlinkFeed,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(1), _quote, uint256(0), uint256(block.timestamp - 1), uint64(0))
    );
  }
}

contract MainnetOnchainConfigTest is MainnetDeployment, CommonDeploymentTest {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), MAINNET_DEPLOYMENT_BLOCK);
    _getEnvironmentParams();

    // there is 1 governor accounts (timelock)
    _governorAccounts = 1;
  }
}

contract E2EDeploymentTestnetTest is DeployTestnet, CommonDeploymentTest {
  // uint256 FORK_BLOCK = 7_000_000;
  uint256 FORK_BLOCK = 14_146_392;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('testnet'), FORK_BLOCK);
    super.setUp();
    run();

    // if there is a delegate, there are 2 governor accounts
    _governorAccounts = delegate == address(0) ? 1 : 2;
  }

  function setupEnvironment() public override(DeployTestnet, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeployTestnet, Deploy) {
    super.setupPostEnvironment();
  }
}

contract TestnetOnchainConfigTest is TestnetDeployment, CommonDeploymentTest {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('testnet'), SEPOLIA_DEPLOYMENT_BLOCK);
    _getEnvironmentParams();
    deployer = address(420);

    // if there is a delegate, there are 2 governor accounts
    _governorAccounts = 2;
  }
}

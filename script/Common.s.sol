// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import '@script/Registry.s.sol';

import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

abstract contract Common is Contracts, Params {
  uint256 internal _deployerPk = 69; // for tests
  uint256 internal _governorPK;

  function deployTokens() public updateParams {
    systemCoin = new SystemCoin('HAI Index Token', 'HAI');
    protocolToken = new ProtocolToken('Protocol Token', 'KITE');
  }

  function deployGovernance() public updateParams {
    IHaiGovernor.HaiGovernorParams memory _emptyGovernorParams;
    // if governor params are not empty, deploy governor
    if (keccak256(abi.encode(_governorParams)) != keccak256(abi.encode(_emptyGovernorParams))) {
      haiGovernor = new HaiGovernor(protocolToken, 'HaiGovernor', _governorParams);

      timelock = TimelockController(payable(haiGovernor.timelock()));

      haiDelegatee = new HaiDelegatee(address(timelock));

      // sets timelock as protocol governor
      governor = address(timelock);
    }
  }

  function deployContracts() public updateParams {
    // deploy Base contracts
    safeEngine = new SAFEEngine(_safeEngineParams);

    oracleRelayer = new OracleRelayer(address(safeEngine), systemCoinOracle, _oracleRelayerParams);

    surplusAuctionHouse =
      new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _surplusAuctionHouseParams);

    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    accountingEngine = new AccountingEngine(
      address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse), _accountingEngineParams
    );

    liquidationEngine = new LiquidationEngine(address(safeEngine), address(accountingEngine), _liquidationEngineParams);

    collateralAuctionHouseFactory =
      new CollateralAuctionHouseFactory(address(safeEngine), address(liquidationEngine), address(oracleRelayer));

    // deploy Token adapters
    coinJoin = new CoinJoin(address(safeEngine), address(systemCoin));

    collateralJoinFactory = new CollateralJoinFactory(address(safeEngine));
  }

  function deployTaxModule() public updateParams {
    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    stabilityFeeTreasury = new StabilityFeeTreasury(
      address(safeEngine), address(accountingEngine), address(coinJoin), _stabilityFeeTreasuryParams
    );
  }

  function _setupContracts() internal {
    // auth
    safeEngine.addAuthorization(address(oracleRelayer)); // modifyParameters
    safeEngine.addAuthorization(address(coinJoin)); // transferInternalCoins
    safeEngine.addAuthorization(address(taxCollector)); // updateAccumulatedRate
    safeEngine.addAuthorization(address(debtAuctionHouse)); // transferInternalCoins [createUnbackedDebt]
    safeEngine.addAuthorization(address(liquidationEngine)); // confiscateSAFECollateralAndDebt
    surplusAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    debtAuctionHouse.addAuthorization(address(accountingEngine)); // startAuction
    accountingEngine.addAuthorization(address(liquidationEngine)); // pushDebtToQueue
    protocolToken.addAuthorization(address(debtAuctionHouse)); // mint
    systemCoin.addAuthorization(address(coinJoin)); // mint

    safeEngine.addAuthorization(address(collateralJoinFactory)); // addAuthorization(cJoin child)
  }

  function deployGlobalSettlement() public updateParams {
    globalSettlement = new GlobalSettlement(
      address(safeEngine),
      address(liquidationEngine),
      address(oracleRelayer),
      address(coinJoin),
      address(collateralJoinFactory),
      address(collateralAuctionHouseFactory),
      address(stabilityFeeTreasury),
      address(accountingEngine),
      _globalSettlementParams
    );

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken), _postSettlementSAHParams);

    settlementSurplusAuctioneer =
      new SettlementSurplusAuctioneer(address(accountingEngine), address(postSettlementSurplusAuctionHouse));
  }

  function _setupGlobalSettlement() internal {
    // setup globalSettlement [auth: disableContract]
    safeEngine.addAuthorization(address(globalSettlement));
    liquidationEngine.addAuthorization(address(globalSettlement));
    stabilityFeeTreasury.addAuthorization(address(globalSettlement));
    accountingEngine.addAuthorization(address(globalSettlement));
    oracleRelayer.addAuthorization(address(globalSettlement));
    coinJoin.addAuthorization(address(globalSettlement));
    collateralJoinFactory.addAuthorization(address(globalSettlement));
    collateralAuctionHouseFactory.addAuthorization(address(globalSettlement)); // [+ terminateAuctionPrematurely]

    // registry
    accountingEngine.modifyParameters('postSettlementSurplusDrain', abi.encode(settlementSurplusAuctioneer));

    // auth
    postSettlementSurplusAuctionHouse.addAuthorization(address(settlementSurplusAuctioneer)); // startAuction
  }

  function deployPIDController() public updateParams {
    pidController = new PIDController({
      _cGains: _pidControllerGains,
      _pidParams: _pidControllerParams,
      _importedState: IPIDController.DeviationObservation(0, 0, 0)
    });

    pidRateSetter = new PIDRateSetter({
      _oracleRelayer: address(oracleRelayer),
      _pidCalculator: address(pidController),
      _pidRateSetterParams: _pidRateSetterParams
    });
  }

  function _setupPIDController() internal {
    // setup registry
    pidController.modifyParameters('seedProposer', abi.encode(pidRateSetter));

    // auth
    oracleRelayer.addAuthorization(address(pidRateSetter));
  }

  function deployJobContracts() public updateParams {
    accountingJob = new AccountingJob(address(accountingEngine), address(stabilityFeeTreasury), JOB_REWARD);
    liquidationJob = new LiquidationJob(address(liquidationEngine), address(stabilityFeeTreasury), JOB_REWARD);
    oracleJob = new OracleJob(address(oracleRelayer), address(pidRateSetter), address(stabilityFeeTreasury), JOB_REWARD);
  }

  function _setupJobContracts() internal {
    stabilityFeeTreasury.setTotalAllowance(address(accountingJob), type(uint256).max);
    stabilityFeeTreasury.setTotalAllowance(address(liquidationJob), type(uint256).max);
    stabilityFeeTreasury.setTotalAllowance(address(oracleJob), type(uint256).max);
  }

  function deployCollateralContracts(bytes32 _cType) public updateParams {
    // deploy CollateralJoin and CollateralAuctionHouse
    address _delegatee = delegatee[_cType];
    if (_delegatee == address(0)) {
      collateralJoin[_cType] =
        collateralJoinFactory.deployCollateralJoin({_cType: _cType, _collateral: address(collateral[_cType])});
    } else {
      collateralJoin[_cType] = collateralJoinFactory.deployDelegatableCollateralJoin({
        _cType: _cType,
        _collateral: address(collateral[_cType]),
        _delegatee: _delegatee
      });
    }

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(_collateralAuctionHouseParams[_cType]));
    collateralAuctionHouse[_cType] =
      ICollateralAuctionHouse(collateralAuctionHouseFactory.collateralAuctionHouses(_cType));
  }

  function _setupCollateral(bytes32 _cType) internal {
    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams[_cType]));
    oracleRelayer.initializeCollateralType(_cType, abi.encode(_oracleRelayerCParams[_cType]));
    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liquidationEngineCParams[_cType]));

    taxCollector.initializeCollateralType(_cType, abi.encode(_taxCollectorCParams[_cType]));

    for (uint256 _i; _i < _taxCollectorSecondaryTaxReceiver.length; _i++) {
      taxCollector.modifyParameters(_cType, 'secondaryTaxReceiver', abi.encode(_taxCollectorSecondaryTaxReceiver[_i]));
    }

    // setup initial price
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function deployProxyContracts(address _safeEngine) public updateParams {
    proxyFactory = new HaiProxyFactory();
    safeManager = new HaiSafeManager(_safeEngine);
    _deployProxyActions();
  }

  function _deployProxyActions() internal {
    basicActions = new BasicActions();
    debtBidActions = new DebtBidActions();
    surplusBidActions = new SurplusBidActions();
    collateralBidActions = new CollateralBidActions();
    postSettlementSurplusBidActions = new PostSettlementSurplusBidActions();
    globalSettlementActions = new GlobalSettlementActions();
    rewardedActions = new RewardedActions();
  }

  function deployTokenDistributor() public updateParams {
    ITokenDistributor.TokenDistributorParams memory _emptyTokenDistributorParams;
    // if token distributor params are not empty, deploy token distributor
    if (keccak256(abi.encode(_tokenDistributorParams)) != keccak256(abi.encode(_emptyTokenDistributorParams))) {
      // Deploy aidrop distributor contract
      tokenDistributor = new TokenDistributor(address(protocolToken), _tokenDistributorParams);

      // auth
      protocolToken.addAuthorization(address(tokenDistributor)); // mint
    }
  }

  function _deployUniV3Pool(
    address _uniV3Factory,
    address _tokenA,
    address _tokenB,
    uint24 _fee,
    uint16 _cardinality,
    int24 _initialTick
  ) internal {
    address _uniV3Pool = IUniswapV3Factory(_uniV3Factory).getPool(_tokenA, _tokenB, _fee);
    if (_uniV3Pool == address(0)) {
      _uniV3Pool = IUniswapV3Factory(_uniV3Factory).createPool({tokenA: _tokenA, tokenB: _tokenB, fee: _fee});
    }

    address _token0 = IUniswapV3Pool(_uniV3Pool).token0();
    uint160 _sqrtPriceX96 = _token0 == address(_tokenA)
      ? TickMath.getSqrtRatioAtTick(_initialTick)
      : TickMath.getSqrtRatioAtTick(-_initialTick);

    IUniswapV3Pool(_uniV3Pool).initialize(_sqrtPriceX96);

    for (uint256 _i = 500; _i <= _cardinality; _i += 500) {
      IUniswapV3Pool(_uniV3Pool).increaseObservationCardinalityNext(uint16(_i));
    }
    if (_cardinality % 500 != 0) {
      IUniswapV3Pool(_uniV3Pool).increaseObservationCardinalityNext(_cardinality);
    }
  }

  function _revokeDeployerToAll(address _governor) internal {
    if (!_shouldRevoke()) return;

    _toAllAuthorizableContracts(_revokeDeployerTo, _governor);
  }

  function _revokeDeployerTo(IAuthorizable _contract, address _governor) internal {
    _contract.addAuthorization(_governor);
    _contract.removeAuthorization(deployer);
  }

  function _shouldRevoke() internal view returns (bool) {
    return governor != deployer && governor != address(0);
  }

  function _delegateToAll(address _delegate) internal {
    _toAllAuthorizableContracts(_delegateTo, _delegate);
  }

  function _delegateTo(IAuthorizable _contract, address _delegate) internal {
    _contract.addAuthorization(_delegate);
  }

  function _toAllAuthorizableContracts(function (IAuthorizable, address) internal _function, address _target) internal {
    // base contracts
    _function(safeEngine, _target);
    _function(liquidationEngine, _target);
    _function(accountingEngine, _target);
    _function(oracleRelayer, _target);

    // auction houses
    _function(surplusAuctionHouse, _target);
    _function(debtAuctionHouse, _target);

    // tax
    _function(taxCollector, _target);
    _function(stabilityFeeTreasury, _target);

    // tokens
    _function(systemCoin, _target);
    _function(protocolToken, _target);

    // pid controller
    _function(pidController, _target);
    _function(pidRateSetter, _target);

    // token adapters
    _function(coinJoin, _target);

    // factories or children
    // NOTE: not deployable on Sepolia testnet
    if (address(chainlinkRelayerFactory) != address(0)) _function(chainlinkRelayerFactory, _target);
    if (address(uniV3RelayerFactory) != address(0)) _function(uniV3RelayerFactory, _target);
    _function(denominatedOracleFactory, _target);
    _function(delayedOracleFactory, _target);

    _function(collateralJoinFactory, _target);
    _function(collateralAuctionHouseFactory, _target);

    // global settlement
    _function(globalSettlement, _target);
    _function(postSettlementSurplusAuctionHouse, _target);
    _function(settlementSurplusAuctioneer, _target);

    // jobs
    _function(accountingJob, _target);
    _function(liquidationJob, _target);
    _function(oracleJob, _target);

    // token distributor
    if (address(tokenDistributor) != address(0)) _function(tokenDistributor, _target);
  }

  modifier updateParams() {
    _getEnvironmentParams();
    _;
    _getEnvironmentParams();
  }
}

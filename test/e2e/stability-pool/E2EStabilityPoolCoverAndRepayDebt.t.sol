// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {StabilityPool} from '@contracts/stability-pool/StabilityPool.sol';
import {EmissionsController} from '@contracts/stability-pool/EmissionsController.sol';
import {StabilityPoolCoverJob} from '@contracts/jobs/StabilityPoolCoverJob.sol';
import {StabilityPoolSweepJob} from '@contracts/jobs/StabilityPoolSweepJob.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStabilityPoolCoverJob} from '@interfaces/jobs/IStabilityPoolCoverJob.sol';
import {IStabilityPoolSweepJob} from '@interfaces/jobs/IStabilityPoolSweepJob.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IWeth} from '@interfaces/external/IWeth.sol';
import {CurveStableSwapNGRelayer} from '@contracts/oracles/CurveStableSwapNGRelayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {ERC4626ShareOracle} from '@contracts/oracles/ERC4626ShareOracle.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';

contract E2EStabilityPoolCoverAndRepayDebtForkTest is HaiTest, MainnetDeployment {
  uint256 internal constant FORK_BLOCK = 148_368_730;
  uint256 internal constant DEFAULT_MAX_QUOTE_STEPS = 4096;

  uint256 internal constant TOTAL_KITE = 1_000_000e18;
  uint256 internal constant DEVIATION_LIMIT = 0.1e18;
  uint256 internal constant EMISSIONS_DURATION = 365 days;
  uint256 internal constant POOL_HAI_DEPOSIT = 50_000e18;
  uint256 internal constant DEAD_SHARES_SEED = 1000e18;

  bytes32 internal constant WETH_CTYPE = bytes32('WETH');
  bytes32 internal constant RETH_CTYPE = bytes32('RETH');
  bytes32 internal constant MOO_VELO_BOLD_LUSD_CTYPE = bytes32('MOO-VELO-BOLD-LUSD');
  bytes32 internal constant YV_VELO_ALETH_WETH_CTYPE = bytes32('YV-VELO-ALETH-WETH');
  bytes32 internal constant OP_CTYPE = bytes32('OP');

  address internal constant VELO_CL_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
  address internal constant WETH = 0x4200000000000000000000000000000000000006;
  address internal constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address internal constant BOLD = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant HAI = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant RETH = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D;
  address internal constant WA_OPT_WETH = 0x464b808c2C7E04b07e860fDF7a91870620246148;
  address internal constant ALETH = 0x3E29D3A9316dAB217754d13b28646B76607c5f04;
  address internal constant LUSD = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;

  address internal constant VELO_CL_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;
  address internal constant VELO_CL_POOL_WETH_USDC = 0x478946BcD4a5a22b316470F5486fAfb928C0bA25;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant CURVE_BOLD_HAI_POOL = 0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5;
  address internal constant BALANCER_V3_ROUTER = 0x84813aA3e079A665C0B80F944427eE83cBA63617;
  address internal constant BALANCER_V3_RETH_WA_OPT_WETH_POOL = 0x870c0Af8A1af0B58b4b0bD31CE4fe72864ae45BE;
  address internal constant BOLD_LUSD_VELO_POOL = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;
  address internal constant ALETH_WETH_VELO_POOL = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;
  address internal constant BOLD_LUSD_VELO_BEEFY_VAULT = 0xC06C0A19d0A3eD7B3BA9D7c3101B6BC9634b84a9;
  address internal constant ALETH_WETH_YEARN_VAULT = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;

  address internal constant HAI_USD_ORACLE = 0x8c212bCaE328669c8b045D467CB78b88e0BE0D39;
  address internal constant RETH_USD_ORACLE = 0xB43314DBdb9b8036E7012A3cDc267E2105Ee8740;
  address internal constant WETH_USD_ORACLE = 0x2fC0cb2c5065a79bC2db79e4fbD537b7CaCF6f36;
  uint16 internal constant BALANCER_ORACLE_TOLERANCE_BPS = 200;
  uint16 internal constant CURVE_ORACLE_TOLERANCE_BPS = 200;

  uint256 internal constant SAFE_WETH_COLLATERAL_WEI = 3e18;
  uint256 internal constant SAFE_RETH_COLLATERAL_WEI = 3e18;
  uint256 internal constant SAFE_MOO_BOLD_LUSD_COLLATERAL_WEI = 250e18;
  uint256 internal constant SAFE_YV_ALETH_WETH_COLLATERAL_WEI = 250e18;
  uint256 internal constant TARGET_SAFE_DEBT = 500e18;
  uint256 internal constant TARGET_SAFE_DEBT_SMALL = 200e18;
  uint256 internal constant LIQUIDATION_PRICE = 100e18;
  uint256 internal constant LOW_LIQUIDATION_PRICE = 1e10;

  address internal testDeployer = label('testDeployer');
  address internal depositor = label('depositor');
  address internal safeOwner = label('safeOwner');
  address internal safeOwnerTwo = label('safeOwnerTwo');
  address internal safeOwnerThree = label('safeOwnerThree');
  address internal safeOwnerFour = label('safeOwnerFour');
  address internal keeper = label('keeper');

  EmissionsController internal emissionsController;
  StabilityPool internal stabilityPool;
  StabilityPoolCoverJob internal stabilityPoolCoverJob;
  StabilityPoolSweepJob internal stabilityPoolSweepJob;

  BalancerV3StablePoolMathSwapStep internal balancerV3Step;
  ERC4626WithdrawalStep internal erc4626Step;
  VeloCLSwapStepViewQuoter internal veloCLStep;
  VeloSwapStep internal veloSwapStep;
  VeloLPRemoveAndSwapStep internal veloLPRemoveAndSwapStep;
  BeefyVaultWithdrawalStep internal beefyStep;
  YearnVaultWithdrawalStep internal yearnStep;
  CurveSwapStep internal curveStep;
  DenominatedOracle internal boldUsdOracle;
  ERC4626ShareOracle internal waOptWethUsdOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    vm.prank(address(timelock));
    try protocolToken.unpause() {} catch {}

    vm.startPrank(testDeployer);
    emissionsController = new EmissionsController(
      IERC20(address(protocolToken)), oracleRelayer, testDeployer, TOTAL_KITE, EMISSIONS_DURATION, DEVIATION_LIMIT
    );
    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      address(oracleRelayer),
      address(emissionsController),
      address(coinJoin),
      address(collateralJoinFactory),
      address(collateralAuctionHouseFactory)
    );
    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    balancerV3Step = new BalancerV3StablePoolMathSwapStep();
    erc4626Step = new ERC4626WithdrawalStep();
    veloCLStep = new VeloCLSwapStepViewQuoter(DEFAULT_MAX_QUOTE_STEPS);
    veloSwapStep = new VeloSwapStep();
    veloLPRemoveAndSwapStep = new VeloLPRemoveAndSwapStep();
    beefyStep = new BeefyVaultWithdrawalStep();
    yearnStep = new YearnVaultWithdrawalStep();
    curveStep = new CurveSwapStep();
    IBaseOracle _haiBoldOracle = new CurveStableSwapNGRelayer(CURVE_BOLD_HAI_POOL, 0, 1);
    boldUsdOracle = new DenominatedOracle(_haiBoldOracle, IBaseOracle(HAI_USD_ORACLE), true);
    waOptWethUsdOracle = new ERC4626ShareOracle(IERC4626(WA_OPT_WETH), IBaseOracle(WETH_USD_ORACLE), 'waOptWETH / USD');

    stabilityPool.setStepWhitelist(address(balancerV3Step), true);
    stabilityPool.setStepWhitelist(address(erc4626Step), true);
    stabilityPool.setStepWhitelist(address(veloCLStep), true);
    stabilityPool.setStepWhitelist(address(veloSwapStep), true);
    stabilityPool.setStepWhitelist(address(veloLPRemoveAndSwapStep), true);
    stabilityPool.setStepWhitelist(address(beefyStep), true);
    stabilityPool.setStepWhitelist(address(yearnStep), true);
    stabilityPool.setStepWhitelist(address(curveStep), true);
    stabilityPool.setStrategySteps(WETH_CTYPE, _wethPipeline());

    stabilityPoolCoverJob = new StabilityPoolCoverJob(address(stabilityPool), address(stabilityFeeTreasury), 1e18);
    stabilityPoolSweepJob = new StabilityPoolSweepJob(address(stabilityPool), address(stabilityFeeTreasury), 1e18);
    vm.stopPrank();

    vm.startPrank(address(timelock));
    stabilityFeeTreasury.setTotalAllowance(address(stabilityPoolCoverJob), type(uint256).max);
    stabilityFeeTreasury.setTotalAllowance(address(stabilityPoolSweepJob), type(uint256).max);
    vm.stopPrank();

    // Ensure OP has a non-empty strategy to hit collateral-type mismatch branch.
    vm.prank(testDeployer);
    stabilityPool.setStrategySteps(OP_CTYPE, _wethPipeline());

    deal(address(protocolToken), address(emissionsController), TOTAL_KITE);
    deal(address(systemCoin), testDeployer, DEAD_SHARES_SEED);
    deal(address(systemCoin), depositor, POOL_HAI_DEPOSIT);

    vm.startPrank(testDeployer);
    systemCoin.approve(address(stabilityPool), DEAD_SHARES_SEED);
    stabilityPool.seedDeadShares(DEAD_SHARES_SEED);
    vm.stopPrank();

    vm.startPrank(depositor);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
    stabilityPool.deposit(POOL_HAI_DEPOSIT, depositor);
    vm.stopPrank();
  }

  function test_cover_and_repay_debt_weth_auction_executes_and_repays() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);
    _runCoverAndRepayFlow(_auctionHouse, _auctionId, WETH_CTYPE);
  }

  function test_cover_and_repay_debt_reth_auction_executes_and_repays() public {
    _setStrategySteps(RETH_CTYPE, _rethPipeline());

    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(RETH_CTYPE, safeOwner, RETH, SAFE_RETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, false);
    _runCoverAndRepayFlow(_auctionHouse, _auctionId, RETH_CTYPE);
  }

  function test_cover_and_repay_debt_job_rewards_keeper_on_profitable_cover() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    uint256 _startTime = block.timestamp;
    uint256[8] memory _ageOffsets =
      [uint256(6 hours), 12 hours, 18 hours, 24 hours, 36 hours, 48 hours, 72 hours, 96 hours];
    uint256 _bidAmount;
    uint256 _estimatedAdjustedBid;
    uint256 _expectedHai;
    for (uint256 _i = 0; _i < _ageOffsets.length; _i++) {
      vm.warp(_startTime + _ageOffsets[_i]);
      (_bidAmount, _estimatedAdjustedBid, _expectedHai) = _findProfitableBid(_auctionHouse, _auctionId, WETH_CTYPE);
      if (_estimatedAdjustedBid > 0) break;
    }
    if (_estimatedAdjustedBid == 0) revert('no profitable bid found');
    assertGe(_expectedHai, _estimatedAdjustedBid);

    uint256 _poolHaiBefore = systemCoin.balanceOf(address(stabilityPool));
    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.prank(keeper);
    int256 _profit = stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, WETH_CTYPE);

    assertGt(_profit, 0);
    assertEq(systemCoin.balanceOf(address(stabilityPool)), _poolHaiBefore + uint256(_profit));
    assertGt(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_cover_and_repay_debt_job_reverts_without_reward_on_non_positive_profit() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    uint256 _bidAmount = 1e18;
    vm.mockCall(
      _auctionHouse,
      abi.encodeWithSelector(ICollateralAuctionHouse.getCollateralBought.selector, _auctionId, _bidAmount),
      abi.encode(uint256(0), uint256(0))
    );

    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.expectRevert(IStabilityPoolCoverJob.StabilityPoolCoverJob_NonPositiveProfit.selector);
    vm.prank(keeper);
    stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, WETH_CTYPE);

    assertEq(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_cover_and_repay_debt_moo_velo_bold_lusd_handles_non_profitable_preview() public {
    _setStrategySteps(MOO_VELO_BOLD_LUSD_CTYPE, _mooVeloBoldLusdPipeline());

    (address _auctionHouse, uint256 _auctionId) = _startAuction(
      MOO_VELO_BOLD_LUSD_CTYPE,
      safeOwnerTwo,
      BOLD_LUSD_VELO_BEEFY_VAULT,
      SAFE_MOO_BOLD_LUSD_COLLATERAL_WEI,
      TARGET_SAFE_DEBT_SMALL,
      LOW_LIQUIDATION_PRICE,
      false
    );
    _assertNotProfitableCover(_auctionHouse, _auctionId, MOO_VELO_BOLD_LUSD_CTYPE);
  }

  function test_cover_and_repay_debt_yv_velo_aleth_weth_auction_reverts_when_not_profitable() public {
    _setStrategySteps(YV_VELO_ALETH_WETH_CTYPE, _yvVeloAlethWethPipeline());

    (address _auctionHouse, uint256 _auctionId) = _startAuction(
      YV_VELO_ALETH_WETH_CTYPE,
      safeOwnerThree,
      ALETH_WETH_YEARN_VAULT,
      SAFE_YV_ALETH_WETH_COLLATERAL_WEI,
      TARGET_SAFE_DEBT_SMALL,
      LOW_LIQUIDATION_PRICE,
      false
    );
    _assertNotProfitableCover(_auctionHouse, _auctionId, YV_VELO_ALETH_WETH_CTYPE);
  }

  function test_cover_and_repay_debt_reverts_when_no_strategy_steps() public {
    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.coverAndRepayDebt(address(collateralAuctionHouse[WETH_CTYPE]), 1, 1e18, bytes32('NO_STEPS'));
  }

  function test_cover_and_repay_debt_reverts_on_invalid_auction_house_for_collateral_type() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    vm.expectRevert(IStabilityPool.StabilityPool_InvalidAuctionHouse.selector);
    stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, 1e18, OP_CTYPE);
  }

  function test_cover_and_repay_debt_returns_zero_when_estimated_collateral_bought_is_zero() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    uint256 _bidAmount = 1e18;
    vm.mockCall(
      _auctionHouse,
      abi.encodeWithSelector(ICollateralAuctionHouse.getCollateralBought.selector, _auctionId, _bidAmount),
      abi.encode(uint256(0), uint256(0))
    );

    ICollateralAuctionHouse.Auction memory _auctionBefore = ICollateralAuctionHouse(_auctionHouse).auctions(_auctionId);

    vm.prank(keeper);
    int256 _profit = stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, WETH_CTYPE);
    assertEq(_profit, 0);

    ICollateralAuctionHouse.Auction memory _auctionAfter = ICollateralAuctionHouse(_auctionHouse).auctions(_auctionId);
    assertEq(_auctionAfter.amountToSell, _auctionBefore.amountToSell);
    assertEq(_auctionAfter.amountToRaise, _auctionBefore.amountToRaise);
  }

  function test_cover_and_repay_debt_reverts_when_configured_step_is_de_whitelisted() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    vm.prank(testDeployer);
    stabilityPool.setStepWhitelist(address(veloCLStep), false);

    uint256 _bidAmount = _findAnyExecutableBid(_auctionHouse, _auctionId);

    vm.expectRevert(IStabilityPool.StabilityPool_StepNotWhitelisted.selector);
    vm.prank(keeper);
    stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, WETH_CTYPE);
  }

  function test_cover_and_repay_debt_reverts_when_strategy_cleared() public {
    (address _auctionHouse, uint256 _auctionId) =
      _startAuction(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, LIQUIDATION_PRICE, true);

    vm.prank(testDeployer);
    stabilityPool.clearStrategySteps(WETH_CTYPE);

    uint256 _bidAmount = _findAnyExecutableBid(_auctionHouse, _auctionId);

    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    vm.prank(keeper);
    stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, WETH_CTYPE);
  }

  function test_stability_fee_routed_to_pool_accrues_internal_coin() public {
    _routeWethSecondaryTaxToStabilityPool();
    _openSafeAndGenerateDebt(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, true);

    uint256 _internalCoinBefore = safeEngine.coinBalance(address(stabilityPool));

    vm.warp(block.timestamp + 30 days);
    taxCollector.taxSingle(WETH_CTYPE);

    uint256 _internalCoinAfter = safeEngine.coinBalance(address(stabilityPool));
    assertGt(_internalCoinAfter, _internalCoinBefore);
  }

  function test_sweep_internal_coin_exits_to_hai_and_rate_limits() public {
    _routeWethSecondaryTaxToStabilityPool();
    _openSafeAndGenerateDebt(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, true);

    vm.warp(block.timestamp + 30 days);
    taxCollector.taxSingle(WETH_CTYPE);

    uint256 _internalCoinBefore = safeEngine.coinBalance(address(stabilityPool));
    assertGt(_internalCoinBefore, 0);

    uint256 _expectedExitedWad = _internalCoinBefore / 1e27;
    uint256 _haiBefore = systemCoin.balanceOf(address(stabilityPool));

    vm.prank(keeper);
    uint256 _exitedWad = stabilityPool.sweepInternalCoin();

    assertEq(_exitedWad, _expectedExitedWad);
    assertEq(systemCoin.balanceOf(address(stabilityPool)), _haiBefore + _expectedExitedWad);
    assertEq(safeEngine.coinBalance(address(stabilityPool)), _internalCoinBefore - (_expectedExitedWad * 1e27));

    vm.expectRevert(IStabilityPool.StabilityPool_InternalCoinSweepTooFrequent.selector);
    vm.prank(keeper);
    stabilityPool.sweepInternalCoin();

    vm.warp(block.timestamp + 1 hours + 1);
    vm.prank(keeper);
    uint256 _secondExitedWad = stabilityPool.sweepInternalCoin();
    assertEq(_secondExitedWad, 0);
  }

  function test_sweep_internal_coin_job_rewards_keeper() public {
    _routeWethSecondaryTaxToStabilityPool();
    _openSafeAndGenerateDebt(WETH_CTYPE, safeOwner, WETH, SAFE_WETH_COLLATERAL_WEI, TARGET_SAFE_DEBT, true);

    vm.warp(block.timestamp + 30 days);
    taxCollector.taxSingle(WETH_CTYPE);

    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.prank(keeper);
    uint256 _exitedWad = stabilityPoolSweepJob.workSweepInternalCoin();
    assertGt(_exitedWad, 0);

    assertGt(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_sweep_internal_coin_job_reverts_without_reward_on_zero_sweep_amount() public {
    vm.warp(block.timestamp + 1 hours + 1);

    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.expectRevert(IStabilityPoolSweepJob.StabilityPoolSweepJob_NullSweepAmount.selector);
    vm.prank(keeper);
    stabilityPoolSweepJob.workSweepInternalCoin();

    assertEq(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_cover_and_repay_debt_yv_velo_aleth_weth_step_override_slippage_precedence() public {
    vm.prank(testDeployer);
    stabilityPool.setCollateralSlippageBps(YV_VELO_ALETH_WETH_CTYPE, 10_000);

    _setStrategySteps(YV_VELO_ALETH_WETH_CTYPE, _yvVeloAlethWethPipeline());
    (address _auctionHouseWithOverride, uint256 _auctionIdWithOverride) = _startAuction(
      YV_VELO_ALETH_WETH_CTYPE,
      safeOwnerThree,
      ALETH_WETH_YEARN_VAULT,
      SAFE_YV_ALETH_WETH_COLLATERAL_WEI,
      TARGET_SAFE_DEBT_SMALL,
      LOW_LIQUIDATION_PRICE,
      false
    );

    vm.warp(block.timestamp + 24 hours);
    uint256 _bidWithOverride = _findAnyExecutableBid(_auctionHouseWithOverride, _auctionIdWithOverride);
    bytes4 _selectorWithOverride = _getCoverAndRepayDebtRevertSelector(
      _auctionHouseWithOverride, _auctionIdWithOverride, _bidWithOverride, YV_VELO_ALETH_WETH_CTYPE
    );
    bool _isExpectedOverrideSelector = _selectorWithOverride
      == bytes4(keccak256('VeloLPRemoveAndSwapStep_InsufficientOutput()'))
      || _selectorWithOverride == bytes4(keccak256('CurveSwapStep_OracleFloorNotMet()'));
    assertTrue(_isExpectedOverrideSelector, 'unexpected selector with step override slippage enabled');

    IStabilityPool.StepConfig[] memory _stepsWithoutOverride = _yvVeloAlethWethPipeline();
    for (uint256 _i = 0; _i < _stepsWithoutOverride.length; _i++) {
      _stepsWithoutOverride[_i].slippageBps = 0;
    }
    _setStrategySteps(YV_VELO_ALETH_WETH_CTYPE, _stepsWithoutOverride);
    _mockCollateralPriceAndUpdate(YV_VELO_ALETH_WETH_CTYPE, LIQUIDATION_PRICE);
    (address _auctionHouseWithoutOverride, uint256 _auctionIdWithoutOverride) = _startAuction(
      YV_VELO_ALETH_WETH_CTYPE,
      safeOwnerFour,
      ALETH_WETH_YEARN_VAULT,
      SAFE_YV_ALETH_WETH_COLLATERAL_WEI,
      TARGET_SAFE_DEBT_SMALL,
      LOW_LIQUIDATION_PRICE,
      false
    );

    vm.warp(block.timestamp + 24 hours);
    uint256 _bidWithoutOverride = _findAnyExecutableBid(_auctionHouseWithoutOverride, _auctionIdWithoutOverride);
    (bool _okWithoutOverride, bytes memory _returnDataWithoutOverride) = _callCoverAndRepayDebt(
      _auctionHouseWithoutOverride, _auctionIdWithoutOverride, _bidWithoutOverride, YV_VELO_ALETH_WETH_CTYPE
    );
    if (_okWithoutOverride) {
      int256 _profitWithoutOverride = abi.decode(_returnDataWithoutOverride, (int256));
      assertTrue(_profitWithoutOverride >= 0, 'expected non-negative profit when step override slippage is disabled');
    } else {
      bytes4 _selectorWithoutOverride = _revertSelector(_returnDataWithoutOverride);
      bool _isExpectedSelector = _selectorWithoutOverride == IStabilityPool.StabilityPool_NotProfitable.selector
        || _selectorWithoutOverride == bytes4(keccak256('CurveSwapStep_OracleFloorNotMet()'));
      assertTrue(_isExpectedSelector, 'unexpected selector when step override slippage is disabled');
    }
  }

  function _runCoverAndRepayFlow(address _auctionHouse, uint256 _auctionId, bytes32 _cType) internal {
    uint256 _startTime = block.timestamp;
    uint256[8] memory _ageOffsets =
      [uint256(6 hours), 12 hours, 18 hours, 24 hours, 36 hours, 48 hours, 72 hours, 96 hours];
    uint256 _bidAmount;
    uint256 _estimatedAdjustedBid;
    uint256 _expectedHai;
    for (uint256 _i = 0; _i < _ageOffsets.length; _i++) {
      vm.warp(_startTime + _ageOffsets[_i]);
      (_bidAmount, _estimatedAdjustedBid, _expectedHai) = _findProfitableBid(_auctionHouse, _auctionId, _cType);
      if (_estimatedAdjustedBid > 0) break;
    }
    if (_estimatedAdjustedBid == 0) revert('no profitable bid found');
    assertGe(_expectedHai, _estimatedAdjustedBid);

    ICollateralAuctionHouse.Auction memory _auctionBefore = ICollateralAuctionHouse(_auctionHouse).auctions(_auctionId);
    uint256 _poolHaiBefore = systemCoin.balanceOf(address(stabilityPool));

    vm.prank(keeper);
    int256 _profit = stabilityPool.coverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _cType);

    assertGt(_profit, 0, 'expected positive profit');
    assertEq(systemCoin.balanceOf(address(stabilityPool)), _poolHaiBefore + uint256(_profit));

    ICollateralAuctionHouse.Auction memory _auctionAfter = ICollateralAuctionHouse(_auctionHouse).auctions(_auctionId);
    assertLe(_auctionAfter.amountToSell, _auctionBefore.amountToSell);
    assertLt(_auctionAfter.amountToRaise, _auctionBefore.amountToRaise);
  }

  function _assertNotProfitableCover(address _auctionHouse, uint256 _auctionId, bytes32 _cType) internal {
    vm.warp(block.timestamp + 24 hours);
    (, uint256 _estimatedAdjustedBid,) = _findProfitableBid(_auctionHouse, _auctionId, _cType);
    assertEq(_estimatedAdjustedBid, 0, 'expected no profitable bid');

    uint256 _bidAmount = _findAnyExecutableBid(_auctionHouse, _auctionId);
    (bool _ok, bytes memory _returnData) = _callCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _cType);
    if (_ok) {
      int256 _profit = abi.decode(_returnData, (int256));
      assertGt(_profit, 0, 'expected positive profit when non-profitable preview still executes');
    } else {
      bytes4 _selector = _revertSelector(_returnData);
      bool _isExpected = _selector == IStabilityPool.StabilityPool_NotProfitable.selector
        || _selector == bytes4(keccak256('VeloLPRemoveAndSwapStep_InsufficientOutput()'))
        || _selector == bytes4(keccak256('CurveSwapStep_OracleFloorNotMet()'));
      assertTrue(_isExpected, 'unexpected revert selector for non-profitable cover');
    }
  }

  function _getCoverAndRepayDebtRevertSelector(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _cType
  ) internal returns (bytes4 _selector) {
    (bool _ok, bytes memory _returnData) = _callCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _cType);
    assertFalse(_ok, 'expected coverAndRepayDebt to revert');
    _selector = _revertSelector(_returnData);
  }

  function _callCoverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _cType
  ) internal returns (bool _ok, bytes memory _returnData) {
    bytes memory _callData =
      abi.encodeCall(stabilityPool.coverAndRepayDebt, (_auctionHouse, _auctionId, _bidAmount, _cType));
    (_ok, _returnData) = address(stabilityPool).call(_callData);
  }

  function _revertSelector(bytes memory _returnData) internal pure returns (bytes4 _selector) {
    assertGe(_returnData.length, 4);
    _selector = bytes4(_returnData);
  }

  function _setStrategySteps(bytes32 _cType, IStabilityPool.StepConfig[] memory _steps) internal {
    vm.prank(testDeployer);
    stabilityPool.setStrategySteps(_cType, _steps);
  }

  function _routeWethSecondaryTaxToStabilityPool() internal {
    address[] memory _secondaryReceivers = taxCollector.secondaryReceiversList();
    address _receiverToReplace = address(0);
    uint256 _taxPercentage;
    bool _canTakeBackTax;

    for (uint256 _i = 0; _i < _secondaryReceivers.length; _i++) {
      ITaxCollector.TaxReceiver memory _receiverData =
        taxCollector.secondaryTaxReceivers(WETH_CTYPE, _secondaryReceivers[_i]);
      if (_receiverData.taxPercentage > 0) {
        _receiverToReplace = _secondaryReceivers[_i];
        _taxPercentage = _receiverData.taxPercentage;
        _canTakeBackTax = _receiverData.canTakeBackTax;
        break;
      }
    }

    assertTrue(_receiverToReplace != address(0), 'no secondary receiver configured');

    vm.startPrank(address(timelock));
    taxCollector.modifyParameters(
      WETH_CTYPE,
      'secondaryTaxReceiver',
      abi.encode(
        ITaxCollector.TaxReceiver({receiver: _receiverToReplace, canTakeBackTax: _canTakeBackTax, taxPercentage: 0})
      )
    );
    taxCollector.modifyParameters(
      WETH_CTYPE,
      'secondaryTaxReceiver',
      abi.encode(
        ITaxCollector.TaxReceiver({
          receiver: address(stabilityPool),
          canTakeBackTax: _canTakeBackTax,
          taxPercentage: _taxPercentage
        })
      )
    );
    vm.stopPrank();
  }

  function _startAuction(
    bytes32 _cType,
    address _owner,
    address _collateralToken,
    uint256 _collateralWei,
    uint256 _targetDebtWad,
    uint256 _liquidationPrice,
    bool _isWethNative
  ) internal returns (address _auctionHouse, uint256 _auctionId) {
    _openSafeAndGenerateDebt(_cType, _owner, _collateralToken, _collateralWei, _targetDebtWad, _isWethNative);
    _mockCollateralPriceAndUpdate(_cType, _liquidationPrice);

    _auctionHouse = collateralAuctionHouseFactory.collateralAuctionHouses(_cType);
    assertTrue(_auctionHouse != address(0), 'auction house not found');
    _auctionId = liquidationEngine.liquidateSAFE(_cType, _owner);
    assertGt(_auctionId, 0);
  }

  function _openSafeAndGenerateDebt(
    bytes32 _cType,
    address _owner,
    address _collateralToken,
    uint256 _collateralWei,
    uint256 _targetDebtWad,
    bool _isWethNative
  ) internal {
    address _joinAddr = collateralJoinFactory.collateralJoins(_cType);
    assertTrue(_joinAddr != address(0), 'collateral join not found');

    uint256 _multiplier = ICollateralJoin(_joinAddr).multiplier();
    uint256 _collateralWad = _collateralWei * (10 ** _multiplier);
    uint256 _debtWad = _computeDebtToGenerate(_cType, _collateralWad, _targetDebtWad);

    vm.startPrank(_owner);

    if (_isWethNative) {
      vm.deal(_owner, _collateralWei);
      IWeth(_collateralToken).deposit{value: _collateralWei}();
    } else {
      deal(_collateralToken, _owner, _collateralWei);
    }

    IERC20(_collateralToken).approve(_joinAddr, _collateralWei);
    ICollateralJoin(_joinAddr).join(_owner, _collateralWei);

    safeEngine.approveSAFEModification(_joinAddr);
    safeEngine.modifySAFECollateralization({
      _cType: _cType,
      _safe: _owner,
      _collateralSource: _owner,
      _debtDestination: _owner,
      _deltaCollateral: int256(_collateralWad),
      _deltaDebt: int256(_debtWad)
    });

    safeEngine.approveSAFEModification(address(coinJoin));
    coinJoin.exit(_owner, _debtWad);
    vm.stopPrank();
  }

  function _mockCollateralPriceAndUpdate(bytes32 _cType, uint256 _price) internal {
    IBaseOracle _oracle = oracleRelayer.cParams(_cType).oracle;
    vm.mockCall(
      address(_oracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector), abi.encode(_price, true)
    );
    vm.mockCall(address(_oracle), abi.encodeWithSelector(IBaseOracle.read.selector), abi.encode(_price));
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function _computeDebtToGenerate(
    bytes32 _cType,
    uint256 _collateralWad,
    uint256 _targetDebtWad
  ) internal view returns (uint256 _debtWad) {
    ISAFEEngine.SAFEEngineCollateralData memory _cData = safeEngine.cData(_cType);
    uint256 _maxDebtWad = (_collateralWad * _cData.safetyPrice) / _cData.accumulatedRate;
    uint256 _safeDebtWad = (_maxDebtWad * 95) / 100;
    uint256 _debtFloorWad = safeEngine.cParams(_cType).debtFloor / 1e27;

    _debtWad = _targetDebtWad;
    if (_debtWad > _safeDebtWad) _debtWad = _safeDebtWad;
    if (_debtWad < _debtFloorWad) _debtWad = _debtFloorWad;
    assertGt(_debtWad, 0);
    assertLe(_debtWad, _maxDebtWad);
  }

  function _findProfitableBid(
    address _auctionHouse,
    uint256 _auctionId,
    bytes32 _cType
  ) internal view returns (uint256 _bidAmount, uint256 _estimatedAdjustedBid, uint256 _expectedHai) {
    uint256 _minimumBid = ICollateralAuctionHouse(_auctionHouse).params().minimumBid;
    uint256 _maxPoolBid = systemCoin.balanceOf(address(stabilityPool));

    address _joinAddr = collateralJoinFactory.collateralJoins(_cType);
    assertTrue(_joinAddr != address(0), 'collateral join not found');
    uint256 _multiplier = ICollateralJoin(_joinAddr).multiplier();

    if (_minimumBid == 0) _minimumBid = 1e18;

    for (uint256 _i = 0; _i < 16; _i++) {
      uint256 _candidate = _candidateBidFromMinimum(_minimumBid, _i);
      if (_candidate > _maxPoolBid) continue;
      (_estimatedAdjustedBid, _expectedHai) =
        _profitForBidCandidate(_auctionHouse, _auctionId, _cType, _candidate, _minimumBid, _multiplier);
      if (_estimatedAdjustedBid > 0) return (_candidate, _estimatedAdjustedBid, _expectedHai);
    }

    uint256 _auctionAmountToRaise = ICollateralAuctionHouse(_auctionHouse).auctions(_auctionId).amountToRaise;
    if (_auctionAmountToRaise >= _minimumBid && _auctionAmountToRaise <= _maxPoolBid) {
      (_estimatedAdjustedBid, _expectedHai) =
        _profitForBidCandidate(_auctionHouse, _auctionId, _cType, _auctionAmountToRaise, _minimumBid, _multiplier);
      if (_estimatedAdjustedBid > 0) return (_auctionAmountToRaise, _estimatedAdjustedBid, _expectedHai);
    }

    return (0, 0, 0);
  }

  function _profitForBidCandidate(
    address _auctionHouse,
    uint256 _auctionId,
    bytes32 _cType,
    uint256 _candidateBid,
    uint256 _minimumBid,
    uint256 _collateralMultiplier
  ) internal view returns (uint256 _adjustedBid, uint256 _previewHai) {
    (uint256 _estimatedCollateralBought, uint256 _adjustedCandidateBid) =
      ICollateralAuctionHouse(_auctionHouse).getCollateralBought(_auctionId, _candidateBid);
    if (_estimatedCollateralBought == 0 || _adjustedCandidateBid == 0 || _adjustedCandidateBid < _minimumBid) {
      return (0, 0);
    }

    uint256 _estimatedCollateralWei = _toCollateralWei(_estimatedCollateralBought, _collateralMultiplier);
    if (_estimatedCollateralWei == 0) return (0, 0);

    _previewHai = stabilityPool.previewSwapToHai(_cType, _estimatedCollateralWei);
    if (_previewHai < _adjustedCandidateBid) return (0, 0);
    return (_adjustedCandidateBid, _previewHai);
  }

  function _candidateBidFromMinimum(uint256 _minimumBid, uint256 _index) internal pure returns (uint256 _candidateBid) {
    if (_index == 0) return _minimumBid;
    if (_index == 1) return _minimumBid * 2;
    if (_index == 2) return _minimumBid * 3;
    if (_index == 3) return _minimumBid * 4;
    if (_index == 4) return _minimumBid * 5;
    if (_index == 5) return _minimumBid * 6;
    if (_index == 6) return _minimumBid * 8;
    if (_index == 7) return _minimumBid * 10;
    if (_index == 8) return _minimumBid * 12;
    if (_index == 9) return _minimumBid * 15;
    if (_index == 10) return _minimumBid * 20;
    if (_index == 11) return _minimumBid * 25;
    if (_index == 12) return _minimumBid * 30;
    if (_index == 13) return _minimumBid * 40;
    if (_index == 14) return _minimumBid * 60;
    return _minimumBid * 80;
  }

  function _findAnyExecutableBid(address _auctionHouse, uint256 _auctionId) internal view returns (uint256 _bidAmount) {
    uint256 _minimumBid = ICollateralAuctionHouse(_auctionHouse).params().minimumBid;
    uint256 _maxPoolBid = systemCoin.balanceOf(address(stabilityPool));
    if (_minimumBid == 0) _minimumBid = 1e18;

    uint256[8] memory _multipliers = [uint256(1), 2, 3, 4, 6, 10, 20, 40];
    for (uint256 _i = 0; _i < _multipliers.length; _i++) {
      uint256 _candidateBid = _minimumBid * _multipliers[_i];
      if (_candidateBid > _maxPoolBid) continue;
      (uint256 _estimatedCollateralBought,) =
        ICollateralAuctionHouse(_auctionHouse).getCollateralBought(_auctionId, _candidateBid);
      if (_estimatedCollateralBought > 0) return _candidateBid;
    }
    return _minimumBid;
  }

  function _toCollateralWei(uint256 _wad, uint256 _multiplier) internal pure returns (uint256 _wei) {
    if (_multiplier == 0) return _wad;
    return _wad / (10 ** _multiplier);
  }

  function _wethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](3);
    _steps[0] = IStabilityPool.StepConfig({step: address(veloCLStep), data: _wethToUsdcVeloClData(), slippageBps: 200});
    _steps[1] = IStabilityPool.StepConfig({step: address(veloSwapStep), data: _usdcToBoldVeloData(), slippageBps: 200});
    _steps[2] = IStabilityPool.StepConfig({step: address(curveStep), data: _boldToHaiCurveData(), slippageBps: 200});
  }

  function _rethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](5);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(balancerV3Step),
      data: _rethToWaOptWethBalancerV3Data(),
      slippageBps: 200
    });
    _steps[1] =
      IStabilityPool.StepConfig({step: address(erc4626Step), data: _waOptWethToWethErc4626Data(), slippageBps: 200});
    _steps[2] = IStabilityPool.StepConfig({step: address(veloCLStep), data: _wethToUsdcVeloClData(), slippageBps: 200});
    _steps[3] = IStabilityPool.StepConfig({step: address(veloSwapStep), data: _usdcToBoldVeloData(), slippageBps: 200});
    _steps[4] = IStabilityPool.StepConfig({step: address(curveStep), data: _boldToHaiCurveData(), slippageBps: 200});
  }

  function _mooVeloBoldLusdPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](3);
    _steps[0] =
      IStabilityPool.StepConfig({step: address(beefyStep), data: _beefyBoldLusdWithdrawalData(), slippageBps: 200});
    _steps[1] = IStabilityPool.StepConfig({
      step: address(veloLPRemoveAndSwapStep),
      data: _boldLusdLpRemoveAndSwapData(),
      slippageBps: 200
    });
    _steps[2] = IStabilityPool.StepConfig({step: address(curveStep), data: _boldToHaiCurveData(), slippageBps: 200});
  }

  function _yvVeloAlethWethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](5);
    _steps[0] =
      IStabilityPool.StepConfig({step: address(yearnStep), data: _yearnAlethWethWithdrawalData(), slippageBps: 200});
    _steps[1] = IStabilityPool.StepConfig({
      step: address(veloLPRemoveAndSwapStep),
      data: _alethWethLpRemoveAndSwapData(),
      slippageBps: 200
    });
    _steps[2] = IStabilityPool.StepConfig({step: address(veloCLStep), data: _wethToUsdcVeloClData(), slippageBps: 200});
    _steps[3] = IStabilityPool.StepConfig({step: address(veloSwapStep), data: _usdcToBoldVeloData(), slippageBps: 200});
    _steps[4] = IStabilityPool.StepConfig({step: address(curveStep), data: _boldToHaiCurveData(), slippageBps: 200});
  }

  function _wethToUsdcVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: VELO_CL_POOL_WETH_USDC,
        tokenIn: WETH,
        tokenOut: USDC,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _usdcToBoldVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: USDC,
        tokenOut: BOLD,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _boldToHaiCurveData() internal view returns (bytes memory _data) {
    _data = abi.encode(
      CurveSwapStep.Data({
        pool: CURVE_BOLD_HAI_POOL,
        i: int128(1),
        j: int128(0),
        tokenIn: BOLD,
        tokenOut: HAI,
        useOracleFloor: true,
        tokenInOracle: address(boldUsdOracle),
        tokenOutOracle: HAI_USD_ORACLE,
        oracleToleranceBps: CURVE_ORACLE_TOLERANCE_BPS
      })
    );
  }

  function _rethToWaOptWethBalancerV3Data() internal view returns (bytes memory _data) {
    _data = abi.encode(
      BalancerV3StablePoolMathSwapStep.Data({
        router: BALANCER_V3_ROUTER,
        pool: BALANCER_V3_RETH_WA_OPT_WETH_POOL,
        tokenIn: RETH,
        tokenOut: WA_OPT_WETH,
        deadlineBuffer: 1 hours,
        userData: bytes(''),
        useOracleFloor: true,
        tokenInOracle: RETH_USD_ORACLE,
        tokenOutOracle: address(waOptWethUsdOracle),
        oracleToleranceBps: BALANCER_ORACLE_TOLERANCE_BPS
      })
    );
  }

  function _waOptWethToWethErc4626Data() internal pure returns (bytes memory _data) {
    _data = abi.encode(ERC4626WithdrawalStep.Data({vault: WA_OPT_WETH, vaultToken: WA_OPT_WETH, assetToken: WETH}));
  }

  function _beefyBoldLusdWithdrawalData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      BeefyVaultWithdrawalStep.Data({
        vault: BOLD_LUSD_VELO_BEEFY_VAULT,
        vaultToken: BOLD_LUSD_VELO_BEEFY_VAULT,
        lpToken: BOLD_LUSD_VELO_POOL,
        shareScale: 1e18
      })
    );
  }

  function _yearnAlethWethWithdrawalData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      YearnVaultWithdrawalStep.Data({
        vault: ALETH_WETH_YEARN_VAULT,
        vaultToken: ALETH_WETH_YEARN_VAULT,
        lpToken: ALETH_WETH_VELO_POOL,
        shareScale: 1e18
      })
    );
  }

  function _boldLusdLpRemoveAndSwapData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: BOLD_LUSD_VELO_POOL,
        tokenA: BOLD,
        tokenB: LUSD,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _alethWethLpRemoveAndSwapData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: ALETH_WETH_VELO_POOL,
        tokenA: WETH,
        tokenB: ALETH,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
  }
}

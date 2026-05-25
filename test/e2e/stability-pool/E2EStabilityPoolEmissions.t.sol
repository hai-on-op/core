// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {StabilityPool} from '@contracts/stability-pool/StabilityPool.sol';
import {EmissionsController} from '@contracts/stability-pool/EmissionsController.sol';
import {EmissionsControllerJob} from '@contracts/jobs/EmissionsControllerJob.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {WAD, HOUR} from '@libraries/Math.sol';
import {CurveStableSwapNGRelayer} from '@contracts/oracles/CurveStableSwapNGRelayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';

contract E2EStabilityPoolEmissionsForkTest is HaiTest, MainnetDeployment {
  uint256 internal constant FORK_BLOCK = 148_368_730;

  uint256 internal constant TOTAL_KITE = 1_000_000e18;
  uint256 internal constant DEVIATION_LIMIT = 0.1e18;
  uint256 internal constant EMISSIONS_DURATION = 365 days;

  uint256 internal constant USER_HAI_BALANCE = 5000e18;
  uint256 internal constant USER_DEPOSIT = 1000e18;

  bytes32 internal constant WETH_CTYPE = bytes32('WETH');

  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
  address internal constant CURVE_POOL = 0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5;

  address internal constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
  address internal constant USDC_ADDR = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address internal constant BOLD_ADDR = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant HAI_ADDR = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant HAI_USD_ORACLE = 0x8c212bCaE328669c8b045D467CB78b88e0BE0D39;
  uint16 internal constant CURVE_ORACLE_TOLERANCE_BPS = 200;

  address internal testDeployer = label('testDeployer');
  address internal user = label('user');
  address internal user2 = label('user2');
  address internal keeper = label('keeper');
  address internal postCutoverRewardsReceiver = label('postCutoverRewardsReceiver');

  EmissionsController internal emissionsController;
  StabilityPool internal stabilityPool;
  EmissionsControllerJob internal emissionsControllerJob;
  DenominatedOracle internal boldUsdOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    // Keep KITE transferable in case current mainnet state is paused at the selected block.
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
    IBaseOracle _haiBoldOracle = new CurveStableSwapNGRelayer(CURVE_POOL, 0, 1);
    boldUsdOracle = new DenominatedOracle(_haiBoldOracle, IBaseOracle(HAI_USD_ORACLE), true);
    emissionsControllerJob =
      new EmissionsControllerJob(address(emissionsController), address(stabilityFeeTreasury), 1e18);
    vm.stopPrank();

    vm.prank(address(timelock));
    stabilityFeeTreasury.setTotalAllowance(address(emissionsControllerJob), type(uint256).max);

    deal(address(protocolToken), address(emissionsController), TOTAL_KITE);
    deal(address(systemCoin), user, USER_HAI_BALANCE);
    deal(address(systemCoin), user2, USER_HAI_BALANCE);

    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
    vm.prank(user2);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }

  function test_optimism_fork() public view {
    assertEq(block.number, FORK_BLOCK);
  }

  function test_deposit_transfers_kite_from_emissions_controller_to_stability_pool() public {
    vm.warp(block.timestamp + 1 days);

    uint256 _accruedBeforeDeposit = emissionsController.getAccruedRewardsForStabilityPool();
    uint256 _controllerKiteBefore = protocolToken.balanceOf(address(emissionsController));
    uint256 _poolKiteBefore = protocolToken.balanceOf(address(stabilityPool));

    vm.prank(user);
    stabilityPool.deposit(USER_DEPOSIT, user);

    uint256 _controllerKiteAfter = protocolToken.balanceOf(address(emissionsController));
    uint256 _poolKiteAfter = protocolToken.balanceOf(address(stabilityPool));

    uint256 _transferredFromController = _controllerKiteBefore - _controllerKiteAfter;
    uint256 _receivedByPool = _poolKiteAfter - _poolKiteBefore;

    assertGt(_accruedBeforeDeposit, 0);
    assertGt(_transferredFromController, 0);
    assertEq(_transferredFromController, _receivedByPool);
    assertEq(_transferredFromController, _accruedBeforeDeposit);
  }

  function test_user_does_not_earn_kite_accrued_before_depositing_hai() public {
    vm.warp(block.timestamp + 1 days);

    vm.prank(user);
    uint256 _shares = stabilityPool.deposit(USER_DEPOSIT, user);
    assertEq(_shares, USER_DEPOSIT);

    uint256 _pendingBeforeClaim = stabilityPool.pendingRewards(user);
    assertEq(_pendingBeforeClaim, 0);

    uint256 _kiteBalanceBefore = protocolToken.balanceOf(user);
    uint256 _poolKiteBefore = protocolToken.balanceOf(address(stabilityPool));
    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();

    assertEq(_claimed, 0);
    assertEq(_claimed, _pendingBeforeClaim);
    assertEq(protocolToken.balanceOf(user), _kiteBalanceBefore + _claimed);
    assertEq(protocolToken.balanceOf(address(stabilityPool)), _poolKiteBefore);
  }

  function test_user_earns_kite_after_depositing_and_time_elapsed() public {
    vm.prank(user);
    uint256 _shares = stabilityPool.deposit(USER_DEPOSIT, user);
    assertEq(_shares, USER_DEPOSIT);
    assertEq(stabilityPool.pendingRewards(user), 0);

    vm.warp(block.timestamp + 1 days);

    vm.prank(user);
    uint256 _claimedFromController = stabilityPool.claimRewardsFromEmissionsController();
    assertGt(_claimedFromController, 0);

    uint256 _pendingAfterAccrual = stabilityPool.pendingRewards(user);
    assertGt(_pendingAfterAccrual, 0);

    uint256 _userKiteBefore = protocolToken.balanceOf(user);
    vm.prank(user);
    uint256 _claimedByUser = stabilityPool.claimRewards();

    assertEq(_claimedByUser, _pendingAfterAccrual);
    assertEq(protocolToken.balanceOf(user), _userKiteBefore + _claimedByUser);
  }

  function test_two_users_earn_kite_proportional_to_shares() public {
    uint256 _user2Deposit = USER_DEPOSIT / 2;

    vm.prank(user);
    stabilityPool.deposit(USER_DEPOSIT, user);
    vm.prank(user2);
    stabilityPool.deposit(_user2Deposit, user2);

    assertEq(stabilityPool.pendingRewards(user), 0);
    assertEq(stabilityPool.pendingRewards(user2), 0);

    vm.warp(block.timestamp + 1 days);

    vm.prank(user);
    uint256 _claimedFromController = stabilityPool.claimRewardsFromEmissionsController();
    assertGt(_claimedFromController, 0);

    uint256 _pendingUser1 = stabilityPool.pendingRewards(user);
    uint256 _pendingUser2 = stabilityPool.pendingRewards(user2);

    uint256 _totalShares = USER_DEPOSIT + _user2Deposit;
    uint256 _integral = (_claimedFromController * WAD) / _totalShares;
    uint256 _expectedUser1 = (USER_DEPOSIT * _integral) / WAD;
    uint256 _expectedUser2 = (_user2Deposit * _integral) / WAD;

    assertEq(_pendingUser1, _expectedUser1);
    assertEq(_pendingUser2, _expectedUser2);
    assertGt(_pendingUser1, _pendingUser2);

    uint256 _user1KiteBefore = protocolToken.balanceOf(user);
    uint256 _user2KiteBefore = protocolToken.balanceOf(user2);

    vm.prank(user);
    uint256 _claimedByUser1 = stabilityPool.claimRewards();
    vm.prank(user2);
    uint256 _claimedByUser2 = stabilityPool.claimRewards();

    assertEq(_claimedByUser1, _pendingUser1);
    assertEq(_claimedByUser2, _pendingUser2);
    assertEq(protocolToken.balanceOf(user), _user1KiteBefore + _claimedByUser1);
    assertEq(protocolToken.balanceOf(user2), _user2KiteBefore + _claimedByUser2);
  }

  function test_update_reward_split_uses_onchain_oracle_prices() public {
    vm.warp(block.timestamp + HOUR + 1);

    uint256 _redemptionPrice = oracleRelayer.calcRedemptionPrice();
    uint256 _marketPrice = oracleRelayer.marketPrice();
    assertGt(_redemptionPrice, 0);

    uint256 _expectedSplit = _expectedSplitFromPrices(_redemptionPrice, _marketPrice);

    emissionsController.updateRewardSplit();

    assertEq(emissionsController.stabilityPoolSplit(), _expectedSplit);
    assertEq(emissionsController.mintingSplit(), 100 - _expectedSplit);
  }

  function test_update_reward_split_job_rewards_keeper() public {
    vm.warp(block.timestamp + HOUR + 1);

    uint256 _redemptionPrice = oracleRelayer.calcRedemptionPrice();
    uint256 _marketPrice = oracleRelayer.marketPrice();
    uint256 _expectedSplit = _expectedSplitFromPrices(_redemptionPrice, _marketPrice);
    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.prank(keeper);
    emissionsControllerJob.workUpdateRewardSplit();

    assertEq(emissionsController.stabilityPoolSplit(), _expectedSplit);
    assertEq(emissionsController.mintingSplit(), 100 - _expectedSplit);
    assertGt(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_update_reward_split_job_reverts_without_reward_when_called_too_frequently() public {
    uint256 _keeperInternalCoinBefore = safeEngine.coinBalance(keeper);

    vm.expectRevert(IEmissionsController.EmissionsController_SplitUpdateTooFrequent.selector);
    vm.prank(keeper);
    emissionsControllerJob.workUpdateRewardSplit();

    assertEq(safeEngine.coinBalance(keeper), _keeperInternalCoinBefore);
  }

  function test_claim_rewards_for_stability_pool_reverts_when_not_receiver() public {
    vm.prank(user);
    vm.expectRevert(IEmissionsController.EmissionsController_OnlyStabilityRewardsReceiver.selector);
    emissionsController.claimRewardsForStabilityPool();
  }

  function test_claim_rewards_for_stability_pool_direct_receiver_claim() public {
    vm.warp(block.timestamp + 1 days);

    uint256 _receiverKiteBefore = protocolToken.balanceOf(address(stabilityPool));
    vm.prank(address(stabilityPool));
    uint256 _claimed = emissionsController.claimRewardsForStabilityPool();

    assertGt(_claimed, 0);
    assertEq(protocolToken.balanceOf(address(stabilityPool)), _receiverKiteBefore + _claimed);
  }

  function test_update_reward_split_reverts_when_called_too_frequently() public {
    vm.expectRevert(IEmissionsController.EmissionsController_SplitUpdateTooFrequent.selector);
    emissionsController.updateRewardSplit();
  }

  function test_update_reward_split_reverts_when_redemption_price_is_zero() public {
    vm.warp(block.timestamp + HOUR + 1);
    vm.mockCall(address(oracleRelayer), abi.encodeWithSignature('calcRedemptionPrice()'), abi.encode(uint256(0)));

    vm.expectRevert(IEmissionsController.EmissionsController_InvalidRedemptionPrice.selector);
    emissionsController.updateRewardSplit();
  }

  function test_update_reward_split_at_positive_deviation_limit_sets_max_stability_split() public {
    uint256 _redemptionPrice = 1e27;
    uint256 _deviationAbs = (_redemptionPrice * DEVIATION_LIMIT) / WAD;

    _updateRewardSplitWithMockedPrices(_redemptionPrice, _redemptionPrice - _deviationAbs);

    assertEq(emissionsController.stabilityPoolSplit(), 100);
    assertEq(emissionsController.mintingSplit(), 0);
  }

  function test_update_reward_split_at_zero_deviation_sets_balanced_split() public {
    uint256 _redemptionPrice = 1e27;

    _updateRewardSplitWithMockedPrices(_redemptionPrice, _redemptionPrice);

    assertEq(emissionsController.stabilityPoolSplit(), 50);
    assertEq(emissionsController.mintingSplit(), 50);
  }

  function test_update_reward_split_at_negative_deviation_limit_sets_min_stability_split() public {
    uint256 _redemptionPrice = 1e27;
    uint256 _deviationAbs = (_redemptionPrice * DEVIATION_LIMIT) / WAD;

    _updateRewardSplitWithMockedPrices(_redemptionPrice, _redemptionPrice + _deviationAbs);

    assertEq(emissionsController.stabilityPoolSplit(), 0);
    assertEq(emissionsController.mintingSplit(), 100);
  }

  function test_update_reward_split_above_positive_deviation_limit_clamps_to_max_stability_split() public {
    uint256 _redemptionPrice = 1e27;
    uint256 _deviationAbs = (_redemptionPrice * DEVIATION_LIMIT) / WAD;

    _updateRewardSplitWithMockedPrices(_redemptionPrice, _redemptionPrice - _deviationAbs - 1);

    assertEq(emissionsController.stabilityPoolSplit(), 100);
    assertEq(emissionsController.mintingSplit(), 0);
  }

  function test_update_reward_split_below_negative_deviation_limit_clamps_to_min_stability_split() public {
    uint256 _redemptionPrice = 1e27;
    uint256 _deviationAbs = (_redemptionPrice * DEVIATION_LIMIT) / WAD;

    _updateRewardSplitWithMockedPrices(_redemptionPrice, _redemptionPrice + _deviationAbs + 1);

    assertEq(emissionsController.stabilityPoolSplit(), 0);
    assertEq(emissionsController.mintingSplit(), 100);
  }

  function test_set_stability_rewards_receiver_rotates_and_payouts_accrued_rewards() public {
    vm.warp(block.timestamp + 1 days);

    uint256 _poolKiteBefore = protocolToken.balanceOf(address(stabilityPool));
    uint256 _accruedToPool = emissionsController.getAccruedRewardsForStabilityPool();
    assertGt(_accruedToPool, 0);

    vm.prank(testDeployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewardsReceiver);

    assertEq(emissionsController.stabilityRewardsReceiver(), postCutoverRewardsReceiver);
    assertEq(protocolToken.balanceOf(address(stabilityPool)), _poolKiteBefore + _accruedToPool);
    assertEq(protocolToken.balanceOf(postCutoverRewardsReceiver), 0);

    vm.warp(block.timestamp + 1 days);
    uint256 _accruedToNewReceiver = emissionsController.getAccruedRewardsForStabilityPool();
    assertGt(_accruedToNewReceiver, 0);

    address _finalReceiver = label('finalReceiver');
    uint256 _newReceiverKiteBefore = protocolToken.balanceOf(postCutoverRewardsReceiver);
    uint256 _finalReceiverKiteBefore = protocolToken.balanceOf(_finalReceiver);

    vm.prank(testDeployer);
    emissionsController.setStabilityRewardsReceiver(_finalReceiver);

    assertEq(emissionsController.stabilityRewardsReceiver(), _finalReceiver);
    assertEq(protocolToken.balanceOf(postCutoverRewardsReceiver), _newReceiverKiteBefore + _accruedToNewReceiver);
    assertEq(protocolToken.balanceOf(_finalReceiver), _finalReceiverKiteBefore);
  }

  function test_enable_transfers_cutover_disables_emissions_claims() public {
    vm.warp(block.timestamp + 1 days);

    vm.prank(user);
    stabilityPool.deposit(USER_DEPOSIT, user);

    vm.warp(block.timestamp + 1 days);
    uint256 _poolKiteBeforeRotation = protocolToken.balanceOf(address(stabilityPool));

    vm.prank(testDeployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewardsReceiver);
    assertEq(emissionsController.stabilityRewardsReceiver(), postCutoverRewardsReceiver);
    assertGe(protocolToken.balanceOf(address(stabilityPool)), _poolKiteBeforeRotation);

    vm.prank(testDeployer);
    stabilityPool.enableTransfers();

    assertEq(stabilityPool.transfersEnabled(), true);
    assertEq(stabilityPool.kiteRewardsActive(), false);

    vm.prank(user);
    stabilityPool.transfer(user2, USER_DEPOSIT / 2);
    assertEq(stabilityPool.balanceOf(user2), USER_DEPOSIT / 2);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertGt(_claimed, 0);

    vm.prank(user2);
    uint256 _claimedUser2 = stabilityPool.claimRewards();
    assertEq(_claimedUser2, 0);

    vm.expectRevert(IStabilityPool.StabilityPool_RewardsInactive.selector);
    stabilityPool.claimRewardsFromEmissionsController();
  }

  function test_enable_transfers_cutover_with_emergency_kite_withdraw_keeps_user_exit_functional() public {
    vm.warp(block.timestamp + 1 days);

    vm.prank(user);
    stabilityPool.deposit(USER_DEPOSIT, user);

    vm.warp(block.timestamp + 1 days);
    vm.prank(user);
    uint256 _claimedFromController = stabilityPool.claimRewardsFromEmissionsController();
    assertGt(_claimedFromController, 0);

    uint256 _pendingBeforeEmergencyWithdraw = stabilityPool.pendingRewards(user);
    assertGt(_pendingBeforeEmergencyWithdraw, 0);

    uint256 _poolKiteBeforeEmergencyWithdraw = protocolToken.balanceOf(address(stabilityPool));
    assertGe(_poolKiteBeforeEmergencyWithdraw, _pendingBeforeEmergencyWithdraw);
    uint256 _pendingReduction = _pendingBeforeEmergencyWithdraw / 2;
    assertGt(_pendingReduction, 0);
    uint256 _emergencyWithdrawAmount =
      (_poolKiteBeforeEmergencyWithdraw - _pendingBeforeEmergencyWithdraw) + _pendingReduction;

    uint256 _receiverKiteBefore = protocolToken.balanceOf(postCutoverRewardsReceiver);
    vm.prank(testDeployer);
    stabilityPool.emergencyWithdrawKite(postCutoverRewardsReceiver, _emergencyWithdrawAmount);
    assertEq(protocolToken.balanceOf(postCutoverRewardsReceiver), _receiverKiteBefore + _emergencyWithdrawAmount);

    vm.prank(testDeployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewardsReceiver);
    vm.prank(testDeployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    stabilityPool.transfer(user2, USER_DEPOSIT / 2);

    vm.prank(user);
    uint256 _claimedByUser = stabilityPool.claimRewards();
    assertEq(_claimedByUser, _pendingBeforeEmergencyWithdraw - _pendingReduction);
    assertEq(stabilityPool.claimable(user), _pendingReduction);

    vm.prank(user2);
    uint256 _claimedByUser2 = stabilityPool.claimRewards();
    assertEq(_claimedByUser2, 0);

    vm.prank(user);
    stabilityPool.withdraw(USER_DEPOSIT / 2, user, user);
    vm.prank(user2);
    stabilityPool.withdraw(USER_DEPOSIT / 2, user2, user2);

    assertEq(systemCoin.balanceOf(user), USER_HAI_BALANCE - (USER_DEPOSIT / 2));
    assertEq(systemCoin.balanceOf(user2), USER_HAI_BALANCE + (USER_DEPOSIT / 2));
    assertEq(stabilityPool.totalAssets(), 0);
  }

  function test_enable_transfers_reverts_when_unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.enableTransfers();
  }

  function test_enable_transfers_reverts_when_receiver_is_pool() public {
    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidRewardsReceiver.selector);
    stabilityPool.enableTransfers();
  }

  function test_enable_transfers_reverts_when_already_enabled() public {
    vm.prank(testDeployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewardsReceiver);

    vm.prank(testDeployer);
    stabilityPool.enableTransfers();

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersAlreadyEnabled.selector);
    stabilityPool.enableTransfers();
  }

  function test_preview_swap_to_hai_weth_pipeline_matches_chained_step_previews() public {
    address _veloWethUsdcStep = address(new VeloSwapStep());
    address _veloStep = address(new VeloSwapStep());
    address _curveStep = address(new CurveSwapStep());

    bytes memory _step1Data = _wethToUsdcVeloData();
    bytes memory _step2Data = _usdcToBoldVeloData();
    bytes memory _step3Data = _boldToHaiCurveData();

    _configureWethPipeline(_veloWethUsdcStep, _veloStep, _curveStep, _step1Data, _step2Data, _step3Data);

    uint256 _amountIn = 1e18;
    uint256 _step1Out = VeloSwapStep(_veloWethUsdcStep).preview(_step1Data, _amountIn)[0];
    assertGt(_step1Out, 0, 'WETH->USDC preview should be > 0');
    uint256 _step2Out = VeloSwapStep(_veloStep).preview(_step2Data, _step1Out)[0];
    assertGt(_step2Out, 0, 'USDC->BOLD preview should be > 0');
    uint256 _manualExpected = CurveSwapStep(_curveStep).preview(_step3Data, _step2Out)[0];
    assertGt(_manualExpected, 0, 'BOLD->HAI preview should be > 0');

    uint256 _poolPreview = stabilityPool.previewSwapToHai(WETH_CTYPE, _amountIn);
    assertEq(_poolPreview, _manualExpected);
    assertGt(_poolPreview, 0);
  }

  function test_preview_swap_to_hai_weth_pipeline_nonzero_output() public {
    VeloSwapStep _veloWethUsdcStep = new VeloSwapStep();
    VeloSwapStep _veloStep = new VeloSwapStep();
    CurveSwapStep _curveStep = new CurveSwapStep();

    _configureWethPipeline(
      address(_veloWethUsdcStep),
      address(_veloStep),
      address(_curveStep),
      _wethToUsdcVeloData(),
      _usdcToBoldVeloData(),
      _boldToHaiCurveData()
    );

    uint256 _expectedHai = stabilityPool.previewSwapToHai(WETH_CTYPE, 1e18);
    assertGt(_expectedHai, 0, 'previewSwapToHai should return non-zero HAI for 1 WETH');
  }

  // --- Strategy Configuration ---

  function test_set_strategy_steps_configures_multi_step_strategy() public {
    address _balancerStep = address(new BalancerV3StablePoolMathSwapStep());
    address _erc4626Step = address(new ERC4626WithdrawalStep());

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_balancerStep, true);
    stabilityPool.setStepWhitelist(_erc4626Step, true);

    bytes32 _cType = bytes32('RETH');

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](2);
    _steps[0] = IStabilityPool.StepConfig({step: _balancerStep, data: bytes('balancer-data'), slippageBps: 50});
    _steps[1] = IStabilityPool.StepConfig({step: _erc4626Step, data: bytes('erc4626-data'), slippageBps: 100});

    stabilityPool.setStrategySteps(_cType, _steps);
    vm.stopPrank();

    assertEq(stabilityPool.strategyStepsLength(_cType), 2);

    IStabilityPool.StepConfig memory _stored0 = stabilityPool.strategySteps(_cType, 0);
    assertEq(_stored0.step, _balancerStep);
    assertEq(_stored0.slippageBps, 50);

    IStabilityPool.StepConfig memory _stored1 = stabilityPool.strategySteps(_cType, 1);
    assertEq(_stored1.step, _erc4626Step);
    assertEq(_stored1.slippageBps, 100);
  }

  function test_clear_strategy_steps_removes_configuration() public {
    address _balancerStep = address(new BalancerV3StablePoolMathSwapStep());

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_balancerStep, true);

    bytes32 _cType = bytes32('RETH');

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: _balancerStep, data: bytes('data'), slippageBps: 50});

    stabilityPool.setStrategySteps(_cType, _steps);
    assertEq(stabilityPool.strategyStepsLength(_cType), 1);

    stabilityPool.clearStrategySteps(_cType);
    vm.stopPrank();

    assertEq(stabilityPool.strategyStepsLength(_cType), 0);
  }

  function test_clear_strategy_steps_reverts_when_unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.clearStrategySteps(WETH_CTYPE);
  }

  function test_set_strategy_steps_reverts_on_empty_steps() public {
    bytes32 _cType = bytes32('RETH');
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](0);

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.setStrategySteps(_cType, _steps);
  }

  function test_set_strategy_steps_reverts_when_unauthorized() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](0);

    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStrategySteps(WETH_CTYPE, _steps);
  }

  function test_set_strategy_steps_reverts_on_non_whitelisted_step() public {
    address _nonWhitelisted = address(new BalancerV3StablePoolMathSwapStep());
    bytes32 _cType = bytes32('RETH');

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: _nonWhitelisted, data: bytes('data'), slippageBps: 50});

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStrategySteps(_cType, _steps);
  }

  function test_set_strategy_steps_reverts_on_zero_address() public {
    bytes32 _cType = bytes32('RETH');

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: address(0), data: bytes('data'), slippageBps: 50});

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStrategySteps(_cType, _steps);
  }

  function test_set_strategy_steps_reverts_on_invalid_slippage_bps() public {
    address _step = address(new BalancerV3StablePoolMathSwapStep());

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_step, true);

    bytes32 _cType = bytes32('RETH');
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: _step, data: bytes('data'), slippageBps: 10_001});

    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setStrategySteps(_cType, _steps);
    vm.stopPrank();
  }

  function test_set_strategy_steps_overwrites_previous_config() public {
    address _step1 = address(new BalancerV3StablePoolMathSwapStep());
    address _step2 = address(new ERC4626WithdrawalStep());

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_step1, true);
    stabilityPool.setStepWhitelist(_step2, true);

    bytes32 _cType = bytes32('RETH');

    IStabilityPool.StepConfig[] memory _steps1 = new IStabilityPool.StepConfig[](2);
    _steps1[0] = IStabilityPool.StepConfig({step: _step1, data: bytes('old-data-1'), slippageBps: 50});
    _steps1[1] = IStabilityPool.StepConfig({step: _step2, data: bytes('old-data-2'), slippageBps: 100});
    stabilityPool.setStrategySteps(_cType, _steps1);
    assertEq(stabilityPool.strategyStepsLength(_cType), 2);

    IStabilityPool.StepConfig[] memory _steps2 = new IStabilityPool.StepConfig[](1);
    _steps2[0] = IStabilityPool.StepConfig({step: _step2, data: bytes('new-data'), slippageBps: 200});
    stabilityPool.setStrategySteps(_cType, _steps2);
    vm.stopPrank();

    assertEq(stabilityPool.strategyStepsLength(_cType), 1);
    IStabilityPool.StepConfig memory _stored = stabilityPool.strategySteps(_cType, 0);
    assertEq(_stored.step, _step2);
    assertEq(_stored.slippageBps, 200);
  }

  // --- Step Whitelist ---

  function test_set_step_whitelist_whitelists_step() public {
    address _step = address(new BalancerV3StablePoolMathSwapStep());

    assertEq(stabilityPool.isWhitelistedStep(_step), false);

    vm.prank(testDeployer);
    stabilityPool.setStepWhitelist(_step, true);

    assertEq(stabilityPool.isWhitelistedStep(_step), true);
  }

  function test_set_step_whitelist_removes_from_whitelist() public {
    address _step = address(new BalancerV3StablePoolMathSwapStep());

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_step, true);
    assertEq(stabilityPool.isWhitelistedStep(_step), true);

    stabilityPool.setStepWhitelist(_step, false);
    vm.stopPrank();

    assertEq(stabilityPool.isWhitelistedStep(_step), false);
  }

  function test_set_step_whitelist_reverts_on_zero_address() public {
    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStepWhitelist(address(0), true);
  }

  function test_set_step_whitelist_reverts_when_unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStepWhitelist(address(0xBEEF), true);
  }

  // --- Slippage Config ---

  function test_set_collateral_slippage_bps_sets_slippage() public {
    bytes32 _cType = bytes32('RETH');

    vm.prank(testDeployer);
    stabilityPool.setCollateralSlippageBps(_cType, 500);

    assertEq(stabilityPool.collateralSlippageBps(_cType), 500);
  }

  function test_set_collateral_slippage_bps_reverts_on_invalid_bps() public {
    bytes32 _cType = bytes32('RETH');

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setCollateralSlippageBps(_cType, 10_001);
  }

  function test_set_collateral_slippage_bps_reverts_when_unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setCollateralSlippageBps(WETH_CTYPE, 100);
  }

  function test_set_step_type_slippage_bps_sets_slippage() public {
    bytes32 _stepType = bytes32('BALANCER_V3_SWAP');

    vm.prank(testDeployer);
    stabilityPool.setStepTypeSlippageBps(_stepType, 300);

    assertEq(stabilityPool.stepTypeSlippageBps(_stepType), 300);
  }

  function test_set_step_type_slippage_bps_reverts_on_invalid_bps() public {
    bytes32 _stepType = bytes32('BALANCER_V3_SWAP');

    vm.prank(testDeployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setStepTypeSlippageBps(_stepType, 10_001);
  }

  function test_set_step_type_slippage_bps_reverts_when_unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStepTypeSlippageBps(bytes32('BALANCER_V3_SWAP'), 100);
  }

  function test_transfer_reverts_when_transfers_disabled() public {
    vm.prank(address(0xABCD));
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersDisabled.selector);
    stabilityPool.transfer(address(0xCAFE), 1);
  }

  function test_preview_swap_to_hai_reverts_on_invalid_collateral_join() public {
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidCollateralJoin.selector);
    stabilityPool.previewSwapToHai(bytes32('INVALID_CTYPE'), 1e18);
  }

  function test_mark_minting_rewards_distributed_reverts_when_unauthorized() public {
    vm.prank(address(0xBEEF));
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.markMintingRewardsDistributed(1e18);
  }

  function test_mark_minting_rewards_distributed_updates_minting_distribution() public {
    vm.warp(block.timestamp + 30 days);

    uint256 _toDistribute = emissionsController.getMintingRewardsToDistribute();
    uint256 _markAmount = _toDistribute / 2;

    vm.prank(testDeployer);
    emissionsController.markMintingRewardsDistributed(_markAmount);

    assertEq(emissionsController.mintingRewardsLastDistributed(), _markAmount);
    assertEq(emissionsController.getMintingRewardsToDistribute(), _toDistribute - _markAmount);
  }

  function test_mark_minting_rewards_distributed_zero_amount_leaves_state_unchanged() public {
    vm.warp(block.timestamp + 30 days);

    uint256 _toDistributeBefore = emissionsController.getMintingRewardsToDistribute();
    uint256 _lastDistributedBefore = emissionsController.mintingRewardsLastDistributed();

    vm.prank(testDeployer);
    emissionsController.markMintingRewardsDistributed(0);

    assertEq(emissionsController.getMintingRewardsToDistribute(), _toDistributeBefore);
    assertEq(emissionsController.mintingRewardsLastDistributed(), _lastDistributedBefore);
  }

  function test_mark_minting_rewards_distributed_clamps_when_amount_exceeds_available() public {
    vm.warp(block.timestamp + 30 days);

    uint256 _toDistribute = emissionsController.getMintingRewardsToDistribute();
    assertGt(_toDistribute, 0);

    vm.prank(testDeployer);
    emissionsController.markMintingRewardsDistributed(type(uint256).max);

    assertEq(emissionsController.mintingRewardsLastDistributed(), _toDistribute);
    assertEq(emissionsController.getMintingRewardsToDistribute(), 0);
  }

  // --- Helpers ---

  function _updateRewardSplitWithMockedPrices(uint256 _redemptionPrice, uint256 _marketPrice) internal {
    vm.mockCall(address(oracleRelayer), abi.encodeWithSignature('calcRedemptionPrice()'), abi.encode(_redemptionPrice));
    vm.mockCall(address(oracleRelayer), abi.encodeWithSignature('marketPrice()'), abi.encode(_marketPrice));

    vm.warp(block.timestamp + HOUR + 1);
    emissionsController.updateRewardSplit();
  }

  function _configureWethPipeline(
    address _veloCLStep,
    address _veloStep,
    address _curveStep,
    bytes memory _step1Data,
    bytes memory _step2Data,
    bytes memory _step3Data
  ) internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](3);
    _steps[0] = IStabilityPool.StepConfig({step: _veloCLStep, data: _step1Data, slippageBps: 0});
    _steps[1] = IStabilityPool.StepConfig({step: _veloStep, data: _step2Data, slippageBps: 0});
    _steps[2] = IStabilityPool.StepConfig({step: _curveStep, data: _step3Data, slippageBps: 0});

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_veloCLStep, true);
    stabilityPool.setStepWhitelist(_veloStep, true);
    stabilityPool.setStepWhitelist(_curveStep, true);
    stabilityPool.setStrategySteps(WETH_CTYPE, _steps);
    vm.stopPrank();
  }

  function _configureWethPipelineTwoStep(
    address _veloWethUsdcStep,
    address _veloUsdcHaiStep,
    bytes memory _step1Data,
    bytes memory _step2Data
  ) internal {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](2);
    _steps[0] = IStabilityPool.StepConfig({step: _veloWethUsdcStep, data: _step1Data, slippageBps: 0});
    _steps[1] = IStabilityPool.StepConfig({step: _veloUsdcHaiStep, data: _step2Data, slippageBps: 0});

    vm.startPrank(testDeployer);
    stabilityPool.setStepWhitelist(_veloWethUsdcStep, true);
    stabilityPool.setStepWhitelist(_veloUsdcHaiStep, true);
    stabilityPool.setStrategySteps(WETH_CTYPE, _steps);
    vm.stopPrank();
  }

  function _wethToUsdcVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: WETH_ADDR,
        tokenOut: USDC_ADDR,
        stable: false,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _usdcToBoldVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: USDC_ADDR,
        tokenOut: BOLD_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _usdcToHaiVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: USDC_ADDR,
        tokenOut: HAI_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _boldToHaiCurveData() internal view returns (bytes memory _data) {
    _data = abi.encode(
      CurveSwapStep.Data({
        pool: CURVE_POOL,
        i: int128(1),
        j: int128(0),
        tokenIn: BOLD_ADDR,
        tokenOut: HAI_ADDR,
        useOracleFloor: true,
        tokenInOracle: address(boldUsdOracle),
        tokenOutOracle: HAI_USD_ORACLE,
        oracleToleranceBps: CURVE_ORACLE_TOLERANCE_BPS
      })
    );
  }

  function _expectedSplitFromPrices(
    uint256 _redemptionPrice,
    uint256 _marketPrice
  ) internal pure returns (uint256 _expectedSplit) {
    int256 _numerator = int256(_redemptionPrice) - int256(_marketPrice);
    int256 _deviationWad = (_numerator * int256(WAD)) / int256(_redemptionPrice);

    if (_deviationWad >= int256(DEVIATION_LIMIT)) {
      return 100;
    }
    if (_deviationWad <= -int256(DEVIATION_LIMIT)) {
      return 0;
    }

    int256 _scaledDeviation = (_deviationWad * 50) / int256(DEVIATION_LIMIT);
    int256 _newSplit = 50 + _scaledDeviation;

    if (_newSplit < 0) {
      return 0;
    }
    if (_newSplit > 100) {
      return 100;
    }

    return uint256(_newSplit);
  }
}

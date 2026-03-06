// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {StabilityPool} from '@contracts/stability-pool/StabilityPool.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {
  MockStabilityPoolEmissionsControllerForTest,
  MockStabilityPoolStrategyStepForTest,
  MockReentrantStabilityPoolEmissionsControllerForTest,
  MockRevertingERC20ForTest
} from '@test/mocks/stability-pool/core/StabilityPoolCoreForTest.sol';
import {
  MockCollateralJoinFactoryForTest,
  MockCollateralAuctionHouseFactoryForTest,
  MockCollateralJoinForTest,
  MockSingleOutputMultiplierStepForTest,
  MockAuctionHouseForTest
} from '@test/mocks/stability-pool/admin/StabilityPoolAdminForTest.sol';
import {
  MockSAFEEngineForTest,
  MockCoinJoinForTest,
  MockCoverAuctionHouseForTest
} from '@test/mocks/stability-pool/cover-flow/StabilityPoolCoverFlowForTest.sol';
import {
  MockConfigurableStrategyStepForTest,
  MockManyOutputsStrategyStepForTest,
  MockPreviewLengthMismatchStepForTest,
  MockExecuteLengthMismatchStepForTest,
  MockRevertNoReasonStepForTest,
  MockRevertReasonStepForTest
} from '@test/mocks/stability-pool/strategy/StabilityPoolStrategyFailureForTest.sol';

uint256 constant RAY = 1e27;

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address user = label('user');
  address user2 = label('user2');
  address postCutoverRewards = label('postCutoverRewards');

  ERC20ForTest systemCoin;
  ERC20ForTest protocolToken;
  MockStabilityPoolEmissionsControllerForTest emissionsController;
  StabilityPool stabilityPool;
  MockStabilityPoolStrategyStepForTest strategyStep;

  function setUp() public virtual {
    vm.startPrank(deployer);

    systemCoin = new ERC20ForTest();
    protocolToken = new ERC20ForTest();
    emissionsController = new MockStabilityPoolEmissionsControllerForTest(protocolToken, address(0));
    strategyStep = new MockStabilityPoolStrategyStepForTest();

    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      mockContract('CoinJoin'),
      mockContract('CollateralJoinFactory'),
      mockContract('CollateralAuctionHouseFactory')
    );

    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    systemCoin.mint(user, 1000e18);
    systemCoin.mint(user2, 1000e18);

    vm.stopPrank();

    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
    vm.prank(user2);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }
}

contract Unit_StabilityPool_Constructor is Base {
  function test_Set_SystemCoin() public view {
    assertEq(address(stabilityPool.systemCoin()), address(systemCoin));
  }
}

contract Unit_StabilityPool_TransferToggle is Base {
  function test_Revert_Transfer_When_Disabled() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(user);
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersDisabled.selector);
    stabilityPool.transfer(user2, 1e18);
  }

  function test_Revert_EnableTransfers_InvalidReceiver() public {
    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidRewardsReceiver.selector);
    stabilityPool.enableTransfers();
  }

  function test_EnableTransfers_OneWay() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);

    vm.prank(deployer);
    stabilityPool.enableTransfers();

    assertEq(stabilityPool.transfersEnabled(), true);
    assertEq(stabilityPool.kiteRewardsActive(), false);

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersAlreadyEnabled.selector);
    stabilityPool.enableTransfers();
  }

  function test_Transfer_After_Enable() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    stabilityPool.transfer(user2, 10e18);
    assertEq(stabilityPool.balanceOf(user2), 10e18);
  }

  function test_Deposit_DuringReceiverCutover_DoesNotRevert() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);

    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    assertEq(stabilityPool.balanceOf(user), 100e18);
  }

  function test_Mint_DuringReceiverCutover_DoesNotRevert() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);

    vm.prank(user);
    stabilityPool.mint(100e18, user);

    assertEq(stabilityPool.balanceOf(user), 100e18);
  }
}

contract Unit_StabilityPool_Rewards is Base {
  function test_ClaimRewards_Without_Withdraw() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);
    assertEq(protocolToken.balanceOf(user), 10e18);
  }

  function test_ClaimRewards_Twice_DoesNotDoubleCountOrRevert() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    uint256 _firstClaim = stabilityPool.claimRewards();
    assertEq(_firstClaim, 10e18);
    assertEq(stabilityPool.pendingRewards(user), 0);

    vm.prank(user);
    uint256 _secondClaim = stabilityPool.claimRewards();
    assertEq(_secondClaim, 0);
    assertEq(stabilityPool.pendingRewards(user), 0);
    assertEq(protocolToken.balanceOf(user), 10e18);
  }

  function test_FirstDepositor_DoesNotCapture_KiteAccrued_WithoutSupply() public {
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(user);
    uint256 _firstClaim = stabilityPool.claimRewards();
    assertEq(_firstClaim, 0);
    assertEq(stabilityPool.kiteRewardRemaining(), 10e18);

    protocolToken.mint(address(stabilityPool), 5e18);

    vm.prank(user);
    uint256 _secondClaim = stabilityPool.claimRewards();
    assertEq(_secondClaim, 5e18);
    assertEq(protocolToken.balanceOf(user), 5e18);
  }

  function test_Deposit_Does_Not_Grant_PastRewards_To_NewShares() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);
  }

  function test_Withdraw_ClaimsControllerRewards_BeforeBurningLastShares() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    protocolToken.mint(address(emissionsController), 10e18);
    emissionsController.setAmountToClaim(10e18);

    vm.prank(user);
    stabilityPool.redeem(100e18, user, user);

    assertEq(protocolToken.balanceOf(user), 10e18);
    assertEq(stabilityPool.totalSupply(), 0);
    assertEq(protocolToken.balanceOf(address(stabilityPool)), 0);
  }

  function test_PartialWithdraw_DoesNotLose_RemainingRewards() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    stabilityPool.redeem(50e18, user, user);
    assertEq(protocolToken.balanceOf(user), 10e18);

    protocolToken.mint(address(stabilityPool), 10e18);
    vm.prank(user);
    stabilityPool.claimRewards();
    assertEq(protocolToken.balanceOf(user), 20e18);
  }

  function test_ClaimHistoricalRewards_AfterTransferCutover() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    stabilityPool.transfer(user2, 100e18);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);

    vm.prank(user2);
    uint256 _claimedUser2 = stabilityPool.claimRewards();
    assertEq(_claimedUser2, 0);
  }

  function test_PostCutoverTopUp_RestoresUnderfundedHistoricalClaims() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(deployer);
    stabilityPool.emergencyWithdrawKite(postCutoverRewards, 6e18);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    uint256 _firstClaim = stabilityPool.claimRewards();
    assertEq(_firstClaim, 4e18);
    assertEq(stabilityPool.claimable(user), 6e18);

    protocolToken.mint(address(stabilityPool), 6e18);

    vm.prank(user);
    uint256 _secondClaim = stabilityPool.claimRewards();
    assertEq(_secondClaim, 6e18);
    assertEq(stabilityPool.claimable(user), 0);
    assertEq(protocolToken.balanceOf(user), 10e18);
  }

  function test_Revert_ClaimFromEmissions_AfterCutover() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    vm.expectRevert(IStabilityPool.StabilityPool_RewardsInactive.selector);
    stabilityPool.claimRewardsFromEmissionsController();
  }

  function test_Revert_EmergencyWithdrawKite_Unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.emergencyWithdrawKite(user, 1e18);
  }

  function test_EmergencyWithdrawKite_Authorized_DoesNotBlock_Withdrawals() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(deployer);
    stabilityPool.emergencyWithdrawKite(postCutoverRewards, 6e18);

    assertEq(protocolToken.balanceOf(postCutoverRewards), 6e18);
    assertEq(stabilityPool.kiteRewardRemaining(), 4e18);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 4e18);
    assertEq(protocolToken.balanceOf(user), 4e18);
    assertEq(stabilityPool.claimable(user), 6e18);

    vm.prank(user);
    stabilityPool.withdraw(100e18, user, user);
    assertEq(systemCoin.balanceOf(user), 1000e18);
  }
}

contract Unit_StabilityPool_WithdrawLiveness is HaiTest {
  address internal deployer = label('deployer');
  address internal user = label('user');

  ERC20ForTest internal systemCoin;
  MockRevertingERC20ForTest internal protocolToken;
  MockStabilityPoolEmissionsControllerForTest internal emissionsController;
  StabilityPool internal stabilityPool;

  function setUp() public {
    vm.startPrank(deployer);

    systemCoin = new ERC20ForTest();
    protocolToken = new MockRevertingERC20ForTest();
    emissionsController = new MockStabilityPoolEmissionsControllerForTest(protocolToken, address(0));
    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      mockContract('CoinJoin'),
      mockContract('CollateralJoinFactory'),
      mockContract('CollateralAuctionHouseFactory')
    );
    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    vm.stopPrank();

    systemCoin.mint(user, 1000e18);
    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }

  function test_Withdraw_Succeeds_When_RewardTransferFails() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);
    protocolToken.setRevertTransfers(true);

    vm.prank(user);
    stabilityPool.withdraw(100e18, user, user);

    assertEq(systemCoin.balanceOf(user), 1000e18);
    assertEq(protocolToken.balanceOf(user), 0);
    assertEq(stabilityPool.claimable(user), 10e18);
    assertEq(stabilityPool.kiteRewardRemaining(), 10e18);

    protocolToken.setRevertTransfers(false);
    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);
  }

  function test_Withdraw_Succeeds_When_ControllerClaimFails() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    protocolToken.mint(address(emissionsController), 10e18);
    emissionsController.setAmountToClaim(10e18);
    emissionsController.setRevertOnClaim(true);

    vm.prank(user);
    stabilityPool.withdraw(100e18, user, user);

    assertEq(systemCoin.balanceOf(user), 1000e18);
    assertEq(protocolToken.balanceOf(user), 0);
    assertEq(protocolToken.balanceOf(address(emissionsController)), 10e18);
  }
}

contract Unit_StabilityPool_Reentrancy is HaiTest {
  address internal deployer = label('deployer');
  address internal user = label('user');

  ERC20ForTest internal systemCoin;
  ERC20ForTest internal protocolToken;
  MockReentrantStabilityPoolEmissionsControllerForTest internal emissionsController;
  StabilityPool internal stabilityPool;

  function setUp() public {
    vm.startPrank(deployer);

    systemCoin = new ERC20ForTest();
    protocolToken = new ERC20ForTest();
    emissionsController = new MockReentrantStabilityPoolEmissionsControllerForTest(protocolToken, address(0));
    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      mockContract('CoinJoin'),
      mockContract('CollateralJoinFactory'),
      mockContract('CollateralAuctionHouseFactory')
    );
    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    vm.stopPrank();

    systemCoin.mint(user, 1000e18);
    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }

  function test_Revert_Deposit_When_EmissionsController_Reenters() public {
    emissionsController.setReenterClaimRewards(true);

    vm.prank(user);
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    stabilityPool.deposit(1e18, user);
  }

  function test_Deposit_Succeeds_When_EmissionsController_DoesNotReenter() public {
    vm.prank(user);
    uint256 _shares = stabilityPool.deposit(1e18, user);

    assertEq(_shares, 1e18);
    assertEq(stabilityPool.balanceOf(user), 1e18);
  }
}

contract Unit_StabilityPool_StrategyConfig is Base {
  function test_Revert_SetStrategySteps_UnwhitelistedStep() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(address(systemCoin), address(systemCoin)),
      slippageBps: 0
    });

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);
  }

  function test_SetStrategySteps_WhenWhitelisted() public {
    vm.prank(deployer);
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(address(systemCoin), address(systemCoin)),
      slippageBps: 0
    });

    vm.prank(deployer);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);

    assertEq(stabilityPool.strategyStepsLength(bytes32('WSTETH')), 1);
  }

  function test_Revert_SetStrategySteps_Unauthorized() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: address(strategyStep), data: '', slippageBps: 0});

    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);
  }
}

contract Unit_StabilityPool_AdminAndPipelines is HaiTest {
  bytes32 internal constant CTYPE = bytes32('WETH');
  bytes32 internal constant OTHER_CTYPE = bytes32('OP');

  address user = label('user');

  ERC20ForTest systemCoin;
  ERC20ForTest protocolToken;
  MockStabilityPoolEmissionsControllerForTest emissionsController;
  MockCollateralJoinFactoryForTest collateralJoinFactory;
  MockCollateralAuctionHouseFactoryForTest collateralAuctionHouseFactory;
  StabilityPool stabilityPool;
  MockSingleOutputMultiplierStepForTest strategyStep;
  ERC20ForTest collateralToken;
  MockCollateralJoinForTest collateralJoin;

  function setUp() public {
    systemCoin = new ERC20ForTest();
    protocolToken = new ERC20ForTest();
    emissionsController = new MockStabilityPoolEmissionsControllerForTest(protocolToken, address(0));
    collateralJoinFactory = new MockCollateralJoinFactoryForTest();
    collateralAuctionHouseFactory = new MockCollateralAuctionHouseFactoryForTest();
    strategyStep = new MockSingleOutputMultiplierStepForTest();
    collateralToken = new ERC20ForTest();
    collateralJoin = new MockCollateralJoinForTest(collateralToken, 0);

    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      mockContract('CoinJoin'),
      address(collateralJoinFactory),
      address(collateralAuctionHouseFactory)
    );
    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));
    collateralJoinFactory.setCollateralJoin(CTYPE, address(collateralJoin));

    systemCoin.mint(user, 1000e18);
    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }

  function test_ClaimRewardsFromEmissionsController_Success() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    protocolToken.mint(address(emissionsController), 10e18);
    emissionsController.setAmountToClaim(10e18);

    vm.prank(user);
    uint256 _claimedFromController = stabilityPool.claimRewardsFromEmissionsController();

    assertEq(_claimedFromController, 10e18);
    assertEq(stabilityPool.pendingRewards(user), 10e18);
  }

  function test_ClearStrategySteps_RemovesConfig() public {
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(
        MockSingleOutputMultiplierStepForTest.Data({
          tokenIn: address(collateralToken),
          tokenOut: address(systemCoin),
          outputMultiplierWad: 2e18
        })
      ),
      slippageBps: 0
    });
    stabilityPool.setStrategySteps(CTYPE, _steps);
    assertEq(stabilityPool.strategyStepsLength(CTYPE), 1);

    stabilityPool.clearStrategySteps(CTYPE);
    assertEq(stabilityPool.strategyStepsLength(CTYPE), 0);
  }

  function test_StrategySteps_Getter_ReturnsStoredConfig() public {
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    bytes memory _stepData = abi.encode(
      MockSingleOutputMultiplierStepForTest.Data({
        tokenIn: address(collateralToken),
        tokenOut: address(systemCoin),
        outputMultiplierWad: 2e18
      })
    );
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: address(strategyStep), data: _stepData, slippageBps: 123});
    stabilityPool.setStrategySteps(CTYPE, _steps);

    IStabilityPool.StepConfig memory _stored = stabilityPool.strategySteps(CTYPE, 0);
    assertEq(_stored.step, address(strategyStep));
    assertEq(_stored.slippageBps, 123);
    assertEq(_stored.data, _stepData);
  }

  function test_AdminConfig_StepWhitelist_And_SlippageParams() public {
    stabilityPool.setStepWhitelist(address(strategyStep), true);
    assertTrue(stabilityPool.isWhitelistedStep(address(strategyStep)));

    stabilityPool.setStepWhitelist(address(strategyStep), false);
    assertTrue(!stabilityPool.isWhitelistedStep(address(strategyStep)));

    stabilityPool.setCollateralSlippageBps(CTYPE, 123);
    stabilityPool.setStepTypeSlippageBps(bytes32('MOCK'), 456);

    assertEq(stabilityPool.collateralSlippageBps(CTYPE), 123);
    assertEq(stabilityPool.stepTypeSlippageBps(bytes32('MOCK')), 456);
  }

  function test_PreviewSwapToHai_UsesConfiguredPipeline() public {
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(
        MockSingleOutputMultiplierStepForTest.Data({
          tokenIn: address(collateralToken),
          tokenOut: address(systemCoin),
          outputMultiplierWad: 2e18
        })
      ),
      slippageBps: 0
    });
    stabilityPool.setStrategySteps(CTYPE, _steps);

    uint256 _expectedHai = stabilityPool.previewSwapToHai(CTYPE, 5e18);
    assertEq(_expectedHai, 10e18);
  }

  function test_CoverAndRepayDebt_Reverts_OnCollateralTypeMismatch() public {
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(address(collateralToken), address(systemCoin), 1e18),
      slippageBps: 0
    });
    stabilityPool.setStrategySteps(CTYPE, _steps);

    MockAuctionHouseForTest _auction = new MockAuctionHouseForTest(OTHER_CTYPE);
    collateralAuctionHouseFactory.setCollateralAuctionHouse(CTYPE, address(_auction));

    vm.expectRevert(IStabilityPool.StabilityPool_CollateralTypeMismatch.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 1e18, CTYPE);
  }
}

contract Unit_StabilityPool_CoverAndRepayFlow is HaiTest {
  bytes32 internal constant CTYPE = bytes32('WETH');
  bytes32 internal constant OTHER_CTYPE = bytes32('OTHER');
  uint256 internal constant SWEEP_COOLDOWN = 1 hours;

  address internal deployer = label('deployer');
  address internal user = label('user');

  ERC20ForTest internal systemCoin;
  ERC20ForTest internal protocolToken;
  ERC20ForTest internal collateralToken;

  MockStabilityPoolEmissionsControllerForTest internal emissionsController;
  MockSAFEEngineForTest internal safeEngine;
  MockCoinJoinForTest internal coinJoin;
  MockCollateralJoinFactoryForTest internal collateralJoinFactory;
  MockCollateralAuctionHouseFactoryForTest internal collateralAuctionHouseFactory;
  MockCollateralJoinForTest internal collateralJoin;
  StabilityPool internal stabilityPool;

  function setUp() public {
    vm.startPrank(deployer);

    systemCoin = new ERC20ForTest();
    protocolToken = new ERC20ForTest();
    collateralToken = new ERC20ForTest();

    emissionsController = new MockStabilityPoolEmissionsControllerForTest(protocolToken, address(0));
    safeEngine = new MockSAFEEngineForTest();
    coinJoin = new MockCoinJoinForTest(safeEngine, systemCoin);
    collateralJoinFactory = new MockCollateralJoinFactoryForTest();
    collateralAuctionHouseFactory = new MockCollateralAuctionHouseFactoryForTest();
    collateralJoin = new MockCollateralJoinForTest(collateralToken, 0);

    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      address(coinJoin),
      address(collateralJoinFactory),
      address(collateralAuctionHouseFactory)
    );

    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));
    collateralJoinFactory.setCollateralJoin(CTYPE, address(collateralJoin));

    vm.stopPrank();

    systemCoin.mint(address(stabilityPool), 1000e18);
    systemCoin.mint(user, 1000e18);
  }

  function _setSingleStep(address _step, bytes memory _data, uint16 _slippageBps) internal {
    vm.prank(deployer);
    stabilityPool.setStepWhitelist(_step, true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: _step, data: _data, slippageBps: _slippageBps});

    vm.prank(deployer);
    stabilityPool.setStrategySteps(CTYPE, _steps);
  }

  function _mockData(
    address _tokenIn,
    address _tokenOut,
    uint256 _previewMultiplier,
    uint256 _executeMultiplier
  ) internal pure returns (bytes memory _data) {
    _data = abi.encode(
      MockConfigurableStrategyStepForTest.Data({
        tokenIn: _tokenIn,
        tokenOut: _tokenOut,
        previewMultiplierWad: _previewMultiplier,
        executeMultiplierWad: _executeMultiplier
      })
    );
  }

  function _newAuction(bytes32 _auctionCType) internal returns (MockCoverAuctionHouseForTest _auction) {
    _auction = new MockCoverAuctionHouseForTest(_auctionCType, safeEngine);
    collateralAuctionHouseFactory.setCollateralAuctionHouse(CTYPE, address(_auction));
  }

  function test_Constructor_InitializesRegistryAndFlags() public view {
    assertEq(address(stabilityPool.systemCoin()), address(systemCoin));
    assertEq(address(stabilityPool.protocolToken()), address(protocolToken));
    assertEq(address(stabilityPool.emissionsController()), address(emissionsController));
    assertEq(address(stabilityPool.coinJoin()), address(coinJoin));
    assertEq(address(stabilityPool.collateralJoinFactory()), address(collateralJoinFactory));
    assertEq(address(stabilityPool.collateralAuctionHouseFactory()), address(collateralAuctionHouseFactory));
    assertEq(stabilityPool.kiteRewardsActive(), true);
    assertEq(stabilityPool.transfersEnabled(), false);
  }

  function test_Revert_SetStrategySteps_EmptyArray() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](0);

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.setStrategySteps(CTYPE, _steps);
  }

  function test_Revert_SetStrategySteps_InvalidSlippageBps() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    vm.prank(deployer);
    stabilityPool.setStepWhitelist(address(_step), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(_step),
      data: _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18),
      slippageBps: 10_001
    });

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setStrategySteps(CTYPE, _steps);
  }

  function test_Revert_SetStepWhitelist_ZeroAddress() public {
    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStepWhitelist(address(0), true);
  }

  function test_Revert_SetCollateralSlippageBps_InvalidBps() public {
    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setCollateralSlippageBps(CTYPE, 10_001);
  }

  function test_Revert_SetStepTypeSlippageBps_InvalidBps() public {
    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidSlippageBps.selector);
    stabilityPool.setStepTypeSlippageBps(bytes32('STEP'), 10_001);
  }

  function test_Revert_SetCollateralSlippageBps_Unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setCollateralSlippageBps(CTYPE, 100);
  }

  function test_Revert_SetStepTypeSlippageBps_Unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStepTypeSlippageBps(bytes32('STEP'), 100);
  }

  function test_Revert_SetStepWhitelist_Unauthorized() public {
    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStepWhitelist(address(0x1234), true);
  }

  function test_Revert_PreviewSwapToHai_InvalidCollateralJoin() public {
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidCollateralJoin.selector);
    stabilityPool.previewSwapToHai(OTHER_CTYPE, 1e18);
  }

  function test_Revert_PreviewSwapToHai_NoStrategySteps() public {
    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.previewSwapToHai(CTYPE, 1e18);
  }

  function test_Revert_PreviewSwapToHai_StepNotWhitelisted() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 0);

    vm.prank(deployer);
    stabilityPool.setStepWhitelist(address(_step), false);

    vm.expectRevert(IStabilityPool.StabilityPool_StepNotWhitelisted.selector);
    stabilityPool.previewSwapToHai(CTYPE, 1e18);
  }

  function test_Revert_PreviewSwapToHai_InvalidStrategyStep_MismatchedOutputs() public {
    MockPreviewLengthMismatchStepForTest _step = new MockPreviewLengthMismatchStepForTest();
    bytes memory _data = abi.encode(
      MockPreviewLengthMismatchStepForTest.Data({tokenIn: address(collateralToken), tokenOut: address(systemCoin)})
    );
    _setSingleStep(address(_step), _data, 0);

    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.previewSwapToHai(CTYPE, 1e18);
  }

  function test_PreviewSwapToHai_Supports_MoreThanEightStepOutputs() public {
    MockManyOutputsStrategyStepForTest _step = new MockManyOutputsStrategyStepForTest();

    address[] memory _tokenOuts = new address[](9);
    uint256[] memory _previewRatios = new uint256[](9);
    uint256[] memory _executeRatios = new uint256[](9);
    for (uint256 _i = 0; _i < 8; _i++) {
      _tokenOuts[_i] = address(new ERC20ForTest());
      _previewRatios[_i] = 1e18;
      _executeRatios[_i] = 1e18;
    }
    _tokenOuts[8] = address(systemCoin);
    _previewRatios[8] = 2e18;
    _executeRatios[8] = 2e18;

    bytes memory _data = abi.encode(
      MockManyOutputsStrategyStepForTest.Data({
        tokenIn: address(collateralToken),
        tokenOuts: _tokenOuts,
        previewRatiosWad: _previewRatios,
        executeRatiosWad: _executeRatios
      })
    );

    _setSingleStep(address(_step), _data, 0);

    uint256 _expectedHai = 2e18;
    uint256 _previewHai = stabilityPool.previewSwapToHai(CTYPE, 1e18);
    assertEq(_previewHai, _expectedHai);
  }

  function test_Revert_CoverAndRepayDebt_NoStrategySteps() public {
    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);

    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 1e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_InvalidAuctionHouse() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 0);

    MockCoverAuctionHouseForTest _auction = new MockCoverAuctionHouseForTest(CTYPE, safeEngine);
    _auction.setQuote(10e18, 8e18, 10e18, 7e18);

    vm.expectRevert(IStabilityPool.StabilityPool_InvalidAuctionHouse.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
  }

  function test_CoverAndRepayDebt_ReturnsZero_WhenEstimatedCollateralIsZero() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(0, 0, 0, 0);

    int256 _profit = stabilityPool.coverAndRepayDebt(address(_auction), 1, 1e18, CTYPE);
    assertTrue(_profit == 0);
    assertEq(coinJoin.joinCalls(), 0);
  }

  function test_Revert_CoverAndRepayDebt_NotProfitable_DuringPreview() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 11e18, 10e18, 10e18);

    vm.expectRevert(IStabilityPool.StabilityPool_NotProfitable.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 11e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_DelegatecallFailed_NoReason() public {
    MockRevertNoReasonStepForTest _step = new MockRevertNoReasonStepForTest();
    bytes memory _data =
      abi.encode(MockRevertNoReasonStepForTest.Data({tokenIn: address(collateralToken), tokenOut: address(systemCoin)}));
    _setSingleStep(address(_step), _data, 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 5e18, 10e18, 5e18);

    vm.expectRevert(IStabilityPool.StabilityPool_DelegatecallFailed.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_DelegatecallFailed_BubblesReason() public {
    MockRevertReasonStepForTest _step = new MockRevertReasonStepForTest();
    bytes memory _data =
      abi.encode(MockRevertReasonStepForTest.Data({tokenIn: address(collateralToken), tokenOut: address(systemCoin)}));
    _setSingleStep(address(_step), _data, 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 5e18, 10e18, 5e18);

    vm.expectRevert(MockRevertReasonStepForTest.MockRevertReasonStepForTest_Reverted.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_InvalidStrategyStep_ExecuteLengthMismatch() public {
    MockExecuteLengthMismatchStepForTest _step = new MockExecuteLengthMismatchStepForTest();
    bytes memory _data = abi.encode(
      MockExecuteLengthMismatchStepForTest.Data({tokenIn: address(collateralToken), tokenOut: address(systemCoin)})
    );
    _setSingleStep(address(_step), _data, 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 5e18, 10e18, 5e18);

    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_NotProfitable_WhenStepOutputBelowMinOut() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 2e18, 1e18), 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 8e18, 10e18, 7e18);

    vm.expectRevert(IStabilityPool.StabilityPool_NotProfitable.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
  }

  function test_Revert_CoverAndRepayDebt_NotProfitable_AfterExecuteFinalCheck() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 1000);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 9e18, 10e18, 11e18);

    vm.expectRevert(IStabilityPool.StabilityPool_NotProfitable.selector);
    stabilityPool.coverAndRepayDebt(address(_auction), 1, 11e18, CTYPE);
  }

  function test_CoverAndRepayDebt_Success_ProfitAndCoinJoinAccounting() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 2e18, 2e18), 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 8e18, 10e18, 7e18);

    int256 _profit = stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);

    assertTrue(_profit > 0);
    assertEq(uint256(_profit), 13e18);
    assertEq(coinJoin.joinCalls(), 1);
    assertEq(coinJoin.lastJoinWad(), 10e18);
    assertEq(coinJoin.exitCalls(), 1);
    assertEq(coinJoin.lastExitWad(), 3e18);
    assertEq(safeEngine.approveCalls(address(coinJoin)), 1);
    assertEq(safeEngine.approveCalls(address(_auction)), 1);
  }

  function test_CoverAndRepayDebt_TradesOnlyNewlyBoughtCollateral() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 1e18, 1e18), 0);

    // Seed unrelated collateral inventory that should not be included in this cover execution.
    collateralToken.mint(address(stabilityPool), 100e18);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 8e18, 10e18, 7e18);

    int256 _profit = stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
    assertEq(uint256(_profit), 3e18);
  }

  function test_CoverAndRepayDebt_ApproveAuctionHouse_OnlyOnce() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 2e18, 2e18), 0);

    safeEngine.setCoinBalance(address(stabilityPool), 100e18 * RAY);
    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(1e18, 1e18, 1e18, 1e18);

    stabilityPool.coverAndRepayDebt(address(_auction), 1, 1e18, CTYPE);
    stabilityPool.coverAndRepayDebt(address(_auction), 2, 1e18, CTYPE);

    assertEq(safeEngine.approveCalls(address(_auction)), 1);
    assertEq(coinJoin.joinCalls(), 0);
  }

  function test_CoverAndRepayDebt_UsesCollateralMultiplierConversion() public {
    MockCollateralJoinForTest _scaledJoin = new MockCollateralJoinForTest(collateralToken, 2);
    vm.prank(deployer);
    collateralJoinFactory.setCollateralJoin(CTYPE, address(_scaledJoin));

    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 2e18, 2e18), 0);

    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(500e18, 8e18, 500e18, 7e18);

    int256 _profit = stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
    assertEq(_scaledJoin.lastExitAmount(), 5e18);
    assertEq(uint256(_profit), 3e18);
  }

  function test_CoverAndRepayDebt_DoesNotJoin_WhenInternalCoinIsSufficient() public {
    MockConfigurableStrategyStepForTest _step = new MockConfigurableStrategyStepForTest(bytes32('STEP'));
    _setSingleStep(address(_step), _mockData(address(collateralToken), address(systemCoin), 2e18, 2e18), 0);

    safeEngine.setCoinBalance(address(stabilityPool), 20e18 * RAY);
    MockCoverAuctionHouseForTest _auction = _newAuction(CTYPE);
    _auction.setQuote(10e18, 8e18, 10e18, 7e18);

    stabilityPool.coverAndRepayDebt(address(_auction), 1, 10e18, CTYPE);
    assertEq(coinJoin.joinCalls(), 0);
  }

  function test_Revert_SweepInternalCoin_TooFrequent() public {
    vm.expectRevert(IStabilityPool.StabilityPool_InternalCoinSweepTooFrequent.selector);
    stabilityPool.sweepInternalCoin();
  }

  function test_SweepInternalCoin_ExitsAllAvailableWad_Permissionless() public {
    safeEngine.setCoinBalance(address(stabilityPool), 13e18 * RAY);

    uint256 _haiBefore = systemCoin.balanceOf(address(stabilityPool));
    vm.warp(block.timestamp + SWEEP_COOLDOWN + 1);

    vm.prank(user);
    uint256 _exited = stabilityPool.sweepInternalCoin();

    assertEq(_exited, 13e18);
    assertEq(systemCoin.balanceOf(address(stabilityPool)), _haiBefore + 13e18);
    assertEq(safeEngine.coinBalance(address(stabilityPool)), 0);
    assertEq(coinJoin.exitCalls(), 1);
    assertEq(coinJoin.lastExitWad(), 13e18);
  }

  function test_SweepInternalCoin_LeavesRadDust() public {
    safeEngine.setCoinBalance(address(stabilityPool), 5e18 * RAY + 7);

    vm.warp(block.timestamp + SWEEP_COOLDOWN + 1);
    uint256 _exited = stabilityPool.sweepInternalCoin();

    assertEq(_exited, 5e18);
    assertEq(safeEngine.coinBalance(address(stabilityPool)), 7);
    assertEq(coinJoin.lastExitWad(), 5e18);
  }

  function test_SweepInternalCoin_ZeroBalance_DoesNotUpdateCooldown() public {
    uint256 _lastSweepBefore = stabilityPool.lastInternalCoinSweepTime();
    vm.warp(block.timestamp + SWEEP_COOLDOWN + 1);
    uint256 _exited = stabilityPool.sweepInternalCoin();

    assertEq(_exited, 0);
    assertEq(stabilityPool.lastInternalCoinSweepTime(), _lastSweepBefore);
    assertEq(coinJoin.exitCalls(), 0);

    uint256 _secondExited = stabilityPool.sweepInternalCoin();
    assertEq(_secondExited, 0);
    assertEq(stabilityPool.lastInternalCoinSweepTime(), _lastSweepBefore);
  }

  function test_SweepInternalCoin_CooldownResetsAfterSuccessfulCall() public {
    safeEngine.setCoinBalance(address(stabilityPool), 1e18 * RAY);
    vm.warp(block.timestamp + SWEEP_COOLDOWN + 1);
    uint256 _firstExited = stabilityPool.sweepInternalCoin();
    assertEq(_firstExited, 1e18);

    vm.expectRevert(IStabilityPool.StabilityPool_InternalCoinSweepTooFrequent.selector);
    stabilityPool.sweepInternalCoin();

    safeEngine.setCoinBalance(address(stabilityPool), 2e18 * RAY);
    vm.warp(block.timestamp + SWEEP_COOLDOWN + 1);
    uint256 _secondExited = stabilityPool.sweepInternalCoin();
    assertEq(_secondExited, 2e18);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {EmissionsController} from '@contracts/stability-pool/EmissionsController.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {MockOracleRelayerForTest} from '@test/mocks/stability-pool/core/EmissionsControllerForTest.sol';

uint256 constant YEAR = 365 days;
uint256 constant WAD = 1e18;
uint256 constant HOUR = 1 hours;

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address receiver = label('receiver');
  address nextReceiver = label('nextReceiver');
  address randomUser = label('randomUser');

  ERC20ForTest kite;
  MockOracleRelayerForTest mockOracleRelayer;
  EmissionsController emissionsController;

  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;

  function setUp() public virtual {
    vm.startPrank(deployer);

    kite = new ERC20ForTest();
    mockOracleRelayer = new MockOracleRelayerForTest();
    emissionsController =
      new EmissionsController(kite, IOracleRelayer(address(mockOracleRelayer)), receiver, TOTAL_KITE, 0.1e18);

    kite.mint(address(emissionsController), TOTAL_KITE);

    vm.stopPrank();
  }
}

contract Unit_EmissionsController_ClaimRewards is Base {
  function test_Revert_OnlyReceiverCanClaim() public {
    vm.prank(randomUser);
    vm.expectRevert(IEmissionsController.EmissionsController_OnlyStabilityRewardsReceiver.selector);
    emissionsController.claimRewardsForStabilityPool();
  }

  function test_Claim_By_CurrentReceiver() public {
    vm.warp(block.timestamp + 10);

    uint256 _before = kite.balanceOf(receiver);
    vm.prank(receiver);
    uint256 _claimed = emissionsController.claimRewardsForStabilityPool();

    assertGt(_claimed, 0);
    assertEq(kite.balanceOf(receiver), _before + _claimed);
  }
}

contract Unit_EmissionsController_SetReceiver is Base {
  function test_Revert_Unauthorized() public {
    vm.prank(randomUser);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.setStabilityRewardsReceiver(nextReceiver);
  }

  function test_Revert_NullReceiver() public {
    vm.prank(deployer);
    vm.expectRevert(IEmissionsController.EmissionsController_InvalidStabilityReceiver.selector);
    emissionsController.setStabilityRewardsReceiver(address(0));
  }

  function test_SetReceiver_TransfersAccrued_ToOldReceiver() public {
    vm.warp(block.timestamp + 5);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(nextReceiver);

    assertGt(kite.balanceOf(receiver), 0);
    assertEq(emissionsController.stabilityRewardsReceiver(), nextReceiver);
  }

  function test_NewReceiver_Claims_AfterSwitch() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(nextReceiver);

    vm.warp(block.timestamp + 5);
    vm.prank(nextReceiver);
    uint256 _claimed = emissionsController.claimRewardsForStabilityPool();
    assertGt(_claimed, 0);
    assertEq(kite.balanceOf(nextReceiver), _claimed);
  }
}

contract Unit_EmissionsController_MintingMarking is Base {
  function test_Revert_MarkMintingRewardsDistributed_Unauthorized() public {
    vm.prank(randomUser);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.markMintingRewardsDistributed(1e18);
  }

  function test_MarkMintingRewardsDistributed_Authorized() public {
    vm.warp(block.timestamp + 20);

    vm.prank(deployer);
    emissionsController.markMintingRewardsDistributed(type(uint256).max);

    assertGt(emissionsController.mintingRewardsLastDistributed(), 0);
  }
}

contract Unit_EmissionsController_UpdateSplit is Base {
  function test_Revert_InvalidRedemptionPrice() public {
    vm.warp(block.timestamp + HOUR + 1);

    mockOracleRelayer.setPrices(0, 1e27);
    vm.expectRevert(IEmissionsController.EmissionsController_InvalidRedemptionPrice.selector);
    emissionsController.updateRewardSplit();
  }
}

abstract contract Base_EmissionsControllerCore is HaiTest {
  address deployer = label('deployer');
  address receiver = label('receiver');
  address randomUser = label('randomUser');

  ERC20ForTest kite;
  MockOracleRelayerForTest mockOracleRelayer;
  EmissionsController emissionsController;

  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;

  function setUp() public virtual {
    vm.startPrank(deployer);

    kite = new ERC20ForTest();
    mockOracleRelayer = new MockOracleRelayerForTest();
    emissionsController =
      new EmissionsController(kite, IOracleRelayer(address(mockOracleRelayer)), receiver, TOTAL_KITE, 0.1e18);
    kite.mint(address(emissionsController), TOTAL_KITE);

    vm.stopPrank();
  }
}

contract Unit_EmissionsController_UpdateSplitBounds is Base_EmissionsControllerCore {
  function test_Revert_UpdateSplit_TooFrequent() public {
    vm.expectRevert(IEmissionsController.EmissionsController_SplitUpdateTooFrequent.selector);
    emissionsController.updateRewardSplit();
  }

  function test_UpdateSplit_ClampsTo100_WhenPositiveDeviationExceedsLimit() public {
    vm.warp(block.timestamp + HOUR + 1);
    mockOracleRelayer.setPrices(1e27, 8e26); // +20%

    emissionsController.updateRewardSplit();

    assertEq(emissionsController.stabilityPoolSplit(), 100);
    assertEq(emissionsController.mintingSplit(), 0);
  }

  function test_UpdateSplit_ClampsTo0_WhenNegativeDeviationExceedsLimit() public {
    vm.warp(block.timestamp + HOUR + 1);
    mockOracleRelayer.setPrices(1e27, 12e26); // -20%

    emissionsController.updateRewardSplit();

    assertEq(emissionsController.stabilityPoolSplit(), 0);
    assertEq(emissionsController.mintingSplit(), 100);
  }

  function test_UpdateSplit_Keeps50_AtZeroDeviation() public {
    vm.warp(block.timestamp + HOUR + 1);
    mockOracleRelayer.setPrices(1e27, 1e27);

    emissionsController.updateRewardSplit();

    assertEq(emissionsController.stabilityPoolSplit(), 50);
    assertEq(emissionsController.mintingSplit(), 50);
  }
}

contract Unit_EmissionsController_AccrualViews is Base_EmissionsControllerCore {
  function test_GetAccruedRewardsForStabilityPool_CapsAtEmissionEnd() public {
    vm.warp(emissionsController.emissionEndTime() + 7 days);

    uint256 _accrued = emissionsController.getAccruedRewardsForStabilityPool();
    assertEq(_accrued, TOTAL_KITE / 2);
  }

  function test_GetMintingRewardsToDistribute_AndMarkClampsToAvailable() public {
    vm.warp(block.timestamp + 100);
    uint256 _toDistribute = emissionsController.getMintingRewardsToDistribute();
    assertGt(_toDistribute, 0);

    vm.prank(deployer);
    emissionsController.markMintingRewardsDistributed(type(uint256).max);

    assertEq(emissionsController.getMintingRewardsToDistribute(), 0);
  }

  function test_ClaimRewardsForStabilityPool_ReturnsZero_WhenNoAccrual() public {
    vm.prank(receiver);
    uint256 _claimed = emissionsController.claimRewardsForStabilityPool();
    assertEq(_claimed, 0);
  }
}

contract Unit_EmissionsController_MintingMarkingAuth is Base_EmissionsControllerCore {
  function test_Revert_MarkMintingRewardsDistributed_Unauthorized() public {
    vm.prank(randomUser);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.markMintingRewardsDistributed(1e18);
  }
}

abstract contract Base_EmissionsControllerEdgeCases is HaiTest {
  address internal deployer = label('deployer');
  address internal receiver = label('receiver');
  address internal nextReceiver = label('nextReceiver');

  ERC20ForTest internal kite;
  MockOracleRelayerForTest internal oracle;
  EmissionsController internal emissionsController;

  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;

  function setUp() public virtual {
    vm.startPrank(deployer);

    kite = new ERC20ForTest();
    oracle = new MockOracleRelayerForTest();
    emissionsController = new EmissionsController(kite, IOracleRelayer(address(oracle)), receiver, TOTAL_KITE, 0.1e18);
    kite.mint(address(emissionsController), TOTAL_KITE);

    vm.stopPrank();
  }
}

contract Unit_EmissionsController_ConstructorReverts is HaiTest {
  function test_Revert_Constructor_InvalidStabilityReceiver() public {
    ERC20ForTest _kite = new ERC20ForTest();
    MockOracleRelayerForTest _oracle = new MockOracleRelayerForTest();

    vm.expectRevert(IEmissionsController.EmissionsController_InvalidStabilityReceiver.selector);
    new EmissionsController(_kite, IOracleRelayer(address(_oracle)), address(0), YEAR * 100 * WAD, 0.1e18);
  }
}

contract Unit_EmissionsController_UpdateSplitLinear is Base_EmissionsControllerEdgeCases {
  function test_UpdateSplit_LinearBranch_UpdatesRatesAndTimestamps() public {
    vm.warp(block.timestamp + HOUR + 1);
    oracle.setPrices(1e27, 95e25); // +5% deviation => 75/25 split for 10% limit

    emissionsController.updateRewardSplit();

    uint256 _totalRate = TOTAL_KITE / YEAR;
    assertEq(emissionsController.stabilityPoolSplit(), 75);
    assertEq(emissionsController.mintingSplit(), 25);
    assertEq(emissionsController.currentStabilityPoolRate(), (_totalRate * 75) / 100);
    assertEq(emissionsController.currentMintingRate(), (_totalRate * 25) / 100);
    assertEq(emissionsController.currentRateStartTime(), block.timestamp);
    assertEq(emissionsController.lastSplitUpdateTime(), block.timestamp);
  }
}

contract Unit_EmissionsController_ClaimStartChecks is Base_EmissionsControllerEdgeCases {
  function test_Revert_ClaimRewards_EmissionsNotStarted() public {
    uint256 _start = emissionsController.emissionStartTime();
    if (_start == 0) return;

    vm.warp(_start - 1);
    vm.prank(receiver);
    vm.expectRevert(IEmissionsController.EmissionsController_EmissionsNotStarted.selector);
    emissionsController.claimRewardsForStabilityPool();
  }
}

contract Unit_EmissionsController_SetReceiverBranches is Base_EmissionsControllerEdgeCases {
  function test_SetReceiver_SameReceiver_DoesNotPayoutAccrued() public {
    vm.warp(block.timestamp + 10);
    uint256 _beforeReceiverBalance = kite.balanceOf(receiver);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(receiver);

    assertEq(kite.balanceOf(receiver), _beforeReceiverBalance);
    assertEq(emissionsController.stabilityRewardsReceiver(), receiver);
    assertGt(emissionsController.stabilityPoolCumulativeRewards(), 0);
  }

  function test_SetReceiver_NoAccrual_DoesNotTransfer() public {
    assertEq(emissionsController.stabilityPoolCumulativeRewards(), 0);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(nextReceiver);

    assertEq(kite.balanceOf(receiver), 0);
    assertEq(emissionsController.stabilityRewardsReceiver(), nextReceiver);
    assertEq(emissionsController.stabilityPoolCumulativeRewards(), 0);
  }
}

contract Unit_EmissionsController_MintingMarkingBranches is Base_EmissionsControllerEdgeCases {
  function test_MarkMintingRewardsDistributed_ExactAmount() public {
    vm.warp(block.timestamp + 200);

    uint256 _toDistribute = emissionsController.getMintingRewardsToDistribute();
    uint256 _markAmount = _toDistribute / 2;

    vm.prank(deployer);
    emissionsController.markMintingRewardsDistributed(_markAmount);

    assertEq(emissionsController.mintingRewardsLastDistributed(), _markAmount);
    assertEq(emissionsController.getMintingRewardsToDistribute(), _toDistribute - _markAmount);
  }
}

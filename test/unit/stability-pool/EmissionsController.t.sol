// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {EmissionsController} from '@contracts/stability-pool/EmissionsController.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {
  MockOracleRelayerForTest,
  MockReentrantKiteTokenForTest
} from '@test/mocks/stability-pool/core/EmissionsControllerForTest.sol';

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
      new EmissionsController(kite, IOracleRelayer(address(mockOracleRelayer)), receiver, TOTAL_KITE, YEAR, 0.1e18);

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

contract Unit_EmissionsController_EmergencyWithdrawKite is Base {
  function test_Revert_EmergencyWithdrawKite_Unauthorized() public {
    vm.prank(randomUser);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.emergencyWithdrawKite(nextReceiver, 1e18);
  }

  function test_EmergencyWithdrawKite_Authorized() public {
    vm.prank(deployer);
    emissionsController.emergencyWithdrawKite(nextReceiver, 10e18);

    assertEq(kite.balanceOf(nextReceiver), 10e18);
    assertEq(kite.balanceOf(address(emissionsController)), TOTAL_KITE - 10e18);
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
      new EmissionsController(kite, IOracleRelayer(address(mockOracleRelayer)), receiver, TOTAL_KITE, YEAR, 0.1e18);
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
    emissionsController =
      new EmissionsController(kite, IOracleRelayer(address(oracle)), receiver, TOTAL_KITE, YEAR, 0.1e18);
    kite.mint(address(emissionsController), TOTAL_KITE);

    vm.stopPrank();
  }
}

contract Unit_EmissionsController_ConstructorReverts is HaiTest {
  function test_Revert_Constructor_InvalidStabilityReceiver() public {
    ERC20ForTest _kite = new ERC20ForTest();
    MockOracleRelayerForTest _oracle = new MockOracleRelayerForTest();

    vm.expectRevert(IEmissionsController.EmissionsController_InvalidStabilityReceiver.selector);
    new EmissionsController(_kite, IOracleRelayer(address(_oracle)), address(0), YEAR * 100 * WAD, YEAR, 0.1e18);
  }

  function test_Revert_Constructor_ZeroDuration() public {
    ERC20ForTest _kite = new ERC20ForTest();
    MockOracleRelayerForTest _oracle = new MockOracleRelayerForTest();

    vm.expectRevert(IEmissionsController.EmissionsController_InvalidEmissionDuration.selector);
    new EmissionsController(_kite, IOracleRelayer(address(_oracle)), address(this), YEAR * 100 * WAD, 0, 0.1e18);
  }
}

contract Unit_EmissionsController_CustomDuration is HaiTest {
  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;
  address internal deployer = label('deployer');
  address internal receiver = label('receiver');

  function test_Constructor_CustomDuration_SetsEndTimeAndRates() public {
    uint256 _duration = 2 * YEAR;
    ERC20ForTest _kite = new ERC20ForTest();
    MockOracleRelayerForTest _oracle = new MockOracleRelayerForTest();

    vm.prank(deployer);
    EmissionsController _controller =
      new EmissionsController(_kite, IOracleRelayer(address(_oracle)), receiver, TOTAL_KITE, _duration, 0.1e18);

    uint256 _expectedRate = TOTAL_KITE / _duration;
    assertEq(_controller.emissionEndTime(), _controller.emissionStartTime() + _duration);
    assertEq(_controller.baseEmissionRate(), _expectedRate);
    assertEq(_controller.currentStabilityPoolRate(), (_expectedRate * 50) / 100);
    assertEq(_controller.currentMintingRate(), (_expectedRate * 50) / 100);
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

contract Unit_EmissionsController_Extension is Base_EmissionsControllerEdgeCases {
  function test_Revert_ExtendEmissions_Unauthorized() public {
    vm.prank(nextReceiver);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    emissionsController.extendEmissions(0, 30 days);
  }

  function test_Revert_ExtendEmissions_ZeroDuration() public {
    vm.prank(deployer);
    vm.expectRevert(IEmissionsController.EmissionsController_InvalidEmissionDuration.selector);
    emissionsController.extendEmissions(1e18, 0);
  }

  function test_ExtendEmissions_BeforeEnd_StretchesRemainingRate() public {
    vm.warp(block.timestamp + 30 days);

    uint256 _now = block.timestamp;
    uint256 _oldEndTime = emissionsController.emissionEndTime();
    uint256 _oldBaseRate = emissionsController.baseEmissionRate();
    uint256 _additionalDuration = 180 days;

    vm.prank(deployer);
    emissionsController.extendEmissions(0, _additionalDuration);

    uint256 _remainingAmount = _oldBaseRate * (_oldEndTime - _now);
    uint256 _expectedEndTime = _oldEndTime + _additionalDuration;
    uint256 _expectedBaseRate = _remainingAmount / (_expectedEndTime - _now);

    assertEq(emissionsController.emissionEndTime(), _expectedEndTime);
    assertEq(emissionsController.baseEmissionRate(), _expectedBaseRate);
    assertEq(emissionsController.currentStabilityPoolRate(), (_expectedBaseRate * 50) / 100);
    assertEq(emissionsController.currentMintingRate(), (_expectedBaseRate * 50) / 100);
    assertEq(emissionsController.currentRateStartTime(), _now);
  }

  function test_ExtendEmissions_AfterEnd_WithAdditionalKite_RestartsFromNow() public {
    vm.warp(emissionsController.emissionEndTime() + 7 days);
    uint256 _now = block.timestamp;
    uint256 _oldEndTime = emissionsController.emissionEndTime();
    uint256 _additionalKite = 10_000e18;
    uint256 _additionalDuration = 200 days;

    kite.mint(deployer, _additionalKite);
    vm.startPrank(deployer);
    kite.approve(address(emissionsController), _additionalKite);
    emissionsController.extendEmissions(_additionalKite, _additionalDuration);
    vm.stopPrank();

    uint256 _expectedEndTime = _now + _additionalDuration;
    uint256 _expectedBaseRate = _additionalKite / _additionalDuration;

    assertLt(_oldEndTime, _now);
    assertEq(emissionsController.emissionEndTime(), _expectedEndTime);
    assertEq(emissionsController.baseEmissionRate(), _expectedBaseRate);
    assertEq(emissionsController.lastCheckpointTime(), _now);
    assertEq(emissionsController.currentStabilityPoolRate(), (_expectedBaseRate * 50) / 100);
    assertEq(emissionsController.currentMintingRate(), (_expectedBaseRate * 50) / 100);
  }
}

contract Unit_EmissionsController_Reentrancy is HaiTest {
  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;

  address internal deployer = label('deployer');
  address internal nextReceiver = label('nextReceiver');

  MockReentrantKiteTokenForTest internal kite;
  MockOracleRelayerForTest internal oracle;
  EmissionsController internal emissionsController;

  function setUp() public {
    vm.startPrank(deployer);

    kite = new MockReentrantKiteTokenForTest();
    oracle = new MockOracleRelayerForTest();
    emissionsController =
      new EmissionsController(kite, IOracleRelayer(address(oracle)), address(kite), TOTAL_KITE, YEAR, 0.1e18);
    kite.setController(address(emissionsController));
    kite.mint(address(emissionsController), TOTAL_KITE);

    vm.stopPrank();
  }

  function test_SetReceiver_Blocks_ReentrantClaim_DuringPayout() public {
    vm.warp(block.timestamp + 10);
    kite.setReenterOnTransfer(true);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(nextReceiver);

    assertEq(emissionsController.stabilityRewardsReceiver(), nextReceiver);
    assertFalse(kite.reenterCallSucceeded());
    assertEq(_selector(kite.reenterErrorData()), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
  }

  function _selector(bytes memory _err) internal pure returns (bytes4 _sel) {
    if (_err.length < 4) return bytes4(0);
    assembly {
      _sel := mload(add(_err, 32))
    }
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {EmissionsController} from '@contracts/EmissionsController.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {YEAR, HOUR, WAD} from '@libraries/Math.sol';

contract MockOracleRelayer {
  uint256 public redemptionPrice = 1e27;
  uint256 public marketPrice = 1e27;

  function calcRedemptionPrice() external view returns (uint256 _redemptionPrice) {
    return redemptionPrice;
  }

  function setPrices(uint256 _redemptionPrice, uint256 _marketPrice) external {
    redemptionPrice = _redemptionPrice;
    marketPrice = _marketPrice;
  }
}

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address receiver = label('receiver');
  address nextReceiver = label('nextReceiver');
  address randomUser = label('randomUser');

  ERC20ForTest kite;
  MockOracleRelayer mockOracleRelayer;
  EmissionsController emissionsController;

  uint256 internal constant TOTAL_KITE = YEAR * 100 * WAD;

  function setUp() public virtual {
    vm.startPrank(deployer);

    kite = new ERC20ForTest();
    mockOracleRelayer = new MockOracleRelayer();
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

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';
import {HaiAero} from '@contracts/tokens/HaiAero.sol';
import {
  AeroMigrationTokenMock,
  AeroEscrowMock,
  AeroRootVoterMock,
  AeroTreasuryMock
} from '@test/mocks/AeroMigrationMocks.sol';

contract Unit_HaiAero is Test {
  HaiAero internal wrapper;
  AeroMigrationTokenMock internal aero;
  AeroEscrowMock internal escrow;
  AeroRootVoterMock internal voter;
  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  address internal keeper = makeAddr('keeper');
  AeroTreasuryMock internal treasury;

  function setUp() public {
    vm.chainId(8453);
    aero = new AeroMigrationTokenMock();
    voter = new AeroRootVoterMock();
    escrow = new AeroEscrowMock(address(aero), address(voter));
    treasury = new AeroTreasuryMock();
    wrapper = new HaiAero(address(aero), address(escrow), address(this), address(treasury), 8453);
    aero.mint(alice, 1000 ether);
    vm.prank(alice);
    aero.approve(address(wrapper), type(uint256).max);
  }

  function _depositNFT(uint128 _amount) internal returns (uint256 _id) {
    _id = escrow.mintStake(alice, _amount, true);
    vm.startPrank(alice);
    escrow.approve(address(wrapper), _id);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    wrapper.depositNFTs(bob, _ids);
    vm.stopPrank();
  }

  function test_DefaultPaused() public {
    assertTrue(wrapper.paused());
    vm.expectRevert(Pausable.EnforcedPause.selector);
    vm.prank(alice);
    wrapper.deposit(alice, 1 ether);
  }

  function test_DepositCreatesPermanentStakeAndClearsApproval() public {
    wrapper.unpause();
    vm.prank(alice);
    wrapper.deposit(bob, 20 ether);
    assertEq(wrapper.balanceOf(bob), 20 ether);
    assertEq(wrapper.totalSupply(), wrapper.totalIssuedPrincipal());
    assertEq(escrow.ownerOf(1), address(treasury));
    assertEq(wrapper.backingOf(1), 20 ether);
    assertEq(aero.balanceOf(address(escrow)), 20 ether);
    assertEq(aero.balanceOf(address(wrapper)), 0);
    assertEq(aero.allowance(address(wrapper), address(escrow)), 0);
    assertTrue(escrow.staked(1).isPermanent);
    assertEq(escrow.staked(1).end, 0);
    assertEq(escrow.getApproved(1), address(0));
  }

  function testFuzz_DepositNFTMintsPrincipalNotCount(uint128 _amount) public {
    _amount = uint128(bound(_amount, 1, uint128(type(int128).max)));
    wrapper.unpause();
    uint256 _id = _depositNFT(_amount);
    assertEq(wrapper.balanceOf(bob), _amount);
    assertEq(wrapper.totalIssuedPrincipal(), _amount);
    assertEq(wrapper.principalOf(_id), _amount);
    assertEq(escrow.ownerOf(_id), address(treasury));
  }

  function test_NonPermanentNFTRejected() public {
    wrapper.unpause();
    uint256 _id = escrow.mintStake(alice, 1 ether, false);
    vm.startPrank(alice);
    escrow.approve(address(wrapper), _id);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    vm.expectRevert(abi.encodeWithSelector(HaiAero.UnsupportedStake.selector, _id));
    wrapper.depositNFTs(alice, _ids);
    assertEq(escrow.ownerOf(_id), alice);
  }

  function test_DuplicateNFTBatchRollsBack() public {
    wrapper.unpause();
    uint256 _id = escrow.mintStake(alice, 1 ether, true);
    vm.startPrank(alice);
    escrow.approve(address(wrapper), _id);
    uint256[] memory _ids = new uint256[](2);
    _ids[0] = _id;
    _ids[1] = _id;
    vm.expectRevert(abi.encodeWithSelector(HaiAero.AlreadyDeposited.selector, _id));
    wrapper.depositNFTs(alice, _ids);
    assertEq(wrapper.totalSupply(), 0);
    assertEq(escrow.ownerOf(_id), alice);
  }

  function test_UnsolicitedSafeNFTTransferRejected() public {
    uint256 _id = escrow.mintStake(alice, 1 ether, true);
    vm.expectRevert();
    vm.prank(alice);
    escrow.safeTransferFrom(alice, address(wrapper), _id);
  }

  function test_CannotDepositOtherPersonsApprovedNFT() public {
    wrapper.unpause();
    uint256 _id = escrow.mintStake(alice, 1 ether, true);
    vm.prank(alice);
    escrow.approve(address(wrapper), _id);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    vm.expectRevert(HaiAero.NotNFTOwner.selector);
    vm.prank(bob);
    wrapper.depositNFTs(bob, _ids);
  }

  function test_FeeTokenDepositRollsBack() public {
    wrapper.unpause();
    aero.setFee(true);
    vm.expectRevert(HaiAero.InexactTransfer.selector);
    vm.prank(alice);
    wrapper.deposit(alice, 1 ether);
    assertEq(wrapper.totalSupply(), 0);
    assertEq(aero.balanceOf(alice), 1000 ether);
  }

  function test_WrongChainFailsClosed() public {
    wrapper.unpause();
    vm.chainId(10);
    vm.expectRevert(HaiAero.WrongChain.selector);
    vm.prank(alice);
    wrapper.deposit(alice, 1 ether);
  }

  function test_ZeroAndOverflowAmountsRejected() public {
    wrapper.unpause();
    vm.startPrank(alice);
    vm.expectRevert(HaiAero.InvalidAmount.selector);
    wrapper.deposit(alice, 0);
    vm.expectRevert(HaiAero.InvalidAmount.selector);
    wrapper.deposit(alice, uint256(uint128(type(int128).max)) + 1);
  }

  function test_TreasuryCanRecognizeMigratedNFTOnceWithoutSelfTransfer() public {
    wrapper.unpause();
    uint256 _id = escrow.mintStake(address(treasury), 5 ether, true);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    // No approval granted: the actual owner Safe deliberately calls the accounting intake.
    vm.prank(address(treasury));
    wrapper.depositNFTs(bob, _ids);
    assertEq(wrapper.balanceOf(bob), 5 ether);
    assertEq(escrow.ownerOf(_id), address(treasury));
    assertEq(escrow.getApproved(_id), address(0));
    vm.expectRevert(abi.encodeWithSelector(HaiAero.AlreadyDeposited.selector, _id));
    vm.prank(address(treasury));
    wrapper.depositNFTs(bob, _ids);
  }

  function test_OtherCallerCannotRecognizeTreasuryNFT() public {
    wrapper.unpause();
    uint256 _id = escrow.mintStake(address(treasury), 5 ether, true);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    vm.expectRevert(HaiAero.NotNFTOwner.selector);
    vm.prank(alice);
    wrapper.depositNFTs(alice, _ids);
    assertEq(wrapper.totalSupply(), 0);
  }

  function test_TreasuryCanMoveBackingWithoutDoubleIssuanceOrStaleCustodyClaim() public {
    wrapper.unpause();
    uint256 _id = _depositNFT(5 ether);
    vm.prank(address(treasury));
    escrow.transferFrom(address(treasury), alice, _id);
    assertEq(wrapper.backingOf(_id), 0);
    (uint256 _recorded, uint256 _live, bool _inTreasury) = wrapper.backingStatus(_id);
    assertEq(_recorded, 5 ether);
    assertEq(_live, 0);
    assertFalse(_inTreasury);
    assertEq(wrapper.totalIssuedPrincipal(), 5 ether);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    vm.prank(alice);
    escrow.approve(address(wrapper), _id);
    vm.expectRevert(abi.encodeWithSelector(HaiAero.AlreadyDeposited.selector, _id));
    vm.prank(alice);
    wrapper.depositNFTs(alice, _ids);
    assertEq(wrapper.totalSupply(), 5 ether);
  }

  function test_TreasuryRejectingNewStakeRollsBackTokensAndIssuance() public {
    wrapper.unpause();
    treasury.setRejectNFTs(true);
    vm.expectRevert();
    vm.prank(alice);
    wrapper.deposit(alice, 1 ether);
    assertEq(wrapper.totalSupply(), 0);
    assertEq(aero.balanceOf(alice), 1000 ether);
    assertEq(escrow.nextId(), 0);
  }

  function test_TreasuryForwardingDuringReceiptCannotMintAgainstAbsentCustody() public {
    wrapper.unpause();
    treasury.setForwardRecipient(bob);
    uint256 _id = escrow.mintStake(alice, 5 ether, true);
    vm.prank(alice);
    escrow.approve(address(wrapper), _id);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _id;
    vm.expectRevert(abi.encodeWithSelector(HaiAero.UnsupportedStake.selector, _id));
    vm.prank(alice);
    wrapper.depositNFTs(alice, _ids);
    assertEq(escrow.ownerOf(_id), alice);
    assertEq(wrapper.totalSupply(), 0);
  }

  /// @dev Deliberately demonstrates the existing trusted-custody limitation; not a global solvency guarantee.
  function test_TrustedTreasuryReplacementIdsRequireExternalIssuanceReconciliation() public {
    wrapper.unpause();
    uint256 _oldId = _depositNFT(5 ether);
    vm.prank(address(treasury));
    uint256 _replacementId = escrow.replaceStake(_oldId);
    uint256[] memory _ids = new uint256[](1);
    _ids[0] = _replacementId;
    vm.prank(address(treasury));
    wrapper.depositNFTs(address(treasury), _ids);
    assertEq(wrapper.totalSupply(), 10 ether);
    assertEq(wrapper.backingOf(_oldId), 0);
    assertEq(wrapper.backingOf(_replacementId), 5 ether);
    // Operational policy MUST forbid this intake: 10 receipts would now depend on only 5 unique principal.
  }
}

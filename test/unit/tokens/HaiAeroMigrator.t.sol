// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {HaiAeroMigrator} from '@contracts/tokens/HaiAeroMigrator.sol';
import {AeroMigrationTokenMock} from '@test/mocks/AeroMigrationMocks.sol';

contract Unit_HaiAeroMigrator is Test {
  address internal constant V1 = 0x70f3713512089736661F928B291d1443C8b1BB6A;
  address internal constant V2 = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;
  address internal constant AERO_OP = 0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152;
  address internal constant AERO_BASE = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant BRIDGE = 0xD605046D24CdaD37Ca2Dff3aa8Ebf254CeEe86d5;
  address internal constant DEAD = address(0xdead);
  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');
  HaiAeroMigrator internal migrator;
  AeroMigrationTokenMock internal output;
  AeroMigrationTokenMock internal v1;
  AeroMigrationTokenMock internal v2;
  AeroMigrationTokenMock internal aero;

  function setUp() public {
    vm.chainId(10);
    AeroMigrationTokenMock _template = new AeroMigrationTokenMock();
    vm.etch(V1, address(_template).code);
    vm.etch(V2, address(_template).code);
    vm.etch(AERO_OP, address(_template).code);
    output = new AeroMigrationTokenMock();
    v1 = AeroMigrationTokenMock(V1);
    v2 = AeroMigrationTokenMock(V2);
    aero = AeroMigrationTokenMock(AERO_OP);
    v1.mint(alice, 100 ether);
    v2.mint(alice, 100 ether);
    aero.mint(alice, 50 ether);
    uint256[] memory _caps = new uint256[](3);
    _caps[0] = _caps[1] = _caps[2] = 1000 ether;
    migrator = new HaiAeroMigrator(address(output), address(this), 10, _caps, makeAddr('treasury'));
    vm.startPrank(alice);
    v1.approve(address(migrator), type(uint256).max);
    v2.approve(address(migrator), type(uint256).max);
    aero.approve(address(migrator), type(uint256).max);
    vm.stopPrank();
  }

  function _activate() internal {
    (, uint256 _required,,) = migrator.readiness();
    output.mint(address(migrator), _required);
    migrator.unpause();
  }

  function test_DefaultPausedAndQuotesHaveExactFixedRates() public {
    assertTrue(migrator.paused());
    assertEq(migrator.previewMigration(V1, 1000 ether), 44 ether);
    assertEq(migrator.previewMigration(V2, 1000 ether), 44 ether);
    assertEq(migrator.previewMigration(AERO_OP, 1 ether), 1 ether);
    vm.expectRevert(Pausable.EnforcedPause.selector);
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
  }

  function test_CannotActivateWithOnlyCallersInventory() public {
    output.mint(address(migrator), 0.044 ether);
    vm.expectRevert(abi.encodeWithSelector(HaiAeroMigrator.InsufficientBacking.selector, 0.044 ether, 58.8 ether));
    migrator.unpause();
  }

  function test_SurrenderTokensAndPayDistinctRecipient() public {
    _activate();
    vm.prank(alice);
    uint256 _received = migrator.migrate(V1, 10 ether, 0.44 ether, bob);
    assertEq(_received, 0.44 ether);
    assertEq(output.balanceOf(bob), _received);
    assertEq(v1.balanceOf(address(migrator)), 10 ether);
    assertEq(v1.totalSupply(), 100 ether);
    assertEq(migrator.outstanding(V1), 90 ether);
    (uint256 _inventory, uint256 _required, bool _caps, bool _ready) = migrator.readiness();
    assertEq(_inventory, _required);
    assertTrue(_caps && _ready);
  }

  function test_LateMintStopsAllRoutesUntilFullyFunded() public {
    _activate();
    v1.mint(bob, 1 ether);
    (,,, bool _ready) = migrator.readiness();
    assertFalse(_ready);
    vm.expectRevert(abi.encodeWithSelector(HaiAeroMigrator.InsufficientBacking.selector, 58.8 ether, 58.844 ether));
    vm.prank(alice);
    migrator.migrate(AERO_OP, 1 ether, 1 ether, alice);
    output.mint(address(migrator), 0.044 ether);
    vm.prank(alice);
    migrator.migrate(AERO_OP, 1 ether, 1 ether, alice);
    assertEq(output.balanceOf(alice), 1 ether);
  }

  function test_V1ToV2DeadAddressConversionDoesNotDoubleCount() public {
    _activate();
    (, uint256 _before,,) = migrator.readiness();
    vm.prank(alice);
    v1.transfer(DEAD, 40 ether);
    v2.mint(alice, 40 ether);
    (, uint256 _after,, bool _ready) = migrator.readiness();
    assertEq(_before, _after);
    assertTrue(_ready);
    vm.prank(alice);
    migrator.migrate(V2, 140 ether, 6.16 ether, bob);
    assertEq(output.balanceOf(bob), 6.16 ether);
  }

  function test_SourceCapsMustCoverAllClaimsAndOnlyIncreaseWhenPaused() public {
    v1.mint(bob, 1000 ether);
    (, uint256 _required,,) = migrator.readiness();
    output.mint(address(migrator), _required);
    vm.expectRevert(HaiAeroMigrator.CapsDoNotCoverLiabilities.selector);
    migrator.unpause();
    migrator.increaseCap(V1, 1100 ether);
    migrator.unpause();
    vm.expectRevert(Pausable.ExpectedPause.selector);
    migrator.increaseCap(V1, 1200 ether);
    migrator.pause();
    vm.expectRevert(HaiAeroMigrator.CapCannotDecrease.selector);
    migrator.increaseCap(V1, 1000 ether);
  }

  function test_SlippageAndInvalidRecipientsDoNotSurrender() public {
    _activate();
    vm.startPrank(alice);
    vm.expectRevert(HaiAeroMigrator.Slippage.selector);
    migrator.migrate(V1, 1 ether, 0.044 ether + 1, alice);
    vm.expectRevert(HaiAeroMigrator.InvalidRecipient.selector);
    migrator.migrate(V1, 1 ether, 0, address(migrator));
    vm.expectRevert(HaiAeroMigrator.InvalidRecipient.selector);
    migrator.migrate(V1, 1 ether, 0, address(0));
    vm.expectRevert(HaiAeroMigrator.InvalidAmount.selector);
    migrator.migrate(V1, 1, 0, alice);
    assertEq(v1.balanceOf(address(migrator)), 0);
  }

  function test_FeeOnInputOrOutputRevertsAtomically() public {
    _activate();
    v1.setFee(true);
    vm.expectRevert(HaiAeroMigrator.InexactTransfer.selector);
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    v1.setFee(false);
    output.setFee(true);
    vm.expectRevert(HaiAeroMigrator.InexactTransfer.selector);
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    assertEq(v1.balanceOf(address(migrator)), 0);
    assertEq(output.balanceOf(alice), 0);
  }

  function test_ReentrancyRevertsAtomically() public {
    _activate();
    v1.setCallback(address(migrator), abi.encodeCall(migrator.migrate, (V1, 1 ether, 0, alice)));
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    assertEq(v1.balanceOf(address(migrator)), 0);
  }

  function test_NewLiabilityDuringTransferRevertsViaPostCheck() public {
    _activate();
    v1.setCallback(AERO_OP, abi.encodeCall(aero.mint, (bob, 1 ether)));
    vm.expectRevert(abi.encodeWithSelector(HaiAeroMigrator.InsufficientBacking.selector, 58.756 ether, 59.756 ether));
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    assertEq(aero.balanceOf(bob), 0);
    assertEq(output.balanceOf(alice), 0);
  }

  function test_WrongChainFailsClosed() public {
    _activate();
    vm.chainId(8453);
    vm.expectRevert(HaiAeroMigrator.WrongChain.selector);
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    (,,, bool _ready) = migrator.readiness();
    assertFalse(_ready);
  }

  function test_BaseExcludesOnlyKnownBridgeAndRedemptionCreatesNewLocalLiability() public {
    vm.chainId(8453);
    AeroMigrationTokenMock _template = new AeroMigrationTokenMock();
    vm.etch(AERO_BASE, address(_template).code);
    vm.etch(BRIDGE, hex'00');
    AeroMigrationTokenMock _base = AeroMigrationTokenMock(AERO_BASE);
    _base.mint(alice, 10 ether);
    _base.mint(BRIDGE, 90 ether);
    uint256[] memory _caps = new uint256[](1);
    _caps[0] = 100 ether;
    HaiAeroMigrator _baseMigrator =
      new HaiAeroMigrator(address(output), address(this), 8453, _caps, makeAddr('treasury'));
    assertEq(_baseMigrator.outstanding(AERO_BASE), 10 ether);
    output.mint(address(_baseMigrator), 10 ether);
    _baseMigrator.unpause();
    vm.prank(BRIDGE);
    _base.transfer(bob, 1 ether);
    (, uint256 _required,, bool _ready) = _baseMigrator.readiness();
    assertEq(_required, 11 ether);
    assertFalse(_ready);
  }

  function testFuzz_RoundingNeverConsumesRemainingBacking(uint96 _amount) public {
    _amount = uint96(bound(_amount, 23, 100 ether));
    _activate();
    uint256 _quote = migrator.previewMigration(V1, _amount);
    vm.prank(alice);
    migrator.migrate(V1, _amount, _quote, bob);
    (uint256 _inventory, uint256 _required,, bool _ready) = migrator.readiness();
    assertGe(_inventory, _required);
    assertTrue(_ready);
  }

  function test_NoOwnerRecoveryOfSurrenderedClaimsOrInventory() public {
    _activate();
    vm.prank(alice);
    migrator.migrate(V1, 1 ether, 0, alice);
    migrator.pause();
    (bool _ok,) = address(migrator).call(abi.encodeWithSignature('rescue(address,address,uint256)', V1, alice, 1 ether));
    assertFalse(_ok);
    (_ok,) = address(migrator).call(
      abi.encodeWithSignature('rescue(address,address,uint256)', address(output), alice, 1 ether)
    );
    assertFalse(_ok);
    assertEq(v1.balanceOf(address(migrator)), 1 ether);
  }

  function test_SurplusWithdrawalPreservesEveryOutstandingClaim() public {
    _activate();
    output.mint(address(migrator), 2 ether);
    vm.expectRevert(Pausable.ExpectedPause.selector);
    migrator.withdrawSurplus(2 ether);
    migrator.pause();
    vm.expectRevert(HaiAeroMigrator.InsufficientSurplus.selector);
    migrator.withdrawSurplus(2 ether + 1);
    migrator.withdrawSurplus(2 ether);
    assertEq(output.balanceOf(migrator.treasury()), 2 ether);
    assertEq(output.balanceOf(address(this)), 0);
    (uint256 _inventory, uint256 _required,,) = migrator.readiness();
    assertEq(_inventory, _required);
    migrator.unpause();
  }

  function test_LegacyBridgeOutflowReleasesOnlyCorrespondingSurplus() public {
    _activate();
    // The synthetic is burned by the old bridge; Base release separately increases Base's liability.
    aero.burn(alice, 10 ether);
    migrator.pause();
    migrator.withdrawSurplus(10 ether);
    assertEq(output.balanceOf(migrator.treasury()), 10 ether);
    migrator.unpause();
    // A later incoming message mints synthetic claims. Migration safely waits for replenishment.
    aero.mint(bob, 3 ether);
    (uint256 _inventory, uint256 _required,, bool _ready) = migrator.readiness();
    assertFalse(_ready);
    assertEq(_required - _inventory, 3 ether);
  }

  function test_SurplusWithdrawalRechecksLiabilitiesAfterHostileCallback() public {
    _activate();
    output.mint(address(migrator), 2 ether);
    migrator.pause();
    output.setCallback(AERO_OP, abi.encodeCall(aero.mint, (bob, 1 ether)));
    vm.expectRevert(abi.encodeWithSelector(HaiAeroMigrator.InsufficientBacking.selector, 58.8 ether, 59.8 ether));
    migrator.withdrawSurplus(2 ether);
    assertEq(aero.balanceOf(bob), 0);
    assertEq(output.balanceOf(migrator.treasury()), 0);
    assertEq(output.balanceOf(address(migrator)), 60.8 ether);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Base} from '@test/unit/tokens/WrappedTokenV3.t.sol';
import {WrappedTokenV3, IWrappedTokenV3} from '@contracts/tokens/WrappedTokenV3.sol';
import {HaiAeroMailboxMock} from '@test/mocks/HaiAeroHyperlaneMocks.sol';
import {Mailbox} from '@hyperlane-xyz/core/contracts/Mailbox.sol';
import {TestPostDispatchHook} from '@hyperlane-xyz/core/contracts/test/TestPostDispatchHook.sol';
import {StaticMessageIdMultisigIsmFactory} from '@hyperlane-xyz/core/contracts/isms/multisig/StaticMultisigIsm.sol';

/// @dev Regression tests for the treasury and bridge recipient findings in the PR #161 audit.
contract Audit_WrappedTokenV3_Configuration is Base {
  function test_Revert_ManagerIsWrapper() public {
    _assertRejectedManager(true);
  }

  function test_Revert_ManagerIsDead() public {
    _assertRejectedManager(false);
  }

  function test_Revert_ConstructorInvalidTreasury() public {
    _assertRejectedConstructorTreasury(8453);
    _assertRejectedConstructorTreasury(10);
  }

  function _assertRejectedConstructorTreasury(uint256 chainId) internal {
    vm.chainId(chainId);
    IWrappedTokenV3.DeploymentConfig memory config = _config(chainId);
    config.treasury = address(0);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(config);
    config.treasury = DEAD;
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(config);
    config.treasury = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(config);
  }

  function _assertRejectedManager(bool self) internal {
    _assertRejectedManagerOnChain(8453, self);
    _assertRejectedManagerOnChain(10, self);
  }

  function _assertRejectedManagerOnChain(uint256 chainId, bool self) internal {
    _activate(chainId);
    WrappedTokenV3 wrapper = chainId == 8453 ? baseWrapper : opWrapper;
    address manager = wrapper.baseTokenManager();
    uint256 treasuryBalance = wrapper.BASE_TOKEN().balanceOf(manager);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    wrapper.modifyParameters('baseTokenManager', abi.encode(self ? address(wrapper) : DEAD));
    assertEq(wrapper.baseTokenManager(), manager);
    assertEq(wrapper.BASE_TOKEN().balanceOf(manager), treasuryBalance);
    assertEq(wrapper.totalSupply(), 0);
    vm.prank(alice);
    wrapper.deposit(alice, 10 ether);
    assertEq(wrapper.BASE_TOKEN().balanceOf(manager), treasuryBalance + 10 ether);
    assertEq(wrapper.BASE_TOKEN().balanceOf(address(wrapper)), 0);
    assertEq(wrapper.BASE_TOKEN().balanceOf(DEAD), 0);
    assertEq(wrapper.balanceOf(alice), 10 ether);
  }
}

/// @dev Uses the actual pinned Hyperlane Mailbox and a two-validator MessageId multisig ISM.
///      Hooks are zero-cost test hooks and signatures use local test keys; no production relayer is tested.
contract Audit_WrappedTokenV3_Mailbox is Base {
  uint256 internal constant VALIDATOR_ONE = 0x123456;
  uint256 internal constant VALIDATOR_TWO = 0x654321;

  function setUp() public override {
    super.setUp();
    address[] memory validators = new address[](2);
    validators[0] = vm.addr(VALIDATOR_ONE);
    validators[1] = vm.addr(VALIDATOR_TWO);
    address ism = new StaticMessageIdMultisigIsmFactory().deploy(validators, 2);
    TestPostDispatchHook hook = new TestPostDispatchHook();
    Mailbox baseTransport = new Mailbox(8453);
    Mailbox opTransport = new Mailbox(10);
    baseTransport.initialize(address(this), ism, address(hook), address(hook));
    opTransport.initialize(address(this), ism, address(hook), address(hook));
    baseMailbox = HaiAeroMailboxMock(address(baseTransport));
    opMailbox = HaiAeroMailboxMock(address(opTransport));
    vm.chainId(8453);
    baseWrapper = new WrappedTokenV3(_config(8453));
    vm.chainId(10);
    opWrapper = new WrappedTokenV3(_config(10));
    vm.startPrank(bridgeOwner);
    baseWrapper.enrollRemoteRouter(10, _address32(address(opWrapper)));
    opWrapper.enrollRemoteRouter(8453, _address32(address(baseWrapper)));
    vm.stopPrank();
    _activate(8453);
    vm.startPrank(alice);
    baseAero.approve(address(baseWrapper), type(uint256).max);
    baseWrapper.deposit(alice, 100 ether);
    vm.stopPrank();
  }

  function _message(
    bool fromBase,
    address sender,
    address recipient,
    uint256 amount,
    uint32 nonce
  ) internal view returns (bytes memory) {
    return abi.encodePacked(
      uint8(3),
      nonce,
      uint32(fromBase ? 8453 : 10),
      _address32(sender),
      uint32(fromBase ? 10 : 8453),
      _address32(address(fromBase ? opWrapper : baseWrapper)),
      _address32(recipient),
      amount
    );
  }

  function _dispatch(bool fromBase, address recipient, uint256 amount) internal returns (bytes memory message) {
    vm.chainId(fromBase ? 8453 : 10);
    WrappedTokenV3 source = fromBase ? baseWrapper : opWrapper;
    Mailbox transport = Mailbox(address(fromBase ? baseMailbox : opMailbox));
    message = _message(fromBase, address(source), recipient, amount, transport.nonce());
    vm.prank(alice);
    assertEq(source.transferRemote(fromBase ? 10 : 8453, _address32(recipient), amount), keccak256(message));
  }

  function _metadata(bytes memory message, uint32 origin, uint256 secondKey) internal returns (bytes memory) {
    bytes32 tree = bytes32(uint256(0x1234));
    bytes32 root = keccak256('audit checkpoint');
    uint32 index = 0;
    bytes32 domain = keccak256(abi.encodePacked(origin, tree, 'HYPERLANE'));
    bytes32 checkpoint = keccak256(abi.encodePacked(domain, root, index, keccak256(message)));
    bytes32 digest = keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', checkpoint));
    (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(VALIDATOR_ONE, digest);
    (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(secondKey, digest);
    return abi.encodePacked(tree, root, index, r1, s1, v1, r2, s2, v2);
  }

  function test_RealMailboxRoundTripAndReplayProtection() public {
    bytes memory outbound = _dispatch(true, alice, 20 ether);
    bytes memory metadata = _metadata(outbound, 8453, VALIDATOR_TWO);
    vm.chainId(10);
    Mailbox transport = Mailbox(address(opMailbox));
    transport.process(metadata, outbound);
    assertEq(opWrapper.balanceOf(alice), 20 ether);
    assertTrue(opWrapper.paused()); // Pausing local issuance intentionally leaves bridging enabled.
    vm.expectRevert('Mailbox: already delivered');
    transport.process(metadata, outbound);
    assertEq(opWrapper.balanceOf(alice), 20 ether);

    bytes memory inbound = _dispatch(false, alice, 20 ether);
    metadata = _metadata(inbound, 10, VALIDATOR_TWO);
    vm.chainId(8453);
    Mailbox(address(baseMailbox)).process(metadata, inbound);
    assertEq(baseWrapper.balanceOf(alice), 100 ether);
    assertEq(opWrapper.totalSupply(), 0);
  }

  function test_RealMailboxRejectsInvalidValidatorAndAlteredAmount() public {
    bytes memory message = _dispatch(true, alice, 20 ether);
    bytes memory badMetadata = _metadata(message, 8453, 0xbad);
    bytes memory goodMetadata = _metadata(message, 8453, VALIDATOR_TWO);
    vm.chainId(10);
    Mailbox transport = Mailbox(address(opMailbox));
    vm.expectRevert('!threshold');
    transport.process(badMetadata, message);
    assertFalse(transport.delivered(keccak256(message)));
    bytes memory altered = _message(true, address(baseWrapper), alice, 200 ether, 0);
    vm.expectRevert('!threshold');
    transport.process(goodMetadata, altered);
    assertEq(opWrapper.totalSupply(), 0);
    transport.process(goodMetadata, message);
    assertEq(opWrapper.totalSupply(), 20 ether);
  }

  function test_RealMailboxRejectsSignedWrongRouter() public {
    bytes memory message = _message(true, alice, alice, 100 ether, 0);
    bytes memory metadata = _metadata(message, 8453, VALIDATOR_TWO);
    vm.chainId(10);
    vm.expectRevert('Enrolled router does not match sender');
    Mailbox(address(opMailbox)).process(metadata, message);
    assertEq(opWrapper.totalSupply(), 0);
  }

  function test_Revert_BridgeToZero() public {
    _assertRejectedBridgeRecipient(bytes32(0), bytes32(0));
  }

  function test_Revert_BridgeToDead() public {
    _assertRejectedBridgeRecipient(_address32(DEAD), _address32(DEAD));
  }

  function test_Revert_BridgeToDestinationWrapper() public {
    assertNotEq(address(baseWrapper), address(opWrapper));
    _assertRejectedBridgeRecipient(_address32(address(baseWrapper)), _address32(address(opWrapper)));
  }

  function test_Revert_NoncanonicalBridgeRecipient(uint96 highBits) public {
    vm.assume(highBits != 0);
    bytes32 recipient = bytes32((uint256(highBits) << 160) | uint256(uint160(alice)));
    _assertRejectedBridgeRecipient(recipient, recipient);
  }

  function _assertRejectedBridgeRecipient(bytes32 baseRecipient, bytes32 opRecipient) internal {
    _activate(10);
    vm.startPrank(alice);
    opAero.approve(address(opWrapper), 20 ether);
    opWrapper.deposit(alice, 20 ether);
    vm.stopPrank();
    opWrapper.pause();

    _assertRejectedBridgeOnChain(true, opRecipient);
    _assertRejectedBridgeOnChain(false, baseRecipient);
    assertEq(baseWrapper.totalSupply(), 100 ether);
    assertEq(opWrapper.totalSupply(), 20 ether);
  }

  function _assertRejectedBridgeOnChain(bool fromBase, bytes32 recipient) internal {
    vm.chainId(fromBase ? 8453 : 10);
    WrappedTokenV3 source = fromBase ? baseWrapper : opWrapper;
    Mailbox transport = Mailbox(address(fromBase ? baseMailbox : opMailbox));
    uint256 balanceBefore = source.balanceOf(alice);
    uint256 supplyBefore = source.totalSupply();
    uint32 nonceBefore = transport.nonce();
    bytes32 latestBefore = transport.latestDispatchedId();
    vm.deal(alice, 1 ether);
    vm.prank(alice);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidRecipient.selector);
    source.transferRemote{value: 0.01 ether}(fromBase ? 10 : 8453, recipient, 10 ether);
    assertEq(source.balanceOf(alice), balanceBefore);
    assertEq(source.totalSupply(), supplyBefore);
    assertEq(transport.nonce(), nonceBefore);
    assertEq(transport.latestDispatchedId(), latestBefore);
    assertEq(alice.balance, 1 ether);
  }

  function test_RejectsCurrentDestinationRouterAfterRotation() public {
    address replacement = makeAddr('replacement destination router');
    vm.prank(bridgeOwner);
    baseWrapper.enrollRemoteRouter(10, _address32(replacement));
    _assertRejectedBridgeRecipient(_address32(address(baseWrapper)), _address32(replacement));

    // Restore the counterpart and prove legitimate transfers still work after the rejected attempts.
    vm.prank(bridgeOwner);
    baseWrapper.enrollRemoteRouter(10, _address32(address(opWrapper)));
    bytes memory message = _dispatch(true, alice, 10 ether);
    bytes memory metadata = _metadata(message, 8453, VALIDATOR_TWO);
    vm.chainId(10);
    Mailbox(address(opMailbox)).process(metadata, message);
    assertEq(opWrapper.balanceOf(alice), 30 ether);
    assertEq(baseWrapper.balanceOf(alice), 90 ether);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {WrappedTokenV3, IWrappedTokenV3} from '@contracts/tokens/WrappedTokenV3.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';

import {HaiTest} from '@test/utils/HaiTest.t.sol';

import {AeroMigrationTokenMock, AeroRootVoterMock, AeroTreasuryMock} from '@test/mocks/AeroMigrationMocks.sol';
import {HaiAeroMailboxMock} from '@test/mocks/HaiAeroHyperlaneMocks.sol';
import {
  WrappedTokenV3EscrowMock,
  WrappedTokenV3SixDecimalsMock,
  WrappedTokenV3TreasuryRotationMock
} from '@test/mocks/WrappedTokenV3Mocks.sol';

/// @dev Local mock transport tests. They do not prove production validator, relayer or ISM delivery.
abstract contract Base is HaiTest {
  address internal constant VELO_V1 = 0x70f3713512089736661F928B291d1443C8b1BB6A;
  address internal constant VELO_V2 = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;
  address internal constant OLD_AERO = 0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152;
  address internal constant DEAD = address(0xdead);
  uint256 internal constant ALICE_KEY = 0xa11ce;
  bytes32 internal constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  address internal alice;
  address internal bob = makeAddr('recipient');
  address internal bridgeOwner = makeAddr('bridge owner');
  WrappedTokenV3 internal baseWrapper;
  WrappedTokenV3 internal opWrapper;
  AeroMigrationTokenMock internal baseAero;
  AeroMigrationTokenMock internal opAero;
  AeroMigrationTokenMock internal veloV1;
  AeroMigrationTokenMock internal veloV2;
  AeroMigrationTokenMock internal oldAero;
  WrappedTokenV3EscrowMock internal escrow;
  AeroTreasuryMock internal baseTreasury;
  AeroTreasuryMock internal opTreasury;
  HaiAeroMailboxMock internal baseMailbox;
  HaiAeroMailboxMock internal opMailbox;

  function setUp() public virtual {
    alice = vm.addr(ALICE_KEY);
    baseAero = new AeroMigrationTokenMock();
    opAero = new AeroMigrationTokenMock();
    escrow = new WrappedTokenV3EscrowMock(address(baseAero), address(new AeroRootVoterMock()));
    baseTreasury = new AeroTreasuryMock();
    opTreasury = new AeroTreasuryMock();
    baseMailbox = new HaiAeroMailboxMock(8453);
    opMailbox = new HaiAeroMailboxMock(10);
    AeroMigrationTokenMock _template = new AeroMigrationTokenMock();
    vm.etch(VELO_V1, address(_template).code);
    vm.etch(VELO_V2, address(_template).code);
    vm.etch(OLD_AERO, address(_template).code);
    veloV1 = AeroMigrationTokenMock(VELO_V1);
    veloV2 = AeroMigrationTokenMock(VELO_V2);
    oldAero = AeroMigrationTokenMock(OLD_AERO);
    vm.chainId(8453);
    baseWrapper = new WrappedTokenV3(_config(8453));
    vm.chainId(10);
    opWrapper = new WrappedTokenV3(_config(10));
    vm.prank(bridgeOwner);
    opWrapper.enrollRemoteRouter(8453, _address32(address(baseWrapper)));
    vm.chainId(8453);
    vm.prank(bridgeOwner);
    baseWrapper.enrollRemoteRouter(10, _address32(address(opWrapper)));
    baseAero.mint(alice, 1000 ether);
    opAero.mint(alice, 1000 ether);
    veloV1.mint(alice, 1000 ether);
    veloV2.mint(alice, 1000 ether);
    oldAero.mint(alice, 1000 ether);
    vm.startPrank(alice);
    baseAero.approve(address(baseWrapper), type(uint256).max);
    opAero.approve(address(opWrapper), type(uint256).max);
    veloV1.approve(address(opWrapper), type(uint256).max);
    veloV2.approve(address(opWrapper), type(uint256).max);
    oldAero.approve(address(opWrapper), type(uint256).max);
    vm.stopPrank();
  }

  function _config(uint256 _chainId) internal view returns (IWrappedTokenV3.DeploymentConfig memory _value) {
    bool _base = _chainId == 8453;
    _value = IWrappedTokenV3.DeploymentConfig({
      baseToken: _base ? address(baseAero) : address(opAero),
      baseTokenNFT: _base ? address(escrow) : address(0),
      treasury: _base ? address(baseTreasury) : address(opTreasury),
      chainId: _chainId,
      mailbox: _base ? address(baseMailbox) : address(opMailbox),
      hook: address(0),
      interchainSecurityModule: address(0),
      bridgeOwner: bridgeOwner
    });
  }

  function _activate(uint256 _chainId) internal {
    vm.chainId(_chainId);
    (_chainId == 8453 ? baseWrapper : opWrapper).unpause();
  }

  function _address32(address _value) internal pure returns (bytes32 _converted) {
    return bytes32(uint256(uint160(_value)));
  }

  function _oneId(uint256 _id) internal pure returns (uint256[] memory _ids) {
    _ids = new uint256[](1);
    _ids[0] = _id;
  }

  function _mintNFT(address _holder, uint128 _amount, bool _permanent) internal returns (uint256 _id) {
    _id = escrow.mintStake(_holder, _amount, _permanent);
    vm.prank(_holder);
    escrow.approve(address(baseWrapper), _id);
  }

  function _assertCombinedSupply(uint256 _issued, uint256 _pending) internal view {
    assertEq(baseWrapper.totalSupply() + opWrapper.totalSupply() + _pending, _issued);
  }

  function _permitDigest(
    WrappedTokenV3 _token,
    uint256 _value,
    uint256 _nonce,
    uint256 _deadline
  ) internal view returns (bytes32 _digest) {
    bytes32 _domainSeparator = keccak256(
      abi.encode(
        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        keccak256(bytes(_token.name())),
        keccak256('1'),
        block.chainid,
        address(_token)
      )
    );

    return keccak256(
      abi.encodePacked(
        '\x19\x01', _domainSeparator, keccak256(abi.encode(PERMIT_TYPEHASH, alice, bob, _value, _nonce, _deadline))
      )
    );
  }
}

contract Unit_WrappedTokenV3_Constructor is Base {
  function test_Set_InitialState() public view {
    assertEq(baseWrapper.name(), 'haiAEROV2');
    assertEq(opWrapper.name(), 'haiAEROV2');
    assertEq(baseWrapper.symbol(), 'haiAERO');
    assertEq(opWrapper.symbol(), 'haiAERO');
    assertEq(baseWrapper.decimals(), 18);
    assertEq(opWrapper.decimals(), 18);
    assertEq(baseWrapper.token(), address(baseWrapper));
    assertEq(opWrapper.token(), address(opWrapper));
    assertEq(baseWrapper.scaleNumerator(), 1);
    assertEq(opWrapper.scaleDenominator(), 1);
    assertEq(baseWrapper.owner(), bridgeOwner);
    assertEq(opWrapper.owner(), bridgeOwner);
    assertTrue(baseWrapper.authorizedAccounts(address(this)));
    assertTrue(opWrapper.authorizedAccounts(address(this)));
    assertEq(baseWrapper.authorizedAccounts().length, 1);
    assertEq(opWrapper.authorizedAccounts().length, 1);
    assertFalse(baseWrapper.authorizedAccounts(address(baseTreasury)));
    assertFalse(opWrapper.authorizedAccounts(address(opTreasury)));
    assertFalse(baseWrapper.authorizedAccounts(bridgeOwner));
    assertFalse(opWrapper.authorizedAccounts(bridgeOwner));
    assertEq(baseWrapper.baseTokenManager(), address(baseTreasury));
    assertEq(opWrapper.baseTokenManager(), address(opTreasury));
    assertEq(address(baseWrapper.BASE_TOKEN()), address(baseAero));
    assertEq(address(baseWrapper.BASE_TOKEN_NFT()), address(escrow));
    assertEq(address(opWrapper.BASE_TOKEN_NFT()), address(0));
    assertEq(baseWrapper.deploymentChainId(), 8453);
    assertEq(opWrapper.deploymentChainId(), 10);
    assertTrue(baseWrapper.paused());
    assertTrue(opWrapper.paused());
    _assertCombinedSupply(0, 0);
  }

  function test_Revert_Reinitialization() public {
    vm.expectRevert('Initializable: contract is already initialized');
    baseWrapper.initialize(1 ether, 'Forged', 'FORGED', address(0), address(0), alice);
    vm.chainId(10);
    vm.expectRevert('Initializable: contract is already initialized');
    opWrapper.initialize(1 ether, 'Forged', 'FORGED', address(0), address(0), alice);
    _assertCombinedSupply(0, 0);
  }

  function test_Deploy_WithinEIP170Limit() public view {
    assertLe(address(baseWrapper).code.length, 24_576);
    assertLe(address(opWrapper).code.length, 24_576);
  }

  function test_Revert_UnsupportedChainOrMismatchedMailboxDomain() public {
    IWrappedTokenV3.DeploymentConfig memory _value = _config(8453);
    _value.chainId = 1;
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value = _config(10);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value = _config(8453);
    _value.mailbox = address(opMailbox);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
  }

  function test_Revert_InvalidBaseTokenOrNullTreasury() public {
    IWrappedTokenV3.DeploymentConfig memory _value = _config(8453);
    _value.baseToken = alice;
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value.baseToken = address(new WrappedTokenV3SixDecimalsMock());
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value = _config(8453);
    _value.treasury = address(0);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value = _config(8453);
    _value.bridgeOwner = address(0);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
  }

  function test_Set_EOATreasuryWithTokenAndNFTCustody() public {
    address _treasury = makeAddr('treasury EOA');
    uint256[2] memory _chains = [uint256(8453), uint256(10)];
    assertEq(_treasury.code.length, 0);

    for (uint256 _i; _i < _chains.length; ++_i) {
      vm.chainId(_chains[_i]);
      IWrappedTokenV3.DeploymentConfig memory _value = _config(_chains[_i]);
      _value.treasury = _treasury;
      WrappedTokenV3 _wrapper = new WrappedTokenV3(_value);
      AeroMigrationTokenMock _underlying = _chains[_i] == 8453 ? baseAero : opAero;
      assertEq(_wrapper.baseTokenManager(), _treasury);
      _wrapper.unpause();

      vm.startPrank(alice);
      _underlying.approve(address(_wrapper), 20 ether);
      _wrapper.deposit(bob, 20 ether);
      vm.stopPrank();

      assertEq(_underlying.balanceOf(_treasury), 20 ether);
      assertEq(_underlying.balanceOf(address(_wrapper)), 0);
      assertEq(_wrapper.balanceOf(bob), 20 ether);
      assertEq(_wrapper.totalSupply(), 20 ether);

      if (_chains[_i] == 8453) {
        uint256 _id = escrow.mintStake(alice, 7 ether, false);
        vm.startPrank(alice);
        escrow.approve(address(_wrapper), _id);
        _wrapper.depositNFTs(bob, _oneId(_id));
        vm.stopPrank();

        assertEq(escrow.ownerOf(_id), _treasury);
        assertEq(escrow.staked(_id).amount, 7 ether);
        assertEq(_wrapper.balanceOf(bob), 27 ether);
        assertEq(_wrapper.totalSupply(), 27 ether);
      }
    }
  }

  function test_Revert_InvalidNFTConfiguration() public {
    IWrappedTokenV3.DeploymentConfig memory _value = _config(8453);
    _value.baseTokenNFT = address(0);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    _value.baseTokenNFT = address(new WrappedTokenV3EscrowMock(address(opAero), address(0)));
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
    vm.chainId(10);
    _value = _config(10);
    _value.baseTokenNFT = address(escrow);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
    new WrappedTokenV3(_value);
  }

  function test_Revert_LegacyTokenAsOptimismBacking() public {
    vm.chainId(10);
    IWrappedTokenV3.DeploymentConfig memory _value = _config(10);
    address[3] memory _legacy = [VELO_V1, VELO_V2, OLD_AERO];
    for (uint256 _i; _i < _legacy.length; ++_i) {
      _value.baseToken = _legacy[_i];
      vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidConfiguration.selector);
      new WrappedTokenV3(_value);
    }
  }
}

contract Unit_WrappedTokenV3_Deposit is Base {
  function test_Mint_BaseDeposit() public {
    _activate(8453);
    vm.prank(alice);
    baseWrapper.deposit(bob, 20 ether);
    assertEq(baseAero.balanceOf(address(baseTreasury)), 20 ether);
    assertEq(baseAero.balanceOf(address(baseWrapper)), 0);
    assertEq(baseAero.balanceOf(address(escrow)), 0);
    assertEq(escrow.nextId(), 0);
    assertEq(baseWrapper.balanceOf(bob), 20 ether);
    assertEq(baseWrapper.totalSupply(), 20 ether);
  }

  function test_Mint_OptimismDeposit() public {
    _activate(10);
    vm.prank(alice);
    opWrapper.deposit(bob, 20 ether);
    assertEq(opAero.balanceOf(address(opTreasury)), 20 ether);
    assertEq(opAero.balanceOf(address(opWrapper)), 0);
    assertEq(opWrapper.balanceOf(bob), 20 ether);
    assertEq(opWrapper.totalSupply(), 20 ether);
  }

  function test_Revert_InexactTransfer() public {
    _activate(8453);
    baseAero.setFee(true);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InexactTransfer.selector);
    vm.prank(alice);
    baseWrapper.deposit(bob, 20 ether);
    assertEq(baseAero.balanceOf(alice), 1000 ether);
    assertEq(baseAero.balanceOf(address(baseTreasury)), 0);
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_InvalidAmountRecipientOrAllowance() public {
    _activate(8453);
    vm.startPrank(alice);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidAmount.selector);
    baseWrapper.deposit(bob, 0);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidRecipient.selector);
    baseWrapper.deposit(address(0), 1 ether);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidRecipient.selector);
    baseWrapper.deposit(address(baseWrapper), 1 ether);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidRecipient.selector);
    baseWrapper.deposit(DEAD, 1 ether);
    baseAero.approve(address(baseWrapper), 0);
    vm.expectRevert();
    baseWrapper.deposit(bob, 1 ether);
    vm.stopPrank();
    assertEq(baseAero.balanceOf(address(baseTreasury)), 0);
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_Reentrancy() public {
    _activate(8453);
    baseAero.setCallback(address(baseWrapper), abi.encodeCall(baseWrapper.deposit, (bob, 1 ether)));
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    vm.prank(alice);
    baseWrapper.deposit(bob, 20 ether);
    assertEq(baseAero.balanceOf(alice), 1000 ether);
    assertEq(baseAero.balanceOf(address(baseTreasury)), 0);
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_TreasuryDeposit() public {
    _activate(8453);
    baseAero.mint(address(baseTreasury), 1 ether);
    vm.startPrank(address(baseTreasury));
    baseAero.approve(address(baseWrapper), 1 ether);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_TreasuryDeposit.selector);
    baseWrapper.deposit(bob, 1 ether);
    vm.stopPrank();
    assertEq(baseWrapper.totalSupply(), 0);
  }
}

contract Unit_WrappedTokenV3_DepositNFTs is Base {
  function test_Mint_PermanentNFTPrincipal() public {
    _activate(8453);
    uint256 _first = _mintNFT(alice, 7 ether, true);
    uint256 _second = _mintNFT(alice, 3 ether, true);
    uint256[] memory _ids = new uint256[](2);
    _ids[0] = _first;
    _ids[1] = _second;
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _ids);
    assertEq(baseWrapper.balanceOf(bob), 10 ether);
    assertEq(baseWrapper.totalSupply(), 10 ether);
    assertEq(escrow.ownerOf(_first), address(baseTreasury));
    assertEq(escrow.ownerOf(_second), address(baseTreasury));
    vm.prank(address(baseTreasury));
    escrow.transferFrom(address(baseTreasury), bob, _first);
    assertEq(escrow.ownerOf(_first), bob);
  }

  function test_Revert_NonadjacentDuplicateTokenIds() public {
    _activate(8453);
    uint256 _first = _mintNFT(alice, 7 ether, true);
    uint256 _second = _mintNFT(alice, 3 ether, false);
    uint256[] memory _ids = new uint256[](3);
    _ids[0] = _ids[2] = _first;
    _ids[1] = _second;
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_DuplicateTokenIds.selector);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _ids);
    assertEq(escrow.ownerOf(_first), alice);
    assertEq(escrow.ownerOf(_second), alice);
    assertEq(baseWrapper.balanceOf(bob), 0);
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Mint_ReturnedNFTCurrentPrincipal() public {
    _activate(8453);
    uint256 _id = _mintNFT(alice, 7 ether, true);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_id));
    assertEq(baseWrapper.balanceOf(bob), 7 ether);
    assertEq(escrow.ownerOf(_id), address(baseTreasury));

    vm.prank(address(baseTreasury));
    escrow.transferFrom(address(baseTreasury), alice, _id);
    escrow.setStake(_id, 9 ether, 0, true);
    vm.prank(alice);
    escrow.approve(address(baseWrapper), _id);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_id));

    assertEq(baseWrapper.balanceOf(bob), 16 ether);
    assertEq(baseWrapper.totalSupply(), 16 ether);
    assertEq(escrow.ownerOf(_id), address(baseTreasury));
    assertEq(escrow.staked(_id).amount, 9 ether);
  }

  function test_Revert_TreasuryDeposit() public {
    _activate(8453);
    uint256 _id = _mintNFT(address(baseTreasury), 7 ether, true);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_TreasuryDeposit.selector);
    vm.prank(address(baseTreasury));
    baseWrapper.depositNFTs(bob, _oneId(_id));
    assertEq(escrow.ownerOf(_id), address(baseTreasury));
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Mint_MixedTimedAndPermanentNFTPrincipal() public {
    _activate(8453);
    uint256 _timed = _mintNFT(alice, 7 ether, false);
    uint256 _permanent = _mintNFT(alice, 3 ether, true);
    uint48 _end = escrow.staked(_timed).end;
    uint256[] memory _ids = new uint256[](2);
    _ids[0] = _timed;
    _ids[1] = _permanent;

    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _ids);

    assertEq(baseWrapper.balanceOf(bob), 10 ether);
    assertEq(baseWrapper.totalSupply(), 10 ether);
    assertEq(escrow.ownerOf(_timed), address(baseTreasury));
    assertEq(escrow.ownerOf(_permanent), address(baseTreasury));
    assertEq(escrow.staked(_timed).amount, 7 ether);
    assertEq(escrow.staked(_timed).end, _end);
    assertFalse(escrow.staked(_timed).isPermanent);
    assertEq(escrow.staked(_permanent).amount, 3 ether);
    assertEq(escrow.staked(_permanent).end, 0);
    assertTrue(escrow.staked(_permanent).isPermanent);
  }

  function test_Mint_MaturedTimedNFTPrincipal() public {
    _activate(8453);
    uint256 _timed = _mintNFT(alice, 7 ether, false);
    uint48 _end = escrow.staked(_timed).end;
    vm.warp(uint256(_end) + 1);

    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_timed));

    assertEq(baseWrapper.balanceOf(bob), 7 ether);
    assertEq(baseWrapper.totalSupply(), 7 ether);
    assertEq(escrow.ownerOf(_timed), address(baseTreasury));
    assertEq(escrow.staked(_timed).amount, 7 ether);
    assertEq(escrow.staked(_timed).end, _end);
    assertFalse(escrow.staked(_timed).isPermanent);
  }

  function test_Revert_EmptyPositions() public {
    _activate(8453);
    uint256[2] memory _ids = [_mintNFT(alice, 0, false), _mintNFT(alice, 0, true)];

    for (uint256 _i; _i < _ids.length; ++_i) {
      vm.expectRevert(abi.encodeWithSelector(IWrappedTokenV3.WrappedTokenV3_UnsupportedStake.selector, _ids[_i]));
      vm.prank(alice);
      baseWrapper.depositNFTs(bob, _oneId(_ids[_i]));
      assertEq(escrow.ownerOf(_ids[_i]), alice);
    }

    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_InvalidOwnerOrEmptyBatch() public {
    _activate(8453);
    uint256 _id = _mintNFT(alice, 7 ether, true);
    vm.prank(bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_NotNFTOwner.selector);
    baseWrapper.depositNFTs(bob, _oneId(_id));
    vm.prank(alice);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidAmount.selector);
    baseWrapper.depositNFTs(bob, new uint256[](0));
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_TreasuryRejectsNFT() public {
    _activate(8453);
    uint256 _id = _mintNFT(alice, 7 ether, true);
    baseTreasury.setRejectNFTs(true);
    vm.expectRevert('reject NFT');
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_id));
    assertEq(escrow.ownerOf(_id), alice);
    assertEq(baseWrapper.totalSupply(), 0);
  }

  function test_Revert_TreasuryForwardsNFT() public {
    _activate(8453);
    uint256 _id = _mintNFT(alice, 7 ether, true);
    baseTreasury.setForwardRecipient(bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InexactTransfer.selector);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_id));
    assertEq(escrow.ownerOf(_id), alice);
    assertEq(baseWrapper.totalSupply(), 0);
  }
}

contract Unit_WrappedTokenV3_Migrate is Base {
  function test_Mint_AllLegacySourcesAtFixedRates() public {
    _activate(10);
    assertEq(opWrapper.previewMigration(VELO_V1, 1000 ether), 44 ether);
    assertEq(opWrapper.previewMigration(VELO_V2, 1000 ether), 44 ether);
    assertEq(opWrapper.previewMigration(OLD_AERO, 1000 ether), 1000 ether);
    vm.startPrank(alice);
    assertEq(opWrapper.migrate(VELO_V1, 100 ether, 4.4 ether, bob), 4.4 ether);
    assertEq(opWrapper.migrate(VELO_V2, 100 ether, 4.4 ether, bob), 4.4 ether);
    assertEq(opWrapper.migrate(OLD_AERO, 10 ether, 10 ether, bob), 10 ether);
    vm.stopPrank();
    assertEq(opWrapper.balanceOf(bob), 18.8 ether);
    assertEq(opWrapper.totalSupply(), 18.8 ether);
    assertEq(veloV1.balanceOf(DEAD), 100 ether);
    assertEq(veloV2.balanceOf(DEAD), 100 ether);
    assertEq(oldAero.balanceOf(DEAD), 10 ether);
    assertEq(veloV2.balanceOf(address(opWrapper)), 0);
    assertEq(opAero.balanceOf(address(opTreasury)), 0);
    assertEq(opWrapper.balanceOf(address(opWrapper)), 0);
  }

  function test_Mint_ConvertedVELOPrincipal(uint256 _amount) public {
    _amount = bound(_amount, 23, 1000 ether);
    _activate(10);
    vm.prank(alice);
    uint256 _output = opWrapper.migrate(VELO_V2, _amount, 0, bob);
    assertLe(_output * 1000, _amount * 44);
    assertGt((_output + 1) * 1000, _amount * 44);
    assertEq(veloV2.balanceOf(DEAD), _amount);
    assertEq(veloV2.balanceOf(alice), 1000 ether - _amount);
    assertEq(opWrapper.balanceOf(bob), _output);
    assertEq(opWrapper.totalSupply(), _output);
  }

  function test_Revert_InvalidMigrationBeforeRetirement() public {
    _activate(10);
    vm.startPrank(alice);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidAmount.selector);
    opWrapper.migrate(VELO_V2, 0, 0, bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidAmount.selector);
    opWrapper.migrate(VELO_V2, 1, 0, bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_UnsupportedSource.selector);
    opWrapper.migrate(address(opAero), 1 ether, 0, bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_Slippage.selector);
    opWrapper.migrate(VELO_V2, 1 ether, 0.044 ether + 1, bob);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InvalidRecipient.selector);
    opWrapper.migrate(OLD_AERO, 1 ether, 0, address(0));
    vm.stopPrank();
    assertEq(veloV2.balanceOf(alice), 1000 ether);
    assertEq(veloV2.balanceOf(DEAD), 0);
    assertEq(opWrapper.totalSupply(), 0);
  }

  function test_Revert_MissingAllowanceOrSpentLegacyBalance() public {
    _activate(10);
    vm.startPrank(alice);
    veloV2.approve(address(opWrapper), 0);
    vm.expectRevert();
    opWrapper.migrate(VELO_V2, 1 ether, 0, bob);
    veloV2.approve(address(opWrapper), type(uint256).max);
    opWrapper.migrate(VELO_V2, 1000 ether, 44 ether, bob);
    vm.expectRevert();
    opWrapper.migrate(VELO_V2, 1000 ether, 44 ether, bob);
    vm.stopPrank();
    assertEq(veloV2.balanceOf(DEAD), 1000 ether);
    assertEq(opWrapper.totalSupply(), 44 ether);
  }

  function test_Revert_InexactLegacyTransfer() public {
    _activate(10);
    veloV2.setFee(true);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_InexactTransfer.selector);
    vm.prank(alice);
    opWrapper.migrate(VELO_V2, 10 ether, 0, bob);
    assertEq(veloV2.balanceOf(alice), 1000 ether);
    assertEq(veloV2.balanceOf(DEAD), 0);
    assertEq(opWrapper.totalSupply(), 0);
  }

  function test_Revert_Reentrancy() public {
    _activate(10);
    veloV2.setCallback(address(opWrapper), abi.encodeCall(opWrapper.migrate, (OLD_AERO, 1 ether, 0, bob)));
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    vm.prank(alice);
    opWrapper.migrate(VELO_V2, 10 ether, 0, bob);
    assertEq(veloV2.balanceOf(alice), 1000 ether);
    assertEq(veloV2.balanceOf(DEAD), 0);
    assertEq(opWrapper.totalSupply(), 0);
  }
}

contract Unit_WrappedTokenV3_PreviewMigration is Base {
  function test_Return_QuoteForEntireUint256Range(uint256 _amount) public {
    vm.chainId(10);
    // Decomposed quotient and remainder avoid a full-width intermediate multiplication.
    uint256 _expected = (_amount / 1000) * 44 + ((_amount % 1000) * 44) / 1000;
    assertEq(opWrapper.previewMigration(VELO_V1, _amount), _expected);
    assertEq(opWrapper.previewMigration(VELO_V2, _amount), _expected);
    assertEq(opWrapper.previewMigration(OLD_AERO, _amount), _amount);
  }

  function test_Return_QuoteForMaximumUint() public {
    vm.chainId(10);
    uint256 _amount = type(uint256).max;
    uint256 _expected = (_amount / 1000) * 44 + ((_amount % 1000) * 44) / 1000;
    assertEq(opWrapper.previewMigration(VELO_V2, _amount), _expected);
    assertEq(opWrapper.previewMigration(OLD_AERO, _amount), _amount);
  }
}

contract Unit_WrappedTokenV3_TransferRemote is Base {
  function test_Revert_UnauthenticatedOrUnenrolledMessage() public {
    vm.chainId(10);
    bytes memory _message = abi.encodePacked(_address32(alice), uint256(1 ether));
    vm.expectRevert('MailboxClient: sender not mailbox');
    vm.prank(alice);
    opWrapper.handle(8453, _address32(address(baseWrapper)), _message);
    vm.expectRevert('Enrolled router does not match sender');
    opMailbox.deliver(address(opWrapper), 8453, _address32(alice), _message);
    vm.expectRevert();
    opMailbox.deliver(address(opWrapper), 1, _address32(address(baseWrapper)), _message);
    _assertCombinedSupply(0, 0);
  }

  function test_Conserve_CombinedSupplyIncludingPendingMessages() public {
    _activate(8453);
    vm.prank(alice);
    baseWrapper.deposit(alice, 20 ether);
    _activate(10);
    vm.prank(alice);
    opWrapper.deposit(alice, 10 ether);
    _assertCombinedSupply(30 ether, 0);
    vm.chainId(8453);
    vm.prank(alice);
    baseWrapper.transferRemote(10, _address32(bob), 7 ether);
    assertEq(baseWrapper.balanceOf(alice), 13 ether);
    assertEq(opWrapper.balanceOf(bob), 0);
    _assertCombinedSupply(30 ether, 7 ether);
    vm.chainId(10);
    baseMailbox.relayLastTo(opMailbox);
    assertEq(opWrapper.balanceOf(bob), 7 ether);
    _assertCombinedSupply(30 ether, 0);
    vm.prank(bob);
    opWrapper.transferRemote(8453, _address32(bob), 3 ether);
    assertEq(opWrapper.balanceOf(bob), 4 ether);
    _assertCombinedSupply(30 ether, 3 ether);
    vm.chainId(8453);
    opMailbox.relayLastTo(baseMailbox);
    assertEq(baseWrapper.balanceOf(bob), 3 ether);
    _assertCombinedSupply(30 ether, 0);
    assertEq(baseAero.balanceOf(address(baseTreasury)), 20 ether);
    assertEq(opAero.balanceOf(address(opTreasury)), 10 ether);
  }

  function test_Mint_MigratedTokensOnBase() public {
    _activate(10);
    vm.prank(alice);
    opWrapper.migrate(VELO_V2, 1000 ether, 44 ether, bob);
    vm.prank(bob);
    opWrapper.transferRemote(8453, _address32(bob), 44 ether);
    _assertCombinedSupply(44 ether, 44 ether);
    vm.chainId(8453);
    opMailbox.relayLastTo(baseMailbox);
    assertEq(baseWrapper.balanceOf(bob), 44 ether);
    assertTrue(baseWrapper.paused());
    _assertCombinedSupply(44 ether, 0);
    assertEq(veloV2.balanceOf(DEAD), 1000 ether);
  }
}

contract Unit_WrappedTokenV3_Authorization is Base {
  function test_Set_AuthorizationThroughDelegationAndRevocation() public {
    WrappedTokenV3[2] memory _wrappers = [baseWrapper, opWrapper];
    uint256[2] memory _chains = [uint256(8453), uint256(10)];

    for (uint256 _i; _i < _wrappers.length; ++_i) {
      WrappedTokenV3 _wrapper = _wrappers[_i];
      vm.chainId(_chains[_i]);
      _wrapper.addAuthorization(alice);
      assertTrue(_wrapper.authorizedAccounts(alice));
      assertEq(_wrapper.authorizedAccounts().length, 2);

      vm.startPrank(alice);
      _wrapper.unpause();
      _wrapper.addAuthorization(bob);
      vm.stopPrank();
      assertFalse(_wrapper.paused());
      assertTrue(_wrapper.authorizedAccounts(bob));

      vm.startPrank(bob);
      _wrapper.pause();
      _wrapper.removeAuthorization(alice);
      vm.stopPrank();
      assertTrue(_wrapper.paused());
      assertFalse(_wrapper.authorizedAccounts(alice));

      vm.startPrank(alice);
      vm.expectRevert(IAuthorizable.Unauthorized.selector);
      _wrapper.unpause();
      vm.expectRevert(IAuthorizable.Unauthorized.selector);
      _wrapper.addAuthorization(alice);
      vm.expectRevert(IAuthorizable.Unauthorized.selector);
      _wrapper.removeAuthorization(bob);
      vm.expectRevert(IAuthorizable.Unauthorized.selector);
      _wrapper.modifyParameters('baseTokenManager', abi.encode(address(opTreasury)));
      vm.stopPrank();

      _wrapper.removeAuthorization(bob);
      assertEq(_wrapper.authorizedAccounts().length, 1);
    }
  }

  function test_Revert_UnauthorizedLocalAdministration() public {
    WrappedTokenV3[2] memory _wrappers = [baseWrapper, opWrapper];
    address[2] memory _treasuries = [address(baseTreasury), address(opTreasury)];
    uint256[2] memory _chains = [uint256(8453), uint256(10)];

    for (uint256 _i; _i < _wrappers.length; ++_i) {
      WrappedTokenV3 _wrapper = _wrappers[_i];
      vm.chainId(_chains[_i]);
      address[3] memory _callers = [alice, _treasuries[_i], bridgeOwner];

      for (uint256 _j; _j < _callers.length; ++_j) {
        vm.startPrank(_callers[_j]);
        vm.expectRevert(IAuthorizable.Unauthorized.selector);
        _wrapper.unpause();
        vm.expectRevert(IAuthorizable.Unauthorized.selector);
        _wrapper.pause();
        vm.expectRevert(IAuthorizable.Unauthorized.selector);
        _wrapper.modifyParameters('baseTokenManager', abi.encode(bob));
        vm.expectRevert(IAuthorizable.Unauthorized.selector);
        _wrapper.addAuthorization(_callers[_j]);
        vm.expectRevert(IAuthorizable.Unauthorized.selector);
        _wrapper.removeAuthorization(address(this));
        vm.stopPrank();
      }

      assertEq(_wrapper.baseTokenManager(), _treasuries[_i]);
      assertTrue(_wrapper.paused());
      assertEq(_wrapper.authorizedAccounts().length, 1);
    }
  }

  function test_Keep_HyperlaneOwnershipIndependent() public {
    baseWrapper.addAuthorization(alice);
    vm.expectRevert('Ownable: caller is not the owner');
    baseWrapper.enrollRemoteRouter(1, _address32(alice));
    vm.prank(alice);
    vm.expectRevert('Ownable: caller is not the owner');
    baseWrapper.enrollRemoteRouter(1, _address32(alice));

    vm.prank(bridgeOwner);
    baseWrapper.enrollRemoteRouter(1, _address32(alice));
    assertEq(baseWrapper.routers(1), _address32(alice));
    assertFalse(baseWrapper.authorizedAccounts(bridgeOwner));

    baseWrapper.addAuthorization(bridgeOwner);
    vm.prank(bridgeOwner);
    baseWrapper.unpause();
    baseWrapper.removeAuthorization(bridgeOwner);
    vm.prank(bridgeOwner);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    baseWrapper.pause();
    vm.prank(bridgeOwner);
    baseWrapper.unenrollRemoteRouter(1);
    assertEq(baseWrapper.routers(1), bytes32(0));
  }
}

contract Unit_WrappedTokenV3_ModifyParameters is Base {
  function test_Set_BaseTokenManager() public {
    AeroTreasuryMock _newBaseTreasury = new AeroTreasuryMock();
    AeroTreasuryMock _newOpTreasury = new AeroTreasuryMock();
    _activate(8453);
    vm.prank(alice);
    baseWrapper.deposit(bob, 2 ether);
    uint256 _oldNFT = _mintNFT(alice, 7 ether, true);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_oldNFT));

    baseWrapper.addAuthorization(alice);
    vm.prank(alice);
    baseWrapper.modifyParameters('baseTokenManager', abi.encode(address(_newBaseTreasury)));
    vm.prank(alice);
    baseWrapper.deposit(bob, 3 ether);
    uint256 _newNFT = _mintNFT(alice, 3 ether, true);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_newNFT));

    assertEq(baseWrapper.baseTokenManager(), address(_newBaseTreasury));
    assertEq(baseAero.balanceOf(address(baseTreasury)), 2 ether);
    assertEq(baseAero.balanceOf(address(_newBaseTreasury)), 3 ether);
    assertEq(escrow.ownerOf(_oldNFT), address(baseTreasury));
    assertEq(escrow.ownerOf(_newNFT), address(_newBaseTreasury));
    assertEq(baseWrapper.balanceOf(bob), 15 ether);
    assertFalse(baseWrapper.authorizedAccounts(address(_newBaseTreasury)));

    _activate(10);
    vm.prank(alice);
    opWrapper.deposit(bob, 2 ether);
    opWrapper.addAuthorization(alice);
    vm.prank(alice);
    opWrapper.modifyParameters('baseTokenManager', abi.encode(address(_newOpTreasury)));
    vm.prank(alice);
    opWrapper.deposit(bob, 3 ether);

    assertEq(opWrapper.baseTokenManager(), address(_newOpTreasury));
    assertEq(opAero.balanceOf(address(opTreasury)), 2 ether);
    assertEq(opAero.balanceOf(address(_newOpTreasury)), 3 ether);
    assertEq(opWrapper.balanceOf(bob), 5 ether);
    assertFalse(opWrapper.authorizedAccounts(address(_newOpTreasury)));
  }

  function test_Set_BaseTokenManagerDuringTokenCallback() public {
    _activate(8453);
    AeroTreasuryMock _nextTreasury = new AeroTreasuryMock();
    baseWrapper.addAuthorization(address(baseAero));
    baseAero.setCallback(
      address(baseWrapper),
      abi.encodeCall(baseWrapper.modifyParameters, ('baseTokenManager', abi.encode(address(_nextTreasury))))
    );

    vm.prank(alice);
    baseWrapper.deposit(bob, 2 ether);
    assertEq(baseWrapper.baseTokenManager(), address(_nextTreasury));
    assertEq(baseAero.balanceOf(address(baseTreasury)), 2 ether);
    assertEq(baseAero.balanceOf(address(_nextTreasury)), 0);
    assertEq(baseWrapper.balanceOf(bob), 2 ether);

    baseAero.setCallback(address(0), '');
    vm.prank(alice);
    baseWrapper.deposit(bob, 3 ether);
    assertEq(baseAero.balanceOf(address(baseTreasury)), 2 ether);
    assertEq(baseAero.balanceOf(address(_nextTreasury)), 3 ether);
    assertEq(baseWrapper.balanceOf(bob), 5 ether);
  }

  function test_Set_BaseTokenManagerDuringNFTCallback() public {
    _activate(8453);
    AeroTreasuryMock _nextTreasury = new AeroTreasuryMock();
    WrappedTokenV3TreasuryRotationMock _rotatingTreasury =
      new WrappedTokenV3TreasuryRotationMock(IModifiable(address(baseWrapper)), address(_nextTreasury));
    baseWrapper.modifyParameters('baseTokenManager', abi.encode(address(_rotatingTreasury)));
    baseWrapper.addAuthorization(address(_rotatingTreasury));

    uint256[] memory _ids = new uint256[](2);
    _ids[0] = _mintNFT(alice, 7 ether, true);
    _ids[1] = _mintNFT(alice, 3 ether, true);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _ids);

    assertEq(baseWrapper.baseTokenManager(), address(_nextTreasury));
    assertEq(escrow.ownerOf(_ids[0]), address(_rotatingTreasury));
    assertEq(escrow.ownerOf(_ids[1]), address(_rotatingTreasury));
    assertEq(baseWrapper.balanceOf(bob), 10 ether);

    uint256 _nextNFT = _mintNFT(alice, 5 ether, true);
    vm.prank(alice);
    baseWrapper.depositNFTs(bob, _oneId(_nextNFT));
    assertEq(escrow.ownerOf(_nextNFT), address(_nextTreasury));
    assertEq(baseWrapper.balanceOf(bob), 15 ether);
  }

  function test_Revert_InvalidBaseTokenManagerOrParameter() public {
    WrappedTokenV3[2] memory _wrappers = [baseWrapper, opWrapper];
    address[2] memory _treasuries = [address(baseTreasury), address(opTreasury)];
    uint256[2] memory _chains = [uint256(8453), uint256(10)];

    for (uint256 _i; _i < _wrappers.length; ++_i) {
      WrappedTokenV3 _wrapper = _wrappers[_i];
      vm.chainId(_chains[_i]);
      vm.expectRevert(Assertions.NullAddress.selector);
      _wrapper.modifyParameters('baseTokenManager', abi.encode(address(0)));
      vm.expectRevert(Encoding.Encoding_InvalidDataLength.selector);
      _wrapper.modifyParameters('baseTokenManager', hex'01');
      vm.expectRevert(IModifiable.UnrecognizedParam.selector);
      _wrapper.modifyParameters('unknown', abi.encode(alice));
      assertEq(_wrapper.baseTokenManager(), _treasuries[_i]);
    }
  }
}

contract Unit_WrappedTokenV3_Pause is Base {
  function test_Stop_LocalIssuanceWhileTransfersAndBridgingContinue() public {
    _activate(10);
    vm.prank(alice);
    opWrapper.migrate(OLD_AERO, 10 ether, 10 ether, alice);
    opWrapper.pause();
    vm.startPrank(alice);
    vm.expectRevert();
    opWrapper.migrate(OLD_AERO, 1 ether, 0, alice);
    opWrapper.transfer(bob, 3 ether);
    opWrapper.transferRemote(8453, _address32(alice), 7 ether);
    vm.stopPrank();
    vm.chainId(8453);
    opMailbox.relayLastTo(baseMailbox);
    assertEq(baseWrapper.balanceOf(alice), 7 ether);
    assertEq(opWrapper.balanceOf(bob), 3 ether);
    _assertCombinedSupply(10 ether, 0);
  }
}

contract Unit_WrappedTokenV3_Permit is Base {
  function test_Set_AllowanceAndRejectReplay() public {
    _activate(8453);
    vm.prank(alice);
    baseWrapper.deposit(alice, 10 ether);
    uint256 _deadline = block.timestamp + 1 hours;
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(ALICE_KEY, _permitDigest(baseWrapper, 3 ether, 0, _deadline));
    baseWrapper.permit(alice, bob, 3 ether, _deadline, _v, _r, _s);
    assertEq(baseWrapper.nonces(alice), 1);
    assertEq(baseWrapper.allowance(alice, bob), 3 ether);
    vm.prank(bob);
    baseWrapper.transferFrom(alice, bob, 3 ether);
    assertEq(baseWrapper.balanceOf(bob), 3 ether);
    assertEq(baseWrapper.allowance(alice, bob), 0);
    vm.expectRevert();
    baseWrapper.permit(alice, bob, 3 ether, _deadline, _v, _r, _s);
    assertEq(baseWrapper.nonces(alice), 1);
    assertEq(baseWrapper.allowance(alice, bob), 0);
  }

  function test_Revert_WrongContractOrChainDomain() public {
    uint256 _deadline = block.timestamp + 1 hours;
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(ALICE_KEY, _permitDigest(baseWrapper, 3 ether, 0, _deadline));
    vm.expectRevert();
    opWrapper.permit(alice, bob, 3 ether, _deadline, _v, _r, _s);
    vm.chainId(10);
    vm.expectRevert();
    baseWrapper.permit(alice, bob, 3 ether, _deadline, _v, _r, _s);
    assertEq(baseWrapper.nonces(alice), 0);
    assertEq(opWrapper.nonces(alice), 0);
    assertEq(baseWrapper.allowance(alice, bob), 0);
  }

  function test_Revert_ExpiredSignature() public {
    uint256 _deadline = block.timestamp - 1;
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(ALICE_KEY, _permitDigest(baseWrapper, 3 ether, 0, _deadline));
    vm.expectRevert(abi.encodeWithSelector(IWrappedTokenV3.ERC2612ExpiredSignature.selector, _deadline));
    baseWrapper.permit(alice, bob, 3 ether, _deadline, _v, _r, _s);
    assertEq(baseWrapper.nonces(alice), 0);
    assertEq(baseWrapper.allowance(alice, bob), 0);
  }
}

contract Unit_WrappedTokenV3_ChainValidation is Base {
  function test_Revert_OperationOnUnsupportedChain() public {
    _activate(10);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_UnsupportedOperation.selector);
    vm.prank(alice);
    opWrapper.depositNFTs(bob, _oneId(1));
    _activate(8453);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_UnsupportedOperation.selector);
    vm.prank(alice);
    baseWrapper.migrate(VELO_V2, 1 ether, 0, bob);
  }

  function test_Revert_ChangedDeploymentChain() public {
    _activate(8453);
    _activate(10);
    vm.chainId(1);
    vm.startPrank(alice);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_WrongChain.selector);
    baseWrapper.deposit(bob, 1 ether);
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_WrongChain.selector);
    baseWrapper.depositNFTs(bob, _oneId(1));
    vm.expectRevert(IWrappedTokenV3.WrappedTokenV3_WrongChain.selector);
    opWrapper.migrate(VELO_V2, 1 ether, 0, bob);
    vm.stopPrank();
    _assertCombinedSupply(0, 0);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {WrappedToken, IWrappedToken} from '@contracts/tokens/WrappedToken.sol';
import {IVotingEscrow, LockedBalance} from '@interfaces/external/IVotingEscrow.sol';
import {WrappedTokenV2, IWrappedTokenV2} from '@contracts/tokens/WrappedTokenV2.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {VotingEscrowForTest} from '@test/mocks/VotingEscrowForTest.sol';
import 'forge-std/console.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address baseTokenManager = label('baseTokenManager');

  address BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

  WrappedToken wrappedTokenV1;
  WrappedTokenV2 wrappedTokenV2;

  uint256 tokenIdA;
  uint256 tokenIdB;
  uint256 tokenIdC;
  uint256 tokenIdD;

  uint256 lockEnd = 1_879_113_600;

  MintableERC20 mockBaseToken;
  VotingEscrowForTest mockBaseTokenNFT;
  string name = 'HAI Base Token';
  string symbol = 'haiBTKN';

  function setUp() public virtual {
    vm.startPrank(deployer);

    // Deploy mock base token
    mockBaseToken = new MintableERC20('HAI Base Token', 'haiBTKN', 18);

    // Deploy mock base token NFT
    mockBaseTokenNFT = new VotingEscrowForTest();

    tokenIdA = mockBaseTokenNFT.mint(user);
    tokenIdB = mockBaseTokenNFT.mint(user);
    tokenIdC = mockBaseTokenNFT.mint(user);
    tokenIdD = mockBaseTokenNFT.mint(user);

    mockBaseTokenNFT.setLockedBalance(tokenIdA, 100, lockEnd, true);
    mockBaseTokenNFT.setLockedBalance(tokenIdB, 200, lockEnd, true);
    mockBaseTokenNFT.setLockedBalance(tokenIdC, 300, lockEnd, true);
    mockBaseTokenNFT.setLockedBalance(tokenIdD, 0, lockEnd, true);

    // LockedBalance memory lockedBalanceA = mockBaseTokenNFT.locked(tokenIdA);
    // LockedBalance memory lockedBalanceB = mockBaseTokenNFT.locked(tokenIdB);
    // LockedBalance memory lockedBalanceC = mockBaseTokenNFT.locked(tokenIdC);

    // console.log("lockedBalanceA", lockedBalanceA.amount);
    // console.log("lockedBalanceB", lockedBalanceB.amount);
    // console.log("lockedBalanceC", lockedBalanceC.amount);

    wrappedTokenV1 = new WrappedToken(name, symbol, address(mockBaseToken), baseTokenManager);

    wrappedTokenV2 = new WrappedTokenV2(
      name, symbol, address(mockBaseToken), address(mockBaseTokenNFT), baseTokenManager, address(wrappedTokenV1)
    );

    wrappedTokenV2.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_WrappedToken_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Set_Name(string memory _name) public happyPath {
    wrappedTokenV2 = new WrappedTokenV2(
      _name, symbol, address(mockBaseToken), address(mockBaseTokenNFT), baseTokenManager, address(wrappedTokenV1)
    );
    assertEq(wrappedTokenV2.name(), _name);
  }

  function test_Set_Symbol(string memory _symbol) public happyPath {
    wrappedTokenV2 = new WrappedTokenV2(
      name, _symbol, address(mockBaseToken), address(mockBaseTokenNFT), baseTokenManager, address(wrappedTokenV1)
    );
    assertEq(wrappedTokenV2.symbol(), _symbol);
  }

  function test_Set_BaseToken() public happyPath {
    assertEq(address(wrappedTokenV2.BASE_TOKEN()), address(mockBaseToken));
  }

  function test_Set_BaseTokenNFT() public happyPath {
    assertEq(address(wrappedTokenV2.BASE_TOKEN_NFT()), address(mockBaseTokenNFT));
  }

  function test_Set_WrappedTokenV1() public happyPath {
    assertEq(address(wrappedTokenV2.WRAPPED_TOKEN_V1()), address(wrappedTokenV1));
  }

  function test_Set_BaseTokenManager() public happyPath {
    assertEq(wrappedTokenV2.baseTokenManager(), baseTokenManager);
  }

  function test_Revert_NullBaseToken() public happyPath {
    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullBaseToken.selector);
    new WrappedTokenV2(name, symbol, address(0), address(mockBaseTokenNFT), baseTokenManager, address(wrappedTokenV1));
  }

  function test_Revert_NullBaseTokenManager() public happyPath {
    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullBaseTokenManager.selector);
    new WrappedTokenV2(
      name, symbol, address(mockBaseToken), address(mockBaseTokenNFT), address(0), address(wrappedTokenV1)
    );
  }

  function test_Revert_NullBaseTokenNFT() public happyPath {
    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullBaseTokenNFT.selector);
    new WrappedTokenV2(name, symbol, address(mockBaseToken), address(0), baseTokenManager, address(wrappedTokenV1));
  }

  function test_Revert_NullWrappedTokenV1() public happyPath {
    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullWrappedTokenV1.selector);
    new WrappedTokenV2(name, symbol, address(mockBaseToken), address(mockBaseTokenNFT), baseTokenManager, address(0));
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);
    new WrappedTokenV2(
      name, symbol, address(mockBaseToken), address(mockBaseTokenNFT), baseTokenManager, address(wrappedTokenV1)
    );
  }
}

contract Unit_WrappedToken_Deposit is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event WrappedTokenV2Deposit(address indexed _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wad) {
    vm.startPrank(_account);
    _assumeHappyPath(_account, _wad);
    _;
  }

  function _assumeHappyPath(address _account, uint256 _wad) internal pure {
    vm.assume(_account != address(0));
    vm.assume(_wad > 0);
    vm.assume(_wad <= type(uint192).max);
  }

  function _setupDeposit(uint256 _wad) internal {
    mockBaseToken.mint(user, _wad);
    mockBaseToken.approve(address(wrappedTokenV2), _wad);
  }

  function test_Revert_NullReceiver(uint256 _wad) public {
    vm.startPrank(user);
    vm.assume(_wad > 0);

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullReceiver.selector);
    wrappedTokenV2.deposit(address(0), _wad);
  }

  function test_Revert_NullAmount(address _account) public {
    vm.startPrank(user);
    vm.assume(_account != address(0));

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullAmount.selector);
    wrappedTokenV2.deposit(_account, 0);
  }

  function test_Call_TransferFrom(uint256 _wad) public happyPath(user, _wad) {
    _setupDeposit(_wad);
    vm.expectCall(address(mockBaseToken), abi.encodeCall(IERC20.transferFrom, (user, baseTokenManager, _wad)));
    wrappedTokenV2.deposit(user, _wad);
  }

  function test_Mint_Tokens(uint256 _wad) public happyPath(user, _wad) {
    _setupDeposit(_wad);
    uint256 _balanceBefore = wrappedTokenV2.balanceOf(user);

    wrappedTokenV2.deposit(user, _wad);

    assertEq(wrappedTokenV2.balanceOf(user), _balanceBefore + _wad);
  }

  function test_Emit_Transfer(uint256 _wad) public happyPath(user, _wad) {
    _setupDeposit(_wad);
    vm.expectEmit();
    emit Transfer(address(0), user, _wad);

    wrappedTokenV2.deposit(user, _wad);
  }

  function test_Emit_WrappedTokenDeposit(uint256 _wad) public happyPath(user, _wad) {
    _setupDeposit(_wad);
    vm.expectEmit();
    emit WrappedTokenV2Deposit(user, _wad);

    wrappedTokenV2.deposit(user, _wad);
  }
}

contract Unit_WrappedToken_DepositNFTs is Base {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  event WrappedTokenV2NFTDeposit(address indexed _account, uint256 _tokenId, uint256 _wad);

  modifier happyPath(address _account) {
    vm.startPrank(user);
    _assumeHappyPath(_account);
    _;
  }

  function _assumeHappyPath(address _account) internal pure {
    vm.assume(_account != address(0));
  }

  function test_Revert_NullReceiver() public {
    vm.startPrank(user);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullReceiver.selector);
    wrappedTokenV2.depositNFTs(address(0), tokenIds);
  }

  function test_Revert_EmptyTokenIds() public {
    vm.startPrank(user);
    vm.assume(user != address(0));

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_EmptyTokenIds.selector);
    wrappedTokenV2.depositNFTs(user, new uint256[](0));
  }

  function test_Revert_BalanceIsZero() public {
    vm.startPrank(user);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdD;

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_BalanceIsZero.selector);
    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_SingleNFT_Call_TransferFrom() public happyPath(user) {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdA;

    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    bytes memory expectedCallData =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', user, baseTokenManager, tokenIdA);
    vm.expectCall(address(mockBaseTokenNFT), expectedCallData);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Call_TransferFrom() public happyPath(user) {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    bytes memory expectedCallDataA =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', user, baseTokenManager, tokenIdA);
    vm.expectCall(address(mockBaseTokenNFT), expectedCallDataA);

    bytes memory expectedCallDataB =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', user, baseTokenManager, tokenIdB);
    vm.expectCall(address(mockBaseTokenNFT), expectedCallDataB);

    bytes memory expectedCallDataC =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', user, baseTokenManager, tokenIdC);
    vm.expectCall(address(mockBaseTokenNFT), expectedCallDataC);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_SingleNFT_Deposit_Mint_Tokens() public happyPath(user) {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdA;

    LockedBalance memory _lockedBalanceBefore = mockBaseTokenNFT.locked(tokenIdA);

    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    wrappedTokenV2.depositNFTs(user, tokenIds);

    assertEq(wrappedTokenV2.balanceOf(user), uint256(int256(_lockedBalanceBefore.amount)));
  }

  function test_MultipleNFTs_Deposit_Mint_Tokens() public happyPath(user) {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    LockedBalance memory _lockedBalanceBeforeA = mockBaseTokenNFT.locked(tokenIdA);

    LockedBalance memory _lockedBalanceBeforeB = mockBaseTokenNFT.locked(tokenIdB);

    LockedBalance memory _lockedBalanceBeforeC = mockBaseTokenNFT.locked(tokenIdC);

    uint256 _totalLockedBalanceBefore = uint256(int256(_lockedBalanceBeforeA.amount))
      + uint256(int256(_lockedBalanceBeforeB.amount)) + uint256(int256(_lockedBalanceBeforeC.amount));

    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    wrappedTokenV2.depositNFTs(user, tokenIds);

    assertEq(wrappedTokenV2.balanceOf(user), _totalLockedBalanceBefore);
  }

  function test_SingleNFT_Deposit_Emit_Transfer_ERC721() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdA;

    vm.expectEmit();

    emit Transfer(user, baseTokenManager, tokenIdA);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Deposit_Emit_Transfer_ERC721() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdA);
    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdB);
    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdC);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_SingleNFT_Deposit_Emit_WrappedTokenV2NFTDeposit() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdA;

    LockedBalance memory _lockedBalanceBefore = mockBaseTokenNFT.locked(tokenIdA);

    vm.expectEmit(true, true, true, true);

    emit WrappedTokenV2NFTDeposit(user, tokenIdA, uint256(int256(_lockedBalanceBefore.amount)));

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Deposit_Emit_WrappedTokenV2NFTDeposit() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    LockedBalance memory _lockedBalanceBeforeA = mockBaseTokenNFT.locked(tokenIdA);

    LockedBalance memory _lockedBalanceBeforeB = mockBaseTokenNFT.locked(tokenIdB);

    LockedBalance memory _lockedBalanceBeforeC = mockBaseTokenNFT.locked(tokenIdC);

    vm.expectEmit(true, true, true, true);

    emit WrappedTokenV2NFTDeposit(user, tokenIdA, uint256(int256(_lockedBalanceBeforeA.amount)));

    vm.expectEmit(true, true, true, true);
    emit WrappedTokenV2NFTDeposit(user, tokenIdB, uint256(int256(_lockedBalanceBeforeB.amount)));

    vm.expectEmit(true, true, true, true);
    emit WrappedTokenV2NFTDeposit(user, tokenIdC, uint256(int256(_lockedBalanceBeforeC.amount)));

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Emit_Transfer_ERC721() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdA);
    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdB);
    vm.expectEmit(true, true, true, false);
    emit Transfer(user, baseTokenManager, tokenIdC);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_Revert_DuplicateTokenIds() public happyPath(user) {
    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdA;

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_DuplicateTokenIds.selector);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }
}

contract Unit_WrappedToken_DepositNFTs_ERC20_Events is Base {
  event Transfer(address indexed from, address indexed to, uint256 _value);

  modifier happyPath(address _account) {
    vm.startPrank(user);
    _assumeHappyPath(_account);
    _;
  }

  function _assumeHappyPath(address _account) internal pure {
    vm.assume(_account != address(0));
  }

  function test_SingleNFT_Emit_ERC20_Transfer_On_Deposit() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdA;

    LockedBalance memory _lockedBalanceBefore = mockBaseTokenNFT.locked(tokenIdA);

    // Check for ERC20 Transfer event from wrappedTokenV2
    vm.expectEmit(true, true, false, true, address(wrappedTokenV2));
    emit Transfer(address(0), user, uint256(int256(_lockedBalanceBefore.amount)));

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Emit_ERC20_Transfer_On_Deposit() public happyPath(user) {
    mockBaseTokenNFT.setApprovalForAll(address(wrappedTokenV2), true);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    LockedBalance memory _lockedBalanceBeforeA = mockBaseTokenNFT.locked(tokenIdA);

    LockedBalance memory _lockedBalanceBeforeB = mockBaseTokenNFT.locked(tokenIdB);

    LockedBalance memory _lockedBalanceBeforeC = mockBaseTokenNFT.locked(tokenIdC);

    uint256 expectedAmount = uint256(int256(_lockedBalanceBeforeA.amount))
      + uint256(int256(_lockedBalanceBeforeB.amount)) + uint256(int256(_lockedBalanceBeforeC.amount));

    // Check for ERC20 Transfer event from wrappedTokenV2
    vm.expectEmit(true, true, false, true, address(wrappedTokenV2));
    emit Transfer(address(0), user, expectedAmount);

    wrappedTokenV2.depositNFTs(user, tokenIds);
  }
}

contract Unit_WrappedToken_MigrateV1toV2 is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event WrappedTokenV2MigrateV1toV2(address indexed _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wad) {
    vm.startPrank(_account);
    _assumeHappyPath(_account, _wad);
    _;
  }

  function _assumeHappyPath(address _account, uint256 _wad) internal pure {
    vm.assume(_account != address(0));
    vm.assume(_wad > 0);
    vm.assume(_wad <= type(uint192).max);
  }

  function test_Revert_NullReceiver(uint256 _wad) public {
    vm.startPrank(user);
    vm.assume(_wad > 0);

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullReceiver.selector);
    wrappedTokenV2.migrateV1toV2(address(0), _wad);
  }

  function test_Revert_NullAmount() public {
    vm.startPrank(user);
    vm.assume(user != address(0));

    vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullAmount.selector);
    wrappedTokenV2.migrateV1toV2(user, 0);
  }

  function test_Call_TransferFrom(uint256 _wad) public happyPath(user, _wad) {
    mockBaseToken.mint(user, _wad);
    vm.startPrank(user);
    mockBaseToken.approve(address(wrappedTokenV1), _wad);
    wrappedTokenV1.deposit(user, _wad);

    wrappedTokenV1.approve(address(wrappedTokenV2), _wad);

    vm.expectCall(
      address(wrappedTokenV1),
      abi.encodeCall(IERC20.transferFrom, (user, address(0x000000000000000000000000000000000000dEaD), _wad))
    );

    wrappedTokenV2.migrateV1toV2(user, _wad);
  }

  function test_Mint_Tokens(uint256 _wad) public happyPath(user, _wad) {
    uint256 _balanceBefore = wrappedTokenV2.balanceOf(user);

    mockBaseToken.mint(user, _wad);
    vm.startPrank(user);
    mockBaseToken.approve(address(wrappedTokenV1), _wad);
    wrappedTokenV1.deposit(user, _wad);

    wrappedTokenV1.approve(address(wrappedTokenV2), _wad);
    wrappedTokenV2.migrateV1toV2(user, _wad);

    assertEq(wrappedTokenV2.balanceOf(user), _balanceBefore + _wad);
  }

  function test_Emit_Transfer(uint256 _wad) public happyPath(user, _wad) {
    mockBaseToken.mint(user, _wad);
    vm.startPrank(user);
    mockBaseToken.approve(address(wrappedTokenV1), _wad);
    wrappedTokenV1.deposit(user, _wad);

    wrappedTokenV1.approve(address(wrappedTokenV2), _wad);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), user, _wad);
    wrappedTokenV2.migrateV1toV2(user, _wad);
  }

  function test_Emit_WrappedTokenV2MigrateV1toV2(uint256 _wad) public happyPath(user, _wad) {
    mockBaseToken.mint(user, _wad);
    vm.startPrank(user);
    mockBaseToken.approve(address(wrappedTokenV1), _wad);
    wrappedTokenV1.deposit(user, _wad);

    wrappedTokenV1.approve(address(wrappedTokenV2), _wad);

    vm.expectEmit(true, true, true, false);
    emit WrappedTokenV2MigrateV1toV2(user, _wad);

    wrappedTokenV2.migrateV1toV2(user, _wad);
  }
}

contract Unit_WrappedToken_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_ModifyParameters_Set_BaseTokenManager_Contract(address _baseTokenManager)
    public
    happyPath
    mockAsContract(_baseTokenManager)
  {
    wrappedTokenV2.modifyParameters('baseTokenManager', abi.encode(_baseTokenManager));

    assertEq(wrappedTokenV2.baseTokenManager(), _baseTokenManager);
  }

  function test_ModifyParameters_Set_BaseTokenManager_EOA(address _baseTokenManager) public happyPath {
    vm.assume(_baseTokenManager != address(0));
    wrappedTokenV2.modifyParameters('baseTokenManager', abi.encode(_baseTokenManager));

    assertEq(wrappedTokenV2.baseTokenManager(), _baseTokenManager);
  }
}

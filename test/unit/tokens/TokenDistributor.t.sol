// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {TokenDistributor, ITokenDistributor} from '@contracts/tokens/TokenDistributor.sol';
import {TokenDistributorMinter, ITokenDistributorMinter} from '@contracts/tokens/TokenDistributorMinter.sol';
import {TokenDistributorTransfer, ITokenDistributorTransfer} from '@contracts/tokens/TokenDistributorTransfer.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {MerkleTreeGenerator} from '@test/utils/MerkleTreeGenerator.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  MerkleTreeGenerator merkleTreeGenerator;
  ITokenDistributorMinter tokenDistributorMinter;
  ITokenDistributorTransfer tokenDistributorTransfer;

  bytes32[] merkleTree;
  bytes32[] leaves;
  bytes32[] validEveProofs;

  bytes32 merkleRoot;

  address[] airdropRecipients;

  uint256[] airdropAmounts;

  uint256 airdropAmount = 100_000;
  uint256 totalClaimable = 500_000;
  uint256 claimPeriodStart = block.timestamp + 10 days;
  uint256 claimPeriodEnd = block.timestamp + 20 days;

  IProtocolToken tokenMinter = IProtocolToken(label('TokenMinter'));
  IERC20 tokenTransfer = new ERC20ForTest();

  address deployer = label('deployer');
  address delegatee;

  event Claimed(address _user, uint256 _amount);

  function setUp() public virtual {
    airdropRecipients = new address[](5);
    airdropRecipients[0] = label('alice');
    airdropRecipients[1] = label('bob');
    airdropRecipients[2] = label('charlie');
    airdropRecipients[3] = label('david');
    airdropRecipients[4] = label('eve');

    airdropAmounts = new uint256[](5);
    airdropAmounts[0] = airdropAmount;
    airdropAmounts[1] = airdropAmount;
    airdropAmounts[2] = airdropAmount;
    airdropAmounts[3] = airdropAmount;
    airdropAmounts[4] = airdropAmount;

    for (uint256 i = 0; i < airdropRecipients.length; i++) {
      leaves.push(keccak256(bytes.concat(keccak256(abi.encode(airdropRecipients[i], airdropAmounts[i])))));
    }

    vm.prank(deployer);
    merkleTreeGenerator = new MerkleTreeGenerator();
    merkleTree = merkleTreeGenerator.generateMerkleTree(leaves);
    merkleRoot = merkleTree[0];

    delegatee = label('delegatee');

    _mockERC20VotesDelegate(deployer);

    vm.prank(deployer);

    tokenDistributorMinter =
      new TokenDistributorMinter(address(tokenMinter), merkleRoot, totalClaimable, claimPeriodStart, claimPeriodEnd);

    vm.prank(deployer);

    tokenDistributorTransfer =
      new TokenDistributorTransfer(address(tokenTransfer), merkleRoot, totalClaimable, claimPeriodStart, claimPeriodEnd);

    uint256 _index = merkleTreeGenerator.getIndex(merkleTree, leaves[4]);
    validEveProofs = merkleTreeGenerator.getProof(merkleTree, _index);
  }

  function _mockERC20VotesDelegate(address _delegatee) internal {
    vm.mockCall(address(tokenMinter), abi.encodeCall(tokenMinter.delegate, (_delegatee)), abi.encode(0));
  }

  function _mockERC20VotesDelegateBySig(
    address _delegatee,
    uint256 _nonce,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) internal {
    vm.mockCall(
      address(tokenMinter),
      abi.encodeCall(tokenMinter.delegateBySig, (_delegatee, _nonce, _expiry, _v, _r, _s)),
      abi.encode(0)
    );
  }

  function _mockERC20Nonces(address _user, uint256 _nonce) internal {
    vm.mockCall(address(tokenMinter), abi.encodeCall(tokenMinter.nonces, address(_user)), abi.encode(_nonce));
  }

  function _mockTotalClaimable(address _distributor, uint256 _totalClaimable) internal {
    stdstore.target(_distributor).sig(ITokenDistributor.totalClaimable.selector).checked_write(_totalClaimable);
  }

  function _mockClaimed(address _distributor, address _user, bool _claimed) internal {
    stdstore.target(_distributor).sig(ITokenDistributor.claimed.selector).with_key(_user).checked_write(_claimed);
  }

  function _mockBalanceOfToken(address _token, address _account, uint256 _balance) internal {
    stdstore.target(_token).sig(IERC20.balanceOf.selector).with_key(_account).checked_write(_balance);
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }
}

contract Unit_TokenDistributor_Constructor is Base {
  function test_Set_Root() public {
    assertEq(tokenDistributorMinter.root(), merkleRoot);
  }

  function test_Set_TotalClaimable() public {
    assertEq(tokenDistributorMinter.totalClaimable(), totalClaimable);
  }

  function test_Set_ClaimPeriodStart() public {
    assertEq(tokenDistributorMinter.claimPeriodStart(), claimPeriodStart);
  }

  function test_Set_ClaimPeriodEnd() public {
    assertEq(tokenDistributorMinter.claimPeriodEnd(), claimPeriodEnd);
  }

  function test_Revert_TotalClaimable_IsNull() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new TokenDistributorMinter(address(tokenMinter), merkleRoot, 0, claimPeriodStart, claimPeriodEnd);
  }

  function test_Revert_ClaimPeriodStart_LtEqTimeStamp(uint256 _claimPeriodStart) public {
    vm.assume(_claimPeriodStart <= block.timestamp);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _claimPeriodStart, block.timestamp));

    new TokenDistributorMinter(address(tokenMinter), merkleRoot, totalClaimable, _claimPeriodStart, claimPeriodEnd);
  }

  function test_Revert_ClaimPeriodEnd_LtEqClaimPeriodStart(uint256 _claimPeriodStart, uint256 _claimPeriodEnd) public {
    vm.assume(_claimPeriodStart > block.timestamp);
    vm.assume(_claimPeriodEnd <= _claimPeriodStart);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _claimPeriodEnd, _claimPeriodStart));

    new TokenDistributorMinter(address(tokenMinter), merkleRoot, totalClaimable, _claimPeriodStart, _claimPeriodEnd);
  }
}

contract Unit_TokenDistributorMinter_Constructor is Base {
  function test_Set_Token() public {
    assertEq(address(tokenDistributorMinter.token()), address(tokenMinter));
  }

  function test_Revert_Token_NoCode() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new TokenDistributorMinter(address(0), merkleRoot, totalClaimable, claimPeriodStart, claimPeriodEnd);
  }
}

contract Unit_TokenDistributorTransfer_Constructor is Base {
  function test_Set_Token() public {
    assertEq(address(tokenDistributorTransfer.token()), address(tokenTransfer));
  }

  function test_Revert_Token_NoCode() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new TokenDistributorTransfer(address(0), merkleRoot, totalClaimable, claimPeriodStart, claimPeriodEnd);
  }
}

contract Unit_TokenDistributor_CanClaim is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
  }

  function test_CanClaim() public {
    assertTrue(tokenDistributorMinter.canClaim(validEveProofs, airdropRecipients[4], airdropAmounts[4]));
  }

  function test_CanClaim2() public {
    uint256 _index0 = merkleTreeGenerator.getIndex(merkleTree, leaves[0]);
    bytes32[] memory _proof0 = merkleTreeGenerator.getProof(merkleTree, _index0);

    uint256 _index1 = merkleTreeGenerator.getIndex(merkleTree, leaves[1]);
    bytes32[] memory _proof1 = merkleTreeGenerator.getProof(merkleTree, _index1);

    uint256 _index2 = merkleTreeGenerator.getIndex(merkleTree, leaves[2]);
    bytes32[] memory _proof2 = merkleTreeGenerator.getProof(merkleTree, _index2);

    uint256 _index3 = merkleTreeGenerator.getIndex(merkleTree, leaves[3]);
    bytes32[] memory _proof3 = merkleTreeGenerator.getProof(merkleTree, _index3);

    uint256 _index4 = merkleTreeGenerator.getIndex(merkleTree, leaves[4]);
    bytes32[] memory _proof4 = merkleTreeGenerator.getProof(merkleTree, _index4);

    assertTrue(tokenDistributorMinter.canClaim(_proof0, airdropRecipients[0], airdropAmounts[0]));
    assertTrue(tokenDistributorMinter.canClaim(_proof1, airdropRecipients[1], airdropAmounts[1]));
    assertTrue(tokenDistributorMinter.canClaim(_proof2, airdropRecipients[2], airdropAmounts[2]));
    assertTrue(tokenDistributorMinter.canClaim(_proof3, airdropRecipients[3], airdropAmounts[3]));
    assertTrue(tokenDistributorMinter.canClaim(_proof4, airdropRecipients[4], airdropAmounts[4]));
  }

  function test_CannotClaim_WrongProof() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa1a3f90bf752ff0c523967805dfe44f14be); //wrong
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(tokenDistributorMinter.canClaim(_proofs, airdropRecipients[1], airdropAmounts[1]));
  }

  function test_CannotClaim_WrongAmount() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa2a3f90bf752ff0c523967805dfe44f14be);
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(tokenDistributorMinter.canClaim(_proofs, airdropRecipients[1], 499_999));
  }

  function test_CannotClaim_Wrong_Recipient() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa2a3f90bf752ff0c523967805dfe44f14be);
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(tokenDistributorMinter.canClaim(_proofs, newAddress(), airdropAmounts[1]));
  }

  function test_CannotClaimPeriodNotStarted() public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start

    assertFalse(tokenDistributorMinter.canClaim(validEveProofs, airdropRecipients[4], airdropAmounts[4]));
  }

  function test_CannotClaimPeriodEnded() public {
    vm.warp(claimPeriodEnd + 1); // going back in time for claim period start

    assertFalse(tokenDistributorMinter.canClaim(validEveProofs, airdropRecipients[4], airdropAmounts[4]));
  }

  function test_CannotClaimAlreadyClaimed() public {
    _mockClaimed(address(tokenDistributorMinter), airdropRecipients[4], true);
    assertFalse(tokenDistributorMinter.canClaim(validEveProofs, airdropRecipients[4], airdropAmounts[4]));
  }

  function test_CannotClaimZeroAmount() public {
    assertFalse(tokenDistributorMinter.canClaim(validEveProofs, airdropRecipients[4], 0));
  }
}

contract Unit_TokenDistributor_CanClaim_ExternalScript is Base {
  function setUp() public override {
    super.setUp();
    bytes32 _root = 0x30e48fd8bee18a1728bfd9f536125c5a352b778d5b07a92de684b14cb7bb92ad; // Root generated with OZ js library
    tokenDistributorMinter =
      new TokenDistributorMinter(address(tokenMinter), _root, totalClaimable, claimPeriodStart, claimPeriodEnd);
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
  }

  function test_CanClaim_ExternalScriptTree() public {
    bytes32[] memory _proof = new bytes32[](2);
    _proof[0] = 0x8d2ba45bdde7d748373d27ad49f041388b49f15b1732a45081981e4f66cf621a;
    _proof[1] = 0x418e3bfe8d301afb4acee0a38a37f071396fdd1827548d5b459bb0c52e0bcf9a;

    uint256 _amount = 100_000;
    address _recipient = address(0x1C8E4bF2Ccae6dC8246AEF5b791014A6D3Df1DDF);

    assertTrue(tokenDistributorMinter.canClaim(_proof, _recipient, _amount));
  }

  function test_CanClaim_ExternalScriptTree2() public {
    bytes32[] memory _proof = new bytes32[](2);
    _proof[0] = 0xc26a9779f3008fa2fc84c2e7b69fb2c6e66219a2784e6dd46827e4083ffb277e;
    _proof[1] = 0x320622079a0c4c751ac8d3b4b0b4d0177583cc07cf25f493f963f677e62a4c26;

    uint256 _amount = 100_000;
    address _recipient = address(0x5cE727541259Ccc6B15FF5b87Ba50C84Be31A607);

    assertTrue(tokenDistributorMinter.canClaim(_proof, _recipient, _amount));
  }
}

contract Unit_TokenDistributorMinter_Claim is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
    vm.startPrank(airdropRecipients[4]);
  }

  function test_Set_Claimed() public {
    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);

    assertTrue(tokenDistributorMinter.claimed(airdropRecipients[4]));
  }

  function test_Set_TotalClaimable() public {
    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);

    assertEq(tokenDistributorMinter.totalClaimable(), totalClaimable - airdropAmounts[4]);
  }

  function test_Call_Token_Mint() public {
    vm.expectCall(address(tokenMinter), abi.encodeCall(tokenMinter.mint, (airdropRecipients[4], airdropAmounts[4])));

    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Emit_Claimed() public {
    vm.expectEmit();
    emit Claimed(airdropRecipients[4], airdropAmounts[4]);

    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ClaimPeriodNotStarted() public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ClaimPeriodEnded() public {
    vm.warp(claimPeriodEnd + 1); // going ahead in time period ended
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ZeroAmount() public {
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorMinter.claim(validEveProofs, 0);
  }

  function test_Revert_AlreadyClaimed() public {
    _mockClaimed(address(tokenDistributorMinter), airdropRecipients[4], true);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidClaimer() public {
    vm.stopPrank();
    vm.startPrank(newAddress());

    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidProof() public {
    bytes32[] memory _proofs = new bytes32[](3);
    _proofs[0] = bytes32(0xcf9633789ba0907ad3a73ab3be992a886fa3502e11375044250fc340ae0a0613);
    _proofs[1] = bytes32(0xa0246557dc9e869dd36d0dcede531af0ab5a4bddda571c276a4519029b69affa);
    _proofs[2] = bytes32(0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af34); // wrong, the valid is 0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af33

    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claim(_proofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidAmount() public {
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claim(validEveProofs, 499_999);
  }
}

contract Unit_TokenDistributorTransfer_Claim is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
    vm.startPrank(airdropRecipients[4]);
  }

  function test_Set_Claimed() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);

    assertTrue(tokenDistributorTransfer.claimed(airdropRecipients[4]));
  }

  function test_Set_TotalClaimable() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);

    assertEq(tokenDistributorTransfer.totalClaimable(), totalClaimable - airdropAmounts[4]);
  }

  function test_Call_Token_Transfer() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.expectCall(
      address(tokenTransfer), abi.encodeCall(tokenTransfer.transfer, (airdropRecipients[4], airdropAmounts[4]))
    );

    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Emit_Claimed() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.expectEmit();
    emit Claimed(airdropRecipients[4], airdropAmounts[4]);

    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ClaimPeriodNotStarted() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ClaimPeriodEnded() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.warp(claimPeriodEnd + 1); // going ahead in time period ended
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_ZeroAmount() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorTransfer.claim(validEveProofs, 0);
  }

  function test_Revert_AlreadyClaimed() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    _mockClaimed(address(tokenDistributorTransfer), airdropRecipients[4], true);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);

    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidClaimer() public {
    vm.stopPrank();
    vm.startPrank(newAddress());

    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);

    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorTransfer.claim(validEveProofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidProof() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);

    bytes32[] memory _proofs = new bytes32[](3);
    _proofs[0] = bytes32(0xcf9633789ba0907ad3a73ab3be992a886fa3502e11375044250fc340ae0a0613);
    _proofs[1] = bytes32(0xa0246557dc9e869dd36d0dcede531af0ab5a4bddda571c276a4519029b69affa);
    _proofs[2] = bytes32(0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af34); // wrong, the valid is 0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af33

    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorTransfer.claim(_proofs, airdropAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidAmount() public {
    _mockBalanceOfToken(address(tokenTransfer), address(tokenDistributorTransfer), totalClaimable);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorTransfer.claim(validEveProofs, 499_999);
  }
}

contract Unit_TokenDistributorMinter_ClaimAndDelegate is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
    vm.startPrank(airdropRecipients[4]);
  }

  function test_Set_Claimed(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockERC20Nonces(airdropRecipients[4], _nonce);
    _mockERC20VotesDelegateBySig(delegatee, _nonce, _expiry, _v, _r, _s);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
    assertTrue(tokenDistributorMinter.claimed(airdropRecipients[4]));
  }

  function test_Set_TotalClaimable(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockERC20Nonces(airdropRecipients[4], _nonce);
    _mockERC20VotesDelegateBySig(delegatee, 0, _expiry, _v, _r, _s);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
    assertEq(tokenDistributorMinter.totalClaimable(), totalClaimable - airdropAmounts[4]);
  }

  function test_Call_Token_Mint(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockERC20Nonces(airdropRecipients[4], _nonce);
    _mockERC20VotesDelegateBySig(delegatee, 0, _expiry, _v, _r, _s);
    vm.expectCall(address(tokenMinter), abi.encodeCall(tokenMinter.mint, (airdropRecipients[4], airdropAmounts[4])));
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Call_Token_DelegateBySig(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockERC20Nonces(airdropRecipients[4], _nonce);
    vm.expectCall(
      address(tokenMinter), abi.encodeCall(tokenMinter.delegateBySig, (delegatee, _nonce, _expiry, _v, _r, _s))
    );
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Emit_Claimed(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockERC20Nonces(airdropRecipients[4], _nonce);
    _mockERC20VotesDelegateBySig(delegatee, _nonce, _expiry, _v, _r, _s);
    vm.expectEmit();
    emit Claimed(airdropRecipients[4], airdropAmounts[4]);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_ClaimPeriodNotStarted(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_ClaimPeriodEnded(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.warp(claimPeriodEnd + 1); // going ahead in time period ended
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_ZeroAmount(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, 0, delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_AlreadyClaimed(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockClaimed(address(tokenDistributorMinter), airdropRecipients[4], true);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidClaimer(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.stopPrank();
    vm.startPrank(newAddress());
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidProof(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    bytes32[] memory _proofs = new bytes32[](3);
    _proofs[0] = bytes32(0xcf9633789ba0907ad3a73ab3be992a886fa3502e11375044250fc340ae0a0613);
    _proofs[1] = bytes32(0xa0246557dc9e869dd36d0dcede531af0ab5a4bddda571c276a4519029b69affa);
    _proofs[2] = bytes32(0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af34); // wrong, the valid is 0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af33
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(_proofs, airdropAmounts[4], delegatee, _expiry, _v, _r, _s);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidAmount(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimInvalid.selector);
    tokenDistributorMinter.claimAndDelegate(validEveProofs, 499_999, delegatee, _expiry, _v, _r, _s);
  }
}

contract Unit_TokenDistributorMinter_Sweep is Base {
  event Swept(address _sweepReceiver, uint256 _amount);

  address sweepReceiver = label('sweepReceiver');

  function setUp() public override {
    super.setUp();

    vm.warp(claimPeriodEnd + 1);
  }

  function test_Set_TotalClaimable(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorMinter), _totalClaimable);

    tokenDistributorMinter.sweep(sweepReceiver);

    assertEq(tokenDistributorMinter.totalClaimable(), 0);
  }

  function test_Call_Token_Mint(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorMinter), _totalClaimable);

    vm.expectCall(address(tokenMinter), abi.encodeCall(tokenMinter.mint, (sweepReceiver, _totalClaimable)));
    tokenDistributorMinter.sweep(sweepReceiver);
  }

  function test_Emit_Swept(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorMinter), _totalClaimable);

    vm.expectEmit();
    emit Swept(sweepReceiver, _totalClaimable);

    tokenDistributorMinter.sweep(sweepReceiver);
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    tokenDistributorMinter.sweep(sweepReceiver);
  }

  function test_Revert_ClaimPeriodNotEnded(uint256 _time) public authorized {
    vm.assume(_time <= claimPeriodEnd);
    vm.warp(_time);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimPeriodNotEnded.selector);

    tokenDistributorMinter.sweep(sweepReceiver);
  }

  function test_Revert_NullTotalClaimable() public authorized {
    _mockTotalClaimable(address(tokenDistributorMinter), 0);

    vm.expectRevert(Assertions.NullAmount.selector);

    tokenDistributorMinter.sweep(sweepReceiver);
  }
}

contract Unit_TokenDistributorTransfer_Sweep is Base {
  event Swept(address _sweepReceiver, uint256 _amount);

  address sweepReceiver = label('sweepReceiver');

  function setUp() public override {
    super.setUp();

    vm.warp(claimPeriodEnd + 1);
  }

  function test_Set_TotalClaimable(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorTransfer), _totalClaimable);

    tokenDistributorTransfer.sweep(sweepReceiver);

    assertEq(tokenDistributorTransfer.totalClaimable(), 0);
  }

  function test_Call_Token_Transfer(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorTransfer), _totalClaimable);

    vm.expectCall(
      address(tokenTransfer),
      abi.encodeCall(
        tokenTransfer.transfer, (sweepReceiver, tokenTransfer.balanceOf(address(tokenDistributorTransfer)))
      )
    );
    tokenDistributorTransfer.sweep(sweepReceiver);
  }

  function test_Emit_Swept(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);
    _mockTotalClaimable(address(tokenDistributorTransfer), _totalClaimable);

    vm.expectEmit();
    emit Swept(sweepReceiver, _totalClaimable);

    tokenDistributorTransfer.sweep(sweepReceiver);
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    tokenDistributorTransfer.sweep(sweepReceiver);
  }

  function test_Revert_ClaimPeriodNotEnded(uint256 _time) public authorized {
    vm.assume(_time <= claimPeriodEnd);
    vm.warp(_time);
    vm.expectRevert(ITokenDistributor.TokenDistributor_ClaimPeriodNotEnded.selector);

    tokenDistributorTransfer.sweep(sweepReceiver);
  }

  function test_Revert_NullTotalClaimable() public authorized {
    _mockTotalClaimable(address(tokenDistributorTransfer), 0);

    vm.expectRevert(Assertions.NullAmount.selector);

    tokenDistributorTransfer.sweep(sweepReceiver);
  }
}

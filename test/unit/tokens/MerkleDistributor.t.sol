// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/console.sol';
import {MerkleDistributor} from '@contracts/tokens/MerkleDistributor.sol';
import {IMerkleDistributor} from '@interfaces/tokens/IMerkleDistributor.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {MerkleTreeGenerator} from '@test/utils/MerkleTreeGenerator.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  MerkleTreeGenerator merkleTreeGenerator;
  IMerkleDistributor merkleDistributor;

  bytes32[] merkleTree;
  bytes32[] leaves;
  bytes32[] validEveProofs;

  bytes32 merkleRoot;

  address[] distroRecipients;

  uint256[] distroAmounts;

  uint256 distroAmount = 100_000;
  uint256 totalClaimable = 500_000;
  uint256 claimPeriodStart = block.timestamp + 10 days;
  uint256 claimPeriodEnd = block.timestamp + 20 days;

  ERC20ForTest token = new ERC20ForTest();

  address daoTimelock = label('daoTimelock');

  event Claimed(address _user, uint256 _amount);

  function setUp() public virtual {
    distroRecipients = new address[](5);
    distroRecipients[0] = label('alice');
    distroRecipients[1] = label('bob');
    distroRecipients[2] = label('charlie');
    distroRecipients[3] = label('david');
    distroRecipients[4] = label('eve');
    distroAmounts = new uint256[](5);
    distroAmounts[0] = distroAmount;
    distroAmounts[1] = distroAmount;
    distroAmounts[2] = distroAmount;
    distroAmounts[3] = distroAmount;
    distroAmounts[4] = distroAmount;
    for (uint256 i = 0; i < distroRecipients.length; i++) {
      leaves.push(keccak256(bytes.concat(keccak256(abi.encode(distroRecipients[i], distroAmounts[i])))));
    }

    merkleTreeGenerator = new MerkleTreeGenerator();
    merkleTree = merkleTreeGenerator.generateMerkleTree(leaves);
    merkleRoot = merkleTree[0];
    vm.prank(daoTimelock);
    merkleDistributor =
      new MerkleDistributor(address(token), merkleRoot, totalClaimable, claimPeriodStart, claimPeriodEnd);
    uint256 _index = merkleTreeGenerator.getIndex(merkleTree, leaves[4]);
    validEveProofs = merkleTreeGenerator.getProof(merkleTree, _index);

    token.mint(address(this), totalClaimable);

    token.transfer(address(merkleDistributor), totalClaimable);
  }

  function _mockTotalClaimable(uint256 _totalClaimable) internal {
    stdstore.target(address(merkleDistributor)).sig(IMerkleDistributor.totalClaimable.selector).checked_write(
      _totalClaimable
    );
  }

  function _mockClaimed(address _user, bool _claimed) internal {
    stdstore.target(address(merkleDistributor)).sig(IMerkleDistributor.claimed.selector).with_key(_user).checked_write(
      _claimed
    );
  }

  modifier authorized() {
    vm.startPrank(daoTimelock);
    _;
  }
}

contract Unit_MerkleDistributor_Constructor is Base {
  function test_Set_Token() public {
    assertEq(address(merkleDistributor.token()), address(token));
  }

  function test_Set_Root() public {
    assertEq(merkleDistributor.root(), merkleRoot);
  }

  function test_Set_TotalClaimable() public {
    assertEq(merkleDistributor.totalClaimable(), totalClaimable);
  }

  function test_Set_ClaimPeriodStart() public {
    assertEq(merkleDistributor.claimPeriodStart(), claimPeriodStart);
  }

  function test_Set_ClaimPeriodEnd() public {
    assertEq(merkleDistributor.claimPeriodEnd(), claimPeriodEnd);
  }

  // function test_Revert_Token_NoCode() public {
  //     vm.expectRevert(
  //         abi.encodeWithSelector(Assertions.NoCode.selector, address(0))
  //     );

  //     new MerkleDistributor(
  //         address(0),
  //         merkleRoot,
  //         totalClaimable,
  //         claimPeriodStart,
  //         claimPeriodEnd
  //     );
  // }

  function test_Revert_TotalClaimable_IsNull() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new MerkleDistributor(address(token), merkleRoot, 0, claimPeriodStart, claimPeriodEnd);
  }

  function test_Revert_ClaimPeriodStart_LtEqTimeStamp(uint256 _claimPeriodStart) public {
    vm.assume(_claimPeriodStart <= block.timestamp);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _claimPeriodStart, block.timestamp));

    new MerkleDistributor(address(token), merkleRoot, totalClaimable, _claimPeriodStart, claimPeriodEnd);
  }

  function test_Revert_ClaimPeriodEnd_LtEqClaimPeriodStart(uint256 _claimPeriodStart, uint256 _claimPeriodEnd) public {
    vm.assume(_claimPeriodStart > block.timestamp);
    vm.assume(_claimPeriodEnd <= _claimPeriodStart);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _claimPeriodEnd, _claimPeriodStart));

    new MerkleDistributor(address(token), merkleRoot, totalClaimable, _claimPeriodStart, _claimPeriodEnd);
  }
}

contract Unit_MerkleDistributor_CanClaim is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
  }

  function test_CanClaim() public {
    assertTrue(merkleDistributor.canClaim(validEveProofs, distroRecipients[4], distroAmounts[4]));
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

    assertTrue(merkleDistributor.canClaim(_proof0, distroRecipients[0], distroAmounts[0]));
    assertTrue(merkleDistributor.canClaim(_proof1, distroRecipients[1], distroAmounts[1]));
    assertTrue(merkleDistributor.canClaim(_proof2, distroRecipients[2], distroAmounts[2]));
    assertTrue(merkleDistributor.canClaim(_proof3, distroRecipients[3], distroAmounts[3]));
    assertTrue(merkleDistributor.canClaim(_proof4, distroRecipients[4], distroAmounts[4]));
  }

  function test_CannotClaim_WrongProof() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa1a3f90bf752ff0c523967805dfe44f14be); //wrong
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(merkleDistributor.canClaim(_proofs, distroRecipients[1], distroAmounts[1]));
  }

  function test_CannotClaim_WrongAmount() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa2a3f90bf752ff0c523967805dfe44f14be);
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(merkleDistributor.canClaim(_proofs, distroRecipients[1], 499_999));
  }

  function test_CannotClaim_Wrong_Recipient() public {
    bytes32[] memory _proofs = new bytes32[](2);
    _proofs[0] = bytes32(0xbb212d55aa35db46dcf841a5b449aa2a3f90bf752ff0c523967805dfe44f14be);
    _proofs[1] = bytes32(0xd27f827b191db255598965e23fac05aac5731018191e49e7dfa89e1b007aa77e);

    assertFalse(merkleDistributor.canClaim(_proofs, newAddress(), distroAmounts[1]));
  }

  function test_CannotClaimPeriodNotStarted() public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start

    assertFalse(merkleDistributor.canClaim(validEveProofs, distroRecipients[4], distroAmounts[4]));
  }

  function test_CannotClaimPeriodEnded() public {
    vm.warp(claimPeriodEnd + 1); // going back in time for claim period start

    assertFalse(merkleDistributor.canClaim(validEveProofs, distroRecipients[4], distroAmounts[4]));
  }

  function test_CannotClaimAlreadyClaimed() public {
    _mockClaimed(distroRecipients[4], true);
    assertFalse(merkleDistributor.canClaim(validEveProofs, distroRecipients[4], distroAmounts[4]));
  }

  function test_CannotClaimZeroAmount() public {
    assertFalse(merkleDistributor.canClaim(validEveProofs, distroRecipients[4], 0));
  }
}

contract Unit_CanClaim_ExternalScript is Base {
  function setUp() public override {
    super.setUp();
    bytes32 _root = 0x30e48fd8bee18a1728bfd9f536125c5a352b778d5b07a92de684b14cb7bb92ad; // Root generated with OZ js library
    merkleDistributor = new MerkleDistributor(address(token), _root, totalClaimable, claimPeriodStart, claimPeriodEnd);
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
  }

  function test_CanClaim_ExternalScriptTree() public {
    bytes32[] memory _proof = new bytes32[](2);
    _proof[0] = 0x8d2ba45bdde7d748373d27ad49f041388b49f15b1732a45081981e4f66cf621a;
    _proof[1] = 0x418e3bfe8d301afb4acee0a38a37f071396fdd1827548d5b459bb0c52e0bcf9a;

    uint256 _amount = 100_000;
    address _recipient = address(0x1C8E4bF2Ccae6dC8246AEF5b791014A6D3Df1DDF);

    assertTrue(merkleDistributor.canClaim(_proof, _recipient, _amount));
  }

  function test_CanClaim_ExternalScriptTree2() public {
    bytes32[] memory _proof = new bytes32[](2);
    _proof[0] = 0xc26a9779f3008fa2fc84c2e7b69fb2c6e66219a2784e6dd46827e4083ffb277e;
    _proof[1] = 0x320622079a0c4c751ac8d3b4b0b4d0177583cc07cf25f493f963f677e62a4c26;

    uint256 _amount = 100_000;
    address _recipient = address(0x5cE727541259Ccc6B15FF5b87Ba50C84Be31A607);

    assertTrue(merkleDistributor.canClaim(_proof, _recipient, _amount));
  }
}

contract Unit_MerkleDistributor_Claim is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
    vm.startPrank(distroRecipients[4]);
  }

  function test_Set_Claimed() public {
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);

    assertTrue(merkleDistributor.claimed(distroRecipients[4]));
  }

  function test_Set_TotalClaimable() public {
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);

    assertEq(merkleDistributor.totalClaimable(), totalClaimable - distroAmounts[4]);
  }

  function test_Call_Token_Transfer() public {
    vm.expectCall(address(token), abi.encodeCall(token.transfer, (distroRecipients[4], distroAmounts[4])));

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Emit_Claimed() public {
    vm.expectEmit();
    emit Claimed(distroRecipients[4], distroAmounts[4]);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ClaimPeriodNotStarted() public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ClaimPeriodEnded() public {
    vm.warp(claimPeriodEnd + 1); // going ahead in time period ended
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ZeroAmount() public {
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, 0);
  }

  function test_Revert_AlreadyClaimed() public {
    _mockClaimed(distroRecipients[4], true);
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidClaimer() public {
    vm.stopPrank();
    vm.startPrank(newAddress());

    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidProof() public {
    bytes32[] memory _proofs = new bytes32[](3);
    _proofs[0] = bytes32(0xcf9633789ba0907ad3a73ab3be992a886fa3502e11375044250fc340ae0a0613);
    _proofs[1] = bytes32(0xa0246557dc9e869dd36d0dcede531af0ab5a4bddda571c276a4519029b69affa);
    _proofs[2] = bytes32(0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af34); // wrong, the valid is 0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af33

    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);
    merkleDistributor.claim(_proofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidAmount() public {
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);
    merkleDistributor.claim(validEveProofs, 499_999);
  }
}

contract Unit_MerkleDistributor_ClaimAndDelegate is Base {
  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodStart); // going ahead in time for claim period start
    vm.startPrank(distroRecipients[4]);
  }

  function test_Set_Claimed(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);

    assertTrue(merkleDistributor.claimed(distroRecipients[4]));
  }

  function test_Set_TotalClaimable(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);

    assertEq(merkleDistributor.totalClaimable(), totalClaimable - distroAmounts[4]);
  }

  function test_Call_Token_Mint(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectCall(address(token), abi.encodeCall(token.transfer, (distroRecipients[4], distroAmounts[4])));
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Emit_Claimed(uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectEmit();
    emit Claimed(distroRecipients[4], distroAmounts[4]);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ClaimPeriodNotStarted(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.warp(claimPeriodStart - 1); // going back in time for claim period start
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ClaimPeriodEnded(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.warp(claimPeriodEnd + 1); // going ahead in time period ended
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_ZeroAmount(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, 0);
  }

  function test_Revert_AlreadyClaimed(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    _mockClaimed(distroRecipients[4], true);

    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);
    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidClaimer(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.stopPrank();
    vm.startPrank(newAddress());

    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(validEveProofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidProof(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    bytes32[] memory _proofs = new bytes32[](3);
    _proofs[0] = bytes32(0xcf9633789ba0907ad3a73ab3be992a886fa3502e11375044250fc340ae0a0613);
    _proofs[1] = bytes32(0xa0246557dc9e869dd36d0dcede531af0ab5a4bddda571c276a4519029b69affa);
    _proofs[2] = bytes32(0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af34); // wrong, the valid is 0x5372fc2bc58ba885b7863917a0ff8130edf9cca8a1db00c8958f37d59f99af33

    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);

    merkleDistributor.claim(_proofs, distroAmounts[4]);
  }

  function test_Revert_FailedMerkleProofVerify_InvalidAmount(uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s) public {
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimInvalid.selector);
    merkleDistributor.claim(validEveProofs, 499_999);
  }
}

contract Unit_MerkleDistributor_Sweep is Base {
  event Swept(address _sweepReceiver, uint256 _amount);

  address sweepReceiver = label('sweepReceiver');

  function setUp() public override {
    super.setUp();
    vm.warp(claimPeriodEnd + 1);
  }

  function test_Set_TotalClaimable(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);

    merkleDistributor.sweep(sweepReceiver);

    assertEq(merkleDistributor.totalClaimable(), 0);
  }

  function test_Call_Token_Mint(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);

    // _mockTotalClaimable(_totalClaimable);

    // TODO: fix this to use "_totalClaimable" instead of "totalClaimable"
    vm.expectCall(address(token), abi.encodeCall(token.transfer, (sweepReceiver, totalClaimable)));
    merkleDistributor.sweep(sweepReceiver);
  }

  function test_Emit_Swept(uint256 _totalClaimable) public authorized {
    vm.assume(_totalClaimable > 0);

    // _mockTotalClaimable(_totalClaimable);

    vm.expectEmit();

    // TODO: fix this to use "_totalClaimable" instead of "totalClaimable"
    emit Swept(sweepReceiver, totalClaimable);

    merkleDistributor.sweep(sweepReceiver);
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    merkleDistributor.sweep(sweepReceiver);
  }

  function test_Revert_ClaimPeriodNotEnded(uint256 _time) public authorized {
    vm.assume(_time <= claimPeriodEnd);
    vm.warp(_time);
    vm.expectRevert(IMerkleDistributor.MerkleDistributor_ClaimPeriodNotEnded.selector);

    merkleDistributor.sweep(sweepReceiver);
  }

  function test_Revert_NullTotalClaimable() public authorized {
    _mockTotalClaimable(0);

    vm.expectRevert(Assertions.NullAmount.selector);

    merkleDistributor.sweep(sweepReceiver);
  }
}

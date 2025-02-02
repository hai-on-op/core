// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {RewardDistributor} from '@contracts/tokens/RewardDistributor.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {MerkleTreeGenerator} from '@test/utils/MerkleTreeGenerator.sol';
import {IRewardDistributor} from '@interfaces/tokens/IRewardDistributor.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address secondUser = label('secondUser');
  address thirdUser = label('thirdUser');
  address rootSetter = label('rootSetter');
  address rescueReceiver = label('rescueReceiver');

  MerkleTreeGenerator merkleTreeGenerator;

  ERC20ForTest mockRewardToken;
  ERC20ForTest mockSecondRewardToken;

  RewardDistributor rewardDistributor;

  bytes32[] merkleTreeA;
  bytes32[] merkleTreeB;
  bytes32[] leavesA;
  bytes32[] leavesB;

  bytes32 merkleRootA;
  bytes32 merkleRootB;

  uint256 constant REWARD_AMOUNT_A = 1;
  uint256 constant REWARD_AMOUNT_B = 2;
  uint256 constant RESCUE_AMOUNT = 10;
  uint256 constant EPOCH_DURATION = 1 days;

  function setUp() public virtual {
    vm.startPrank(deployer);

    rewardDistributor = new RewardDistributor(EPOCH_DURATION, rootSetter);
    label(address(rewardDistributor), 'RewardDistributor');

    mockRewardToken = new ERC20ForTest();
    mockSecondRewardToken = new ERC20ForTest();

    rewardDistributor.addAuthorization(authorizedAccount);
    rewardDistributor.modifyParameters('rootSetter', abi.encode(rootSetter));

    mockRewardToken.mint(address(rewardDistributor), 100);
    mockSecondRewardToken.mint(address(rewardDistributor), 100);

    address[] memory users = new address[](3);

    users[0] = user;
    users[1] = secondUser;
    users[2] = thirdUser;

    for (uint256 i = 0; i < users.length; i++) {
      leavesA.push(keccak256(bytes.concat(keccak256(abi.encode(users[i], REWARD_AMOUNT_A)))));
      leavesB.push(keccak256(bytes.concat(keccak256(abi.encode(users[i], REWARD_AMOUNT_B)))));
    }

    merkleTreeGenerator = new MerkleTreeGenerator();

    merkleTreeA = merkleTreeGenerator.generateMerkleTree(leavesA);
    merkleTreeB = merkleTreeGenerator.generateMerkleTree(leavesB);

    merkleRootA = merkleTreeA[0];
    merkleRootB = merkleTreeB[0];

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
    vm.stopPrank();
  }

  modifier rootSetterModifier() {
    vm.startPrank(rootSetter);
    _;
    vm.stopPrank();
  }
}

contract Unit_RewardDistributor_Constructor is Base {
  function test_Set_EpochDuration() public {
    assertEq(rewardDistributor.epochDuration(), EPOCH_DURATION);
  }

  function test_Set_EpochCounter() public {
    assertEq(rewardDistributor.epochCounter(), 0);
  }

  function test_Set_RootSetter() public {
    assertEq(rewardDistributor.rootSetter(), rootSetter);
  }
}

contract Unit_RewardDistributor_UpdateMerkleRoots is Base {
  event RewardDistributorMerkleRootUpdated(address indexed _rewardToken, bytes32 _merkleRoot, uint256 _epochCounter);

  function test_UpdateMerkleRootsSingleToken() public rootSetterModifier {
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    vm.expectEmit(true, true, true, true);
    emit RewardDistributorMerkleRootUpdated(address(mockRewardToken), merkleRootA, 0);
    rewardDistributor.updateMerkleRoots(tokens, roots);
  }

  function test_UpdateMerkleRootsMultipleTokens() public rootSetterModifier {
    address[] memory tokens = new address[](2);
    tokens[0] = address(mockRewardToken);
    tokens[1] = address(mockSecondRewardToken);

    bytes32[] memory roots = new bytes32[](2);
    roots[0] = merkleRootA;
    roots[1] = merkleRootB;

    rewardDistributor.updateMerkleRoots(tokens, roots);
  }

  function test_Revert_UpdateMerkleRoots_NotRootSetter() public {
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    vm.expectRevert(IRewardDistributor.RewardDistributor_NotRootSetter.selector);
    rewardDistributor.updateMerkleRoots(tokens, roots);
  }

  function test_Revert_UpdateMerkleRoots_ArrayLengthsMustMatch() public rootSetterModifier {
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](2);
    roots[0] = merkleRootA;
    roots[1] = merkleRootB;

    vm.expectRevert(IRewardDistributor.RewardDistributor_ArrayLengthsMustMatch.selector);
    rewardDistributor.updateMerkleRoots(tokens, roots);
  }

  function test_Revert_UpdateMerkleRoots_InvalidTokenAddress() public rootSetterModifier {
    address[] memory tokens = new address[](1);
    tokens[0] = address(0);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    vm.expectRevert(IRewardDistributor.RewardDistributor_InvalidTokenAddress.selector);
    rewardDistributor.updateMerkleRoots(tokens, roots);
  }

  function test_Revert_UpdateMerkleRoots_TooSoonEpochNotElapsed() public rootSetterModifier {
    // Do initial update to set lastUpdatedTime
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    rewardDistributor.updateMerkleRoots(tokens, roots);

    // Try to update again before epoch duration has passed
    vm.warp(block.timestamp + EPOCH_DURATION - 1);

    vm.expectRevert(IRewardDistributor.RewardDistributor_TooSoonEpochNotElapsed.selector);
    rewardDistributor.updateMerkleRoots(tokens, roots);
  }
}

contract Unit_RewardDistributor_Claim is Base {
  event RewardDistributorRewardClaimed(address indexed _account, address indexed _rewardToken, uint256 _wad);

  function test_Claim() public rootSetterModifier {
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    rewardDistributor.updateMerkleRoots(tokens, roots);

    uint256 index = merkleTreeGenerator.getIndex(merkleTreeA, leavesA[0]);
    bytes32[] memory proof = merkleTreeGenerator.getProof(merkleTreeA, index);

    vm.stopPrank();
    vm.prank(user);

    vm.expectEmit(true, true, true, true);
    emit RewardDistributorRewardClaimed(user, address(mockRewardToken), REWARD_AMOUNT_A);
    rewardDistributor.claim(address(mockRewardToken), REWARD_AMOUNT_A, proof);
  }

  function test_Revert_Claim_AlreadyClaimed() public {
    // First set the merkle root as rootSetter
    vm.startPrank(rootSetter);
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    rewardDistributor.updateMerkleRoots(tokens, roots);
    vm.stopPrank();

    // Get proof for user
    uint256 index = merkleTreeGenerator.getIndex(merkleTreeA, leavesA[0]);
    bytes32[] memory proof = merkleTreeGenerator.getProof(merkleTreeA, index);

    // First claim as user
    vm.prank(user);
    rewardDistributor.claim(address(mockRewardToken), REWARD_AMOUNT_A, proof);

    // Try to claim again - should revert with AlreadyClaimed
    vm.prank(user);
    vm.expectRevert(IRewardDistributor.RewardDistributor_AlreadyClaimed.selector);
    rewardDistributor.claim(address(mockRewardToken), REWARD_AMOUNT_A, proof);
  }

  function test_Revert_Claim_InvalidMerkleProof() public rootSetterModifier {
    address[] memory tokens = new address[](1);
    tokens[0] = address(mockRewardToken);

    bytes32[] memory roots = new bytes32[](1);
    roots[0] = merkleRootA;

    rewardDistributor.updateMerkleRoots(tokens, roots);

    uint256 index = merkleTreeGenerator.getIndex(merkleTreeA, leavesA[1]);
    bytes32[] memory proof = merkleTreeGenerator.getProof(merkleTreeA, index);

    vm.stopPrank();

    vm.prank(user);
    vm.expectRevert(IRewardDistributor.RewardDistributor_InvalidMerkleProof.selector);
    rewardDistributor.claim(address(mockRewardToken), REWARD_AMOUNT_A, proof);
  }
}

contract Unit_RewardDistributor_EmergencyWithdrawal is Base {
  event RewardDistributorEmergencyWithdrawal(
    address indexed _rescueReceiver, address indexed _rewardToken, uint256 _wad
  );

  function test_EmergencyWithdrawal() public {
    address rescueReceiver = makeAddr('rescueReceiver');

    vm.expectEmit(true, true, true, true);
    emit RewardDistributorEmergencyWithdrawal(rescueReceiver, address(mockRewardToken), RESCUE_AMOUNT);
    vm.prank(authorizedAccount);
    rewardDistributor.emergencyWidthdraw(rescueReceiver, address(mockRewardToken), RESCUE_AMOUNT);
  }

  function test_Revert_EmergencyWithdrawal_NotAuthorized() public {
    address rescueReceiver = makeAddr('rescueReceiver');

    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardDistributor.emergencyWidthdraw(rescueReceiver, address(mockRewardToken), RESCUE_AMOUNT);
  }

  function test_Revert_EmergencyWithdrawal_InvalidTokenAddress() public {
    address rescueReceiver = makeAddr('rescueReceiver');

    vm.prank(authorizedAccount);
    vm.expectRevert(IRewardDistributor.RewardDistributor_InvalidTokenAddress.selector);
    rewardDistributor.emergencyWidthdraw(rescueReceiver, address(0), RESCUE_AMOUNT);
  }

  function test_Revert_EmergencyWithdrawal_InvalidAmount() public {
    address rescueReceiver = makeAddr('rescueReceiver');

    vm.prank(authorizedAccount);
    vm.expectRevert(IRewardDistributor.RewardDistributor_InvalidAmount.selector);
    rewardDistributor.emergencyWidthdraw(rescueReceiver, address(mockRewardToken), 0);
  }
}

contract Unit_RewardDistributor_Pause is Base {
  function test_Pause() public authorized {
    rewardDistributor.pause();
    assertTrue(rewardDistributor.paused());
  }

  function test_Revert_Pause_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardDistributor.pause();
  }

  function test_Revert_Pause_CannotClaim() public authorized {
    rewardDistributor.pause();

    vm.stopPrank();
    vm.prank(user);

    vm.expectRevert(Pausable.EnforcedPause.selector);
    rewardDistributor.claim(address(mockRewardToken), REWARD_AMOUNT_A, new bytes32[](0));
  }

  function test_Revert_Pause_CannotMultiClaim() public authorized {
    rewardDistributor.pause();

    vm.stopPrank();
    vm.prank(user);
    vm.expectRevert(Pausable.EnforcedPause.selector);
    rewardDistributor.multiClaim(new address[](1), new uint256[](1), new bytes32[][](1));
  }
}

contract Unit_RewardDistributor_Unpause is Base {
  function test_Unpause() public authorized {
    rewardDistributor.pause();
    rewardDistributor.unpause();
    assertFalse(rewardDistributor.paused());
  }

  function test_Revert_Unpause_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    rewardDistributor.unpause();
  }
}

contract Unit_RewardDistributor_ViewFunctions is Base {
  function test_ViewFunctions() public {
    assertEq(rewardDistributor.epochCounter(), 0);
    assertEq(rewardDistributor.epochDuration(), EPOCH_DURATION);
    assertEq(rewardDistributor.lastUpdatedTime(), 0);
    assertEq(rewardDistributor.rootSetter(), rootSetter);
    assertEq(rewardDistributor.merkleRoots(address(mockRewardToken)), bytes32(0));
    assertEq(rewardDistributor.isClaimed(merkleRootA, address(this)), false);
  }
}

contract Unit_RewardDistributor_MultiClaim is Base {
  function test_MultiClaim() public rootSetterModifier {
    address[] memory tokens = new address[](2);
    tokens[0] = address(mockRewardToken);
    tokens[1] = address(mockSecondRewardToken);

    bytes32[] memory roots = new bytes32[](2);
    roots[0] = merkleRootA;
    roots[1] = merkleRootB;

    rewardDistributor.updateMerkleRoots(tokens, roots);

    uint256 indexA = merkleTreeGenerator.getIndex(merkleTreeA, leavesA[0]);
    bytes32[] memory proofA = merkleTreeGenerator.getProof(merkleTreeA, indexA);

    uint256 indexB = merkleTreeGenerator.getIndex(merkleTreeB, leavesB[0]);
    bytes32[] memory proofB = merkleTreeGenerator.getProof(merkleTreeB, indexB);

    vm.stopPrank();

    vm.prank(user);

    uint256[] memory amounts = new uint256[](2);
    amounts[0] = REWARD_AMOUNT_A;
    amounts[1] = REWARD_AMOUNT_B;

    bytes32[][] memory proofs = new bytes32[][](2);
    proofs[0] = proofA;
    proofs[1] = proofB;

    rewardDistributor.multiClaim(tokens, amounts, proofs);
  }
}

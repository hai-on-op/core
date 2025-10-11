// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {VeNFTManager} from '@contracts/tokens/VeNFTManager.sol';
import {IVeNFTManager} from '@interfaces/tokens/IVeNFTManager.sol';

import {HaiTest} from '@test/utils/HaiTest.t.sol';

import {VotingEscrowForTest} from '@test/mocks/VotingEscrowForTest.sol';
import {VoterForTest} from '@test/mocks/VoterForTest.sol';
import {RewardsDistributorForTest} from '@test/mocks/RewardsDistributorForTest.sol';
import {RootVotingRewardsFactoryForTest} from '@test/mocks/RootVotingRewardsFactoryForTest.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';

import {IVoter} from '@interfaces/external/IVoter.sol';
import {IRewardsDistributor} from '@interfaces/external/IRewardsDistributor.sol';
import {IRootVotingRewardsFactory} from '@interfaces/external/IRootVotingRewardsFactory.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  address secondaryManager = label('secondaryManager');
  address tertiaryManager = label('tertiaryManager');

  address rootMessageBridge = label('rootMessageBridge');

  address superchainRecipient = label('superchainRecipient');

  address poolA = label('poolA');
  address poolB = label('poolB');
  address poolC = label('poolC');

  address bribeContractA = label('bribeContractA');
  address bribeContractB = label('bribeContractB');
  address bribeContractC = label('bribeContractC');

  address feeContractA = label('feeContractA');
  address feeContractB = label('feeContractB');
  address feeContractC = label('feeContractC');

  address tokenA = label('tokenA');
  address tokenB = label('tokenB');
  address tokenC = label('tokenC');

  // for user address
  uint256 tokenIdA;
  uint256 tokenIdB;
  uint256 tokenIdC;

  // for secondary manager
  uint256 tokenIdD;
  uint256 tokenIdE;
  uint256 tokenIdF;

  // for tertiary manager
  uint256 tokenIdG;
  uint256 tokenIdH;
  uint256 tokenIdI;

  // for manager contract
  uint256 tokenIdJ;
  uint256 tokenIdK;
  uint256 tokenIdL;

  VeNFTManager public veNFTManager;
  VotingEscrowForTest public veNFT;
  VoterForTest public voter;
  RewardsDistributorForTest public rewardsDistributor;
  RootVotingRewardsFactoryForTest public rootVotingRewardsFactory;

  ERC20ForTest public rewardTokenA;
  ERC20ForTest public rewardTokenB;
  ERC20ForTest public rewardTokenC;
  ERC20ForTest public rewardTokenD;

  function setUp() public {
    vm.startPrank(deployer);

    veNFT = new VotingEscrowForTest();

    voter = new VoterForTest();

    rewardsDistributor = new RewardsDistributorForTest();

    rootVotingRewardsFactory = new RootVotingRewardsFactoryForTest();

    veNFTManager = new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );

    rewardTokenA = new ERC20ForTest();
    rewardTokenB = new ERC20ForTest();
    rewardTokenC = new ERC20ForTest();
    rewardTokenD = new ERC20ForTest();

    // for user address
    tokenIdA = veNFT.mint(user);
    tokenIdB = veNFT.mint(user);
    tokenIdC = veNFT.mint(user);

    // for secondary manager
    tokenIdD = veNFT.mint(secondaryManager);
    tokenIdE = veNFT.mint(secondaryManager);
    tokenIdF = veNFT.mint(secondaryManager);

    // for tertiary manager
    tokenIdG = veNFT.mint(tertiaryManager);
    tokenIdH = veNFT.mint(tertiaryManager);
    tokenIdI = veNFT.mint(tertiaryManager);

    // for manager contract
    tokenIdJ = veNFT.mint(address(veNFTManager));
    tokenIdK = veNFT.mint(address(veNFTManager));
    tokenIdL = veNFT.mint(address(veNFTManager));

    // mint reward tokens to veNFTManager
    rewardTokenA.mint(address(veNFTManager), 100);
    rewardTokenB.mint(address(veNFTManager), 100);
    rewardTokenC.mint(address(veNFTManager), 100);

    veNFTManager.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_VeNFTManager_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_SecondaryManager() public happyPath {
    assertEq(veNFTManager.secondaryManager(), secondaryManager);
  }

  function test_Set_TertiaryManager() public happyPath {
    assertEq(veNFTManager.tertiaryManager(), tertiaryManager);
  }

  function test_Set_VeNFT() public happyPath {
    assertEq(address(veNFTManager.VE_NFT()), address(veNFT));
  }

  function test_Set_Voter() public happyPath {
    assertEq(address(veNFTManager.voter()), address(voter));
  }

  function test_Set_RootVotingRewardsFactory() public happyPath {
    assertEq(address(veNFTManager.rootVotingRewardsFactory()), address(rootVotingRewardsFactory));
  }

  function test_Set_RootMessageBridge() public happyPath {
    assertEq(veNFTManager.rootMessageBridge(), rootMessageBridge);
  }

  function test_Set_RewardsDistributor() public happyPath {
    assertEq(address(veNFTManager.rewardsDistributor()), address(rewardsDistributor));
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(authorizedAccount);

    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullSecondaryManager() public happyPath {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullSecondaryManager.selector);
    new VeNFTManager(
      address(0),
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullTertiaryManager() public happyPath {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullTertiaryManager.selector);
    new VeNFTManager(
      secondaryManager,
      address(0),
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullVeNFT() public happyPath {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullVeNFT.selector);
    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(0),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullVoter() public happyPath {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullVoter.selector);
    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(0),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullRootVotingRewardsFactory() public {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullRootVotingRewardsFactory.selector);
    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(0),
      rootMessageBridge,
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullRootMessageBridge() public {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullRootMessageBridge.selector);
    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      address(0),
      address(rewardsDistributor)
    );
  }

  function test_Revert_NullRewardsDistributor() public {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullRewardsDistributor.selector);
    new VeNFTManager(
      secondaryManager,
      tertiaryManager,
      address(veNFT),
      address(voter),
      address(rootVotingRewardsFactory),
      rootMessageBridge,
      address(0)
    );
  }
}

contract Unit_VeNFTManager_DepositVeNFTs is Base {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  event VeNFTManagerVeNFTDeposit(uint256 _tokenId);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  function test_Revert_NotSecondaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryManager.selector);

    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_Revert_EmptyTokenIds() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyTokenIds.selector);
    veNFTManager.depositVeNFTs(new uint256[](0));
  }

  function test_Revert_DuplicateTokenIds() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdD;
    tokenIds[1] = tokenIdD;
    tokenIds[2] = tokenIdE;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectRevert(IVeNFTManager.VeNFTManager_DuplicateTokenIds.selector);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_singleNFT_Call_TransferFrom() public isSecondary {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdD;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    bytes memory expectedCallData = abi.encodeWithSignature(
      'safeTransferFrom(address,address,uint256)', secondaryManager, address(veNFTManager), tokenIdD
    );
    vm.expectCall(address(veNFT), expectedCallData);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_MultipleNFTs_Call_TransferFrom() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);

    tokenIds[0] = tokenIdD;
    tokenIds[1] = tokenIdE;
    tokenIds[2] = tokenIdF;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    bytes memory expectedCallDataA = abi.encodeWithSignature(
      'safeTransferFrom(address,address,uint256)', secondaryManager, address(veNFTManager), tokenIdD
    );
    vm.expectCall(address(veNFT), expectedCallDataA);

    bytes memory expectedCallDataB = abi.encodeWithSignature(
      'safeTransferFrom(address,address,uint256)', secondaryManager, address(veNFTManager), tokenIdE
    );
    vm.expectCall(address(veNFT), expectedCallDataB);

    bytes memory expectedCallDataC = abi.encodeWithSignature(
      'safeTransferFrom(address,address,uint256)', secondaryManager, address(veNFTManager), tokenIdF
    );
    vm.expectCall(address(veNFT), expectedCallDataC);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_SingleNFT_Emit_Transfer_ERC721() public isSecondary {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdD;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(secondaryManager, address(veNFTManager), tokenIdD);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_MultipleNFTs_Emit_Transfer_ERC721() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdD;
    tokenIds[1] = tokenIdE;
    tokenIds[2] = tokenIdF;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(secondaryManager, address(veNFTManager), tokenIdD);
    vm.expectEmit(true, true, true, false);
    emit Transfer(secondaryManager, address(veNFTManager), tokenIdE);
    vm.expectEmit(true, true, true, false);
    emit Transfer(secondaryManager, address(veNFTManager), tokenIdF);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_SingleNFT_Emit_VeNFTManagerVeNFTDeposit() public isSecondary {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdD;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerVeNFTDeposit(tokenIdD);

    veNFTManager.depositVeNFTs(tokenIds);
  }

  function test_MultipleNFTs_Emit_VeNFTManagerVeNFTDeposit() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdD;
    tokenIds[1] = tokenIdE;
    tokenIds[2] = tokenIdF;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerVeNFTDeposit(tokenIdD);
    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerVeNFTDeposit(tokenIdE);
    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerVeNFTDeposit(tokenIdF);

    veNFTManager.depositVeNFTs(tokenIds);
  }
}

contract Unit_VeNFTManager_TransferVeNfts is Base {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  event VeNFTManagerVeNFTTransfer(address indexed _account, uint256 _tokenId);

  modifier isAuthorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  function test_Revert_NotAuthorized() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdJ;

    veNFT.setApprovalForAll(address(veNFTManager), true);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_Revert_NullReceiver() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdJ;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectRevert(IVeNFTManager.VeNFTManager_NullReceiver.selector);
    veNFTManager.transferVeNFTs(address(0), tokenIds);
  }

  function test_Revert_EmptyTokenIds() public isAuthorized {
    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyTokenIds.selector);
    veNFTManager.transferVeNFTs(user, new uint256[](0));
  }

  function test_Revert_DuplicateTokenIds() public isAuthorized {
    vm.expectRevert(IVeNFTManager.VeNFTManager_DuplicateTokenIds.selector);
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdJ;
    tokenIds[1] = tokenIdJ;
    tokenIds[2] = tokenIdK;
    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_SingleNFT_Call_TransferFrom() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdJ;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    bytes memory expectedCallData =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', address(veNFTManager), user, tokenIdJ);
    vm.expectCall(address(veNFT), expectedCallData);
    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Call_TransferFrom() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdJ;
    tokenIds[1] = tokenIdK;
    tokenIds[2] = tokenIdL;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    bytes memory expectedCallDataA =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', address(veNFTManager), user, tokenIdJ);
    vm.expectCall(address(veNFT), expectedCallDataA);

    bytes memory expectedCallDataB =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', address(veNFTManager), user, tokenIdK);
    vm.expectCall(address(veNFT), expectedCallDataB);

    bytes memory expectedCallDataC =
      abi.encodeWithSignature('safeTransferFrom(address,address,uint256)', address(veNFTManager), user, tokenIdL);
    vm.expectCall(address(veNFT), expectedCallDataC);

    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_SingleNFT_Emit_Transfer_ERC721() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdJ;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(veNFTManager), user, tokenIdJ);

    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_MultipleNFTs_Emit_Transfer_ERC721() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdJ;
    tokenIds[1] = tokenIdK;
    tokenIds[2] = tokenIdL;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(veNFTManager), user, tokenIdJ);
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(veNFTManager), user, tokenIdK);
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(veNFTManager), user, tokenIdL);

    veNFTManager.transferVeNFTs(user, tokenIds);
  }

  function test_SingleNFT_Emit_VeNFTManagerVeNFTTransfer() public isAuthorized {
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = tokenIdJ;

    veNFT.setApprovalForAll(address(veNFTManager), true);

    // 1) Expect the ERC721 Transfer emitted by veNFT
    vm.expectEmit(true, true, true, false, address(veNFT));
    emit Transfer(address(veNFTManager), user, tokenIdJ);

    // 2) Then expect the manager’s event
    vm.expectEmit(true, false, false, true, address(veNFTManager));
    emit VeNFTManagerVeNFTTransfer(user, tokenIdJ);

    veNFTManager.transferVeNFTs(user, tokenIds);
  }
}

contract Unit_VeNFTManager_Vote is Base {
  event VeNFTManagerVote(uint256 _tokenId, address[] _poolVote, uint256[] _weights);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  modifier isTertiary() {
    vm.startPrank(tertiaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    veNFTManager.vote(tokenIdB, new address[](0), new uint256[](0));
  }

  function test_Revert_NullTokenId() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullTokenId.selector);
    veNFTManager.vote(0, new address[](0), new uint256[](0));
  }

  function test_Revert_EmptyPoolVote() public isSecondary {
    address[] memory poolVote = new address[](0);

    uint256[] memory weights = new uint256[](1);
    weights[0] = 1;

    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyPoolVote.selector);
    veNFTManager.vote(tokenIdD, poolVote, weights);
  }

  function test_Revert_EmptyWeights() public isSecondary {
    address[] memory poolVote = new address[](1);
    poolVote[0] = poolA;

    uint256[] memory weights = new uint256[](0);

    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyWeights.selector);
    veNFTManager.vote(tokenIdD, poolVote, weights);
  }

  function test_Revert_UnequalLengths() public isSecondary {
    address[] memory poolVote = new address[](2);
    poolVote[0] = poolA;
    poolVote[1] = poolB;

    uint256[] memory weights = new uint256[](1);
    weights[0] = 1;

    vm.expectRevert(IVeNFTManager.VeNFTManager_UnequalLengths.selector);
    veNFTManager.vote(tokenIdD, poolVote, weights);
  }

  function test_Call_Vote() public isSecondary {
    address[] memory poolVote = new address[](2);
    poolVote[0] = poolA;
    poolVote[1] = poolB;

    uint256[] memory weights = new uint256[](2);
    weights[0] = 1;
    weights[1] = 1;

    vm.expectCall(address(voter), abi.encodeWithSelector(IVoter.vote.selector, tokenIdD, poolVote, weights));
    veNFTManager.vote(tokenIdD, poolVote, weights);
  }

  function test_Emit_VeNFTManagerVote() public isSecondary {
    address[] memory poolVote = new address[](2);
    poolVote[0] = poolA;
    poolVote[1] = poolB;

    uint256[] memory weights = new uint256[](2);
    weights[0] = 1;
    weights[1] = 1;

    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerVote(tokenIdD, poolVote, weights);

    veNFTManager.vote(tokenIdD, poolVote, weights);
  }
}

contract Unit_VeNFTManager_ClaimFees is Base {
  event VeNFTManagerFeeClaim(address[] _fees, address[][] _tokens, uint256 _tokenId);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    address[][] memory tokens = new address[][](3);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    veNFTManager.claimFees(fees, tokens, tokenIdD);
  }

  function test_Revert_NullTokenId() public isSecondary {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    address[][] memory tokens = new address[][](3);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_NullTokenId.selector);
    veNFTManager.claimFees(fees, tokens, 0);
  }

  function test_Revert_EmptyFees() public isSecondary {
    address[][] memory tokens = new address[][](3);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;
    tokens[1] = new address[](3);
    tokens[1][0] = tokenA;
    tokens[1][1] = tokenB;
    tokens[1][2] = tokenC;
    tokens[2] = new address[](3);
    tokens[2][0] = tokenA;
    tokens[2][1] = tokenB;
    tokens[2][2] = tokenC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyFees.selector);
    veNFTManager.claimFees(new address[](0), tokens, tokenIdD);
  }

  function test_Revert_EmptyTokens() public isSecondary {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyTokens.selector);
    veNFTManager.claimFees(fees, new address[][](0), tokenIdD);
  }

  function test_Revert_UnequalLengths() public isSecondary {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    address[][] memory tokens = new address[][](2);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;
    tokens[1] = new address[](3);
    tokens[1][0] = tokenA;
    tokens[1][1] = tokenB;
    tokens[1][2] = tokenC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_UnequalLengths.selector);
    veNFTManager.claimFees(fees, tokens, tokenIdD);
  }

  function test_Call_ClaimFees() public isSecondary {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    address[][] memory tokens = new address[][](3);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;
    tokens[1] = new address[](3);
    tokens[1][0] = tokenA;
    tokens[1][1] = tokenB;
    tokens[1][2] = tokenC;
    tokens[2] = new address[](3);
    tokens[2][0] = tokenA;
    tokens[2][1] = tokenB;
    tokens[2][2] = tokenC;

    vm.expectCall(address(voter), abi.encodeWithSelector(IVoter.claimFees.selector, fees, tokens, tokenIdD));
    veNFTManager.claimFees(fees, tokens, tokenIdD);
  }

  function test_Emit_VeNFTManagerFeeClaim() public isSecondary {
    address[] memory fees = new address[](3);
    fees[0] = feeContractA;
    fees[1] = feeContractB;
    fees[2] = feeContractC;

    address[][] memory tokens = new address[][](3);
    tokens[0] = new address[](3);
    tokens[0][0] = tokenA;
    tokens[0][1] = tokenB;
    tokens[0][2] = tokenC;
    tokens[1] = new address[](3);
    tokens[1][0] = tokenA;
    tokens[1][1] = tokenB;
    tokens[1][2] = tokenC;
    tokens[2] = new address[](3);
    tokens[2][0] = tokenA;
    tokens[2][1] = tokenB;
    tokens[2][2] = tokenC;

    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerFeeClaim(fees, tokens, tokenIdD);

    veNFTManager.claimFees(fees, tokens, tokenIdD);
  }
}

contract Unit_VeNFTManager_ClaimAndLockRebases is Base {
  event VeNFTManagerRebaseClaimAndLock(uint256 _tokenId);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  modifier isTertiary() {
    vm.startPrank(tertiaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    veNFTManager.claimAndLockRebases(tokenIds);
  }

  function test_Revert_EmptyTokenIds() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyTokenIds.selector);
    veNFTManager.claimAndLockRebases(new uint256[](0));
  }

  function test_Call_ClaimAndLockRebases() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    for (uint256 i; i < tokenIds.length; i++) {
      vm.expectCall(
        address(rewardsDistributor), abi.encodeWithSelector(IRewardsDistributor.claim.selector, tokenIds[i])
      );
    }
    veNFTManager.claimAndLockRebases(tokenIds);
  }

  function test_Emit_VeNFTManagerRebaseClaimAndLock() public isSecondary {
    uint256[] memory tokenIds = new uint256[](3);
    tokenIds[0] = tokenIdA;
    tokenIds[1] = tokenIdB;
    tokenIds[2] = tokenIdC;

    for (uint256 i; i < tokenIds.length; i++) {
      vm.expectEmit(true, true, true, false);
      emit VeNFTManagerRebaseClaimAndLock(tokenIds[i]);
    }

    veNFTManager.claimAndLockRebases(tokenIds);
  }
}

contract Unit_VeNFTManager_SetSuperchainRecipient is Base {
  event VeNFTManagerSuperchainRecipientSet(uint256 _chainId, address _recipient);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  modifier isTertiary() {
    vm.startPrank(tertiaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    veNFTManager.setSuperchainRecipient(1, address(0));
  }

  function test_Revert_NullChainId() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullChainId.selector);
    veNFTManager.setSuperchainRecipient(0, superchainRecipient);
  }

  function test_Revert_NullRecipient() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullRecipient.selector);
    veNFTManager.setSuperchainRecipient(1, address(0));
  }

  function test_Call_SetSuperchainRecipient() public isSecondary {
    vm.expectCall(
      address(rootVotingRewardsFactory),
      abi.encodeWithSelector(IRootVotingRewardsFactory.setRecipient.selector, 1, superchainRecipient)
    );
    veNFTManager.setSuperchainRecipient(1, superchainRecipient);
  }

  function test_Emit_VeNFTManagerSuperchainRecipientSet() public isSecondary {
    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerSuperchainRecipientSet(1, superchainRecipient);
    veNFTManager.setSuperchainRecipient(1, superchainRecipient);
  }
}

contract Unit_VeNFTManager_SetTertiary is Base {
  event VeNFTManagerTertiaryManagerSet(address indexed _account);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  function test_Revert_NotSecondaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryManager.selector);
    veNFTManager.setTertiary(tertiaryManager);
  }

  function test_Revert_NullTertiaryManager() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullTertiaryManager.selector);
    veNFTManager.setTertiary(address(0));
  }

  function test_Call_SetTertiary() public isSecondary {
    veNFTManager.setTertiary(tertiaryManager);

    assertEq(veNFTManager.tertiaryManager(), tertiaryManager);
  }

  function test_Emit_VeNFTManagerTertiaryManagerSet() public isSecondary {
    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerTertiaryManagerSet(tertiaryManager);
    veNFTManager.setTertiary(tertiaryManager);
  }
}

contract Unit_VeNFTManager_SetSecondary is Base {
  event VeNFTManagerSecondaryManagerSet(address indexed _account);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isAuthorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_NotAuthorized() public isUser {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    veNFTManager.setSecondary(secondaryManager);
  }

  function test_Revert_NullSecondaryManager() public isAuthorized {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullSecondaryManager.selector);
    veNFTManager.setSecondary(address(0));
  }

  function test_Call_SetSecondary() public isAuthorized {
    veNFTManager.setSecondary(secondaryManager);

    assertEq(veNFTManager.secondaryManager(), secondaryManager);
  }

  function test_Emit_VeNFTManagerSecondaryManagerSet() public isAuthorized {
    vm.expectEmit(true, true, true, false);
    emit VeNFTManagerSecondaryManagerSet(secondaryManager);
    veNFTManager.setSecondary(secondaryManager);
  }
}

contract Unit_VeNFTManager_ApproveSuperchainGasAllowance is Base {
  event VeNFTManagerSuperchainGasAllowanceApproved();

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  modifier isTertiary() {
    vm.startPrank(tertiaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    veNFTManager.approveSuperchainGasAllowance();
  }

  function test_Call_ApproveSuperchainGasAllowance() public isSecondary {
    address weth = veNFTManager.WETH();
    address rmb = veNFTManager.rootMessageBridge();
    uint256 amount = 10_000_000_000_000_000;

    vm.mockCall(
      weth,
      abi.encodeWithSelector(IERC20.approve.selector, rmb, amount),
      abi.encode(true) // make approve return true
    );

    vm.expectCall(weth, abi.encodeWithSelector(IERC20.approve.selector, rmb, amount));

    veNFTManager.approveSuperchainGasAllowance();
  }

  function test_Emit_VeNFTManagerSuperchainGasAllowanceApproved() public isSecondary {
    address weth = veNFTManager.WETH();
    address rmb = veNFTManager.rootMessageBridge();
    uint256 amount = 10_000_000_000_000_000;

    // Make approve() succeed on the predeploy
    vm.mockCall(weth, abi.encodeWithSelector(IERC20.approve.selector, rmb, amount), abi.encode(true));

    vm.expectEmit(false, false, false, true);
    emit VeNFTManagerSuperchainGasAllowanceApproved();

    veNFTManager.approveSuperchainGasAllowance();
  }
}

contract Unit_VeNFTManager_WithdrawVotingRewards is Base {
  event VeNFTManagerTokenWithdrawn(address indexed _account, address indexed _token, uint256 _balance);

  modifier isUser() {
    vm.startPrank(user);
    _;
  }

  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  modifier isTertiary() {
    vm.startPrank(tertiaryManager);
    _;
  }

  function test_Revert_NotSecondaryOrTertiaryManager() public isUser {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NotSecondaryOrTertiaryManager.selector);
    address[] memory tokens = new address[](1);
    tokens[0] = address(rewardTokenA);
    veNFTManager.withdrawVotingRewards(user, tokens);
  }

  function test_Revert_NullReceiver() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_NullReceiver.selector);
    address[] memory tokens = new address[](1);
    tokens[0] = address(rewardTokenA);
    veNFTManager.withdrawVotingRewards(address(0), tokens);
  }

  function test_Revert_EmptyTokens() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_EmptyTokens.selector);
    address[] memory tokens = new address[](0);
    veNFTManager.withdrawVotingRewards(user, tokens);
  }

  function test_Revert_TokenBalanceIsZero() public isSecondary {
    vm.expectRevert(IVeNFTManager.VeNFTManager_TokenBalanceIsZero.selector);
    address[] memory tokens = new address[](1);
    tokens[0] = address(rewardTokenD);
    veNFTManager.withdrawVotingRewards(user, tokens);
  }

  function test_Call_WithdrawVotingRewards() public isSecondary {
    address[] memory tokens = new address[](3);
    tokens[0] = address(rewardTokenA);
    tokens[1] = address(rewardTokenB);
    tokens[2] = address(rewardTokenC);

    for (uint256 i; i < tokens.length; i++) {
      vm.expectCall(address(tokens[i]), abi.encodeWithSelector(IERC20.transfer.selector, user, 100));
    }

    veNFTManager.withdrawVotingRewards(user, tokens);
  }

  function test_Emit_VeNFTManagerTokenWithdrawn() public isSecondary {
    address[] memory tokens = new address[](3);
    tokens[0] = address(rewardTokenA);
    tokens[1] = address(rewardTokenB);
    tokens[2] = address(rewardTokenC);

    for (uint256 i; i < tokens.length; i++) {
      vm.expectEmit(true, true, true, false);
      emit VeNFTManagerTokenWithdrawn(user, tokens[i], 100);
    }

    veNFTManager.withdrawVotingRewards(user, tokens);
  }
}

contract Unit_VeNFTManager_GetManagedTokenIds is Base {
  modifier isSecondary() {
    vm.startPrank(secondaryManager);
    _;
  }

  function test_Call_GetManagedTokenIds() public isSecondary {
    uint256[] memory ids = new uint256[](3);
    ids[0] = tokenIdD;
    ids[1] = tokenIdE;
    ids[2] = tokenIdF;

    veNFT.setApprovalForAll(address(veNFTManager), true);
    veNFTManager.depositVeNFTs(ids);

    uint256[] memory tokenIds = veNFTManager.getManagedTokenIds();
    assertEq(tokenIds.length, 3);
    assertEq(tokenIds[0], tokenIdD);
    assertEq(tokenIds[1], tokenIdE);
    assertEq(tokenIds[2], tokenIdF);
  }
}

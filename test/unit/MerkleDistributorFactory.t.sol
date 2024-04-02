// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  MerkleDistributorFactoryForTest, IMerkleDistributorFactory
} from '@test/mocks/MerkleDistributorFactoryForTest.sol';
import {MerkleDistributorChild} from '@contracts/factories/MerkleDistributorChild.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  // ERC20ForTest token = new ERC20ForTest();

  // bytes32 root =
  //     0x30e48fd8bee18a1728bfd9f536125c5a352b778d5b07a92de684b14cb7bb92ad; // Root generated with OZ js library
  // uint256 totalClaimable = 500_000;
  // uint256 claimPeriodStart = block.timestamp + 10 days;
  // uint256 claimPeriodEnd = block.timestamp + 20 days;

  MerkleDistributorFactoryForTest merkleDistributorFactory;

  MerkleDistributorChild merkleDistributorChild = MerkleDistributorChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'MerkleDistributorChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    merkleDistributorFactory = new MerkleDistributorFactoryForTest();
    label(address(merkleDistributorFactory), 'MerkleDistributorFactory');

    merkleDistributorFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_MerkleDistributorFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    merkleDistributorFactory = new MerkleDistributorFactoryForTest();
  }
}

contract Unit_MerkleDistributorFactory_DeployMerkleDistributor is Base {
  event DeployMerkleDistributor(
    address indexed _merkleDistributor,
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  );

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    merkleDistributorFactory.deployMerkleDistributor(
      address(_token), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }

  function test_Deploy_MerkleDistributorChild(
    address _token,
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    ERC20ForTest token = new ERC20ForTest();

    bytes32 root = 0x30e48fd8bee18a1728bfd9f536125c5a352b778d5b07a92de684b14cb7bb92ad; // Root generated with OZ js library
    uint256 totalClaimable = 500_000;
    uint256 claimPeriodStart = block.timestamp + 10 days;
    uint256 claimPeriodEnd = block.timestamp + 20 days;

    merkleDistributorFactory.deployMerkleDistributor(
      address(token), root, totalClaimable, claimPeriodStart, claimPeriodEnd
    );

    assertEq(address(merkleDistributorChild).code, type(MerkleDistributorChild).runtimeCode);

    assertEq(address(merkleDistributorChild.token()), address(token));
    assertEq(merkleDistributorChild.root(), root);
    assertEq(merkleDistributorChild.totalClaimable(), totalClaimable);
    assertEq(merkleDistributorChild.claimPeriodStart(), claimPeriodStart);
    assertEq(merkleDistributorChild.claimPeriodEnd(), claimPeriodEnd);
  }
}

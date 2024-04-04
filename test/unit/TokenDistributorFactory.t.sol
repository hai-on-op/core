// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {TokenDistributorFactory} from '@contracts/factories/TokenDistributorFactory.sol';
import {ITokenDistributorFactory} from '@interfaces/factories/ITokenDistributorFactory.sol';
import {TokenDistributorMinterChild} from '@contracts/factories/TokenDistributorMinterChild.sol';
import {TokenDistributorTransferChild} from '@contracts/factories/TokenDistributorTransferChild.sol';
import {ITokenDistributorMinter} from '@contracts/tokens/TokenDistributorMinter.sol';
import {ITokenDistributorTransfer} from '@contracts/tokens/TokenDistributorTransfer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  address mockToken = mockContract('Token');

  TokenDistributorFactory tokenDistributorFactory;
  TokenDistributorMinterChild tokenDistributorMinterChild = TokenDistributorMinterChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'TokenDistributorMinterChild')
  );
  TokenDistributorTransferChild tokenDistributorTransferChild = TokenDistributorTransferChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'TokenDistributorTransferChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    tokenDistributorFactory = new TokenDistributorFactory();
    label(address(tokenDistributorFactory), 'TokenDistributorFactory');

    tokenDistributorFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_TokenDistributorFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    tokenDistributorFactory = new TokenDistributorFactory();
  }
}

contract Unit_TokenDistributorFactory_DeployTokenDistributorMinter is Base {
  event DeployTokenDistributor(
    address indexed _tokenDistributor,
    ITokenDistributorFactory.TokenDistributorType _type,
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

    tokenDistributorFactory.deployTokenDistributorMinter(
      address(_token), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }

  function test_Deploy_TokenDistributorMinterChild(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);

    tokenDistributorFactory.deployTokenDistributorMinter(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );

    assertEq(address(tokenDistributorMinterChild).code, type(TokenDistributorMinterChild).runtimeCode);
    assertEq(address(tokenDistributorMinterChild.token()), address(mockToken));
    assertEq(tokenDistributorMinterChild.root(), _root);
    assertEq(tokenDistributorMinterChild.totalClaimable(), _totalClaimable);
    assertEq(tokenDistributorMinterChild.claimPeriodStart(), _claimPeriodStart);
    assertEq(tokenDistributorMinterChild.claimPeriodEnd(), _claimPeriodEnd);
  }

  function test_Emit_DeployTokenDistributor(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);
    vm.expectEmit();
    emit DeployTokenDistributor(
      address(tokenDistributorMinterChild),
      ITokenDistributorFactory.TokenDistributorType.MINTER,
      address(mockToken),
      _root,
      _totalClaimable,
      _claimPeriodStart,
      _claimPeriodEnd
    );

    tokenDistributorFactory.deployTokenDistributorMinter(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }

  function test_Return_TokenDistributorMinter(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);
    ITokenDistributorMinter tokenDistributorMinter = tokenDistributorFactory.deployTokenDistributorMinter(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
    assertEq(address(tokenDistributorMinter), address(tokenDistributorMinterChild));
  }
}

contract Unit_TokenDistributorFactory_DeployTokenDistributorTransfer is Base {
  event DeployTokenDistributor(
    address indexed _tokenDistributor,
    ITokenDistributorFactory.TokenDistributorType _type,
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

    tokenDistributorFactory.deployTokenDistributorTransfer(
      address(_token), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }

  function test_Deploy_TokenDistributorTransferChild(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);

    tokenDistributorFactory.deployTokenDistributorTransfer(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );

    assertEq(address(tokenDistributorTransferChild).code, type(TokenDistributorTransferChild).runtimeCode);
    assertEq(address(tokenDistributorTransferChild.token()), address(mockToken));
    assertEq(tokenDistributorTransferChild.root(), _root);
    assertEq(tokenDistributorTransferChild.totalClaimable(), _totalClaimable);
    assertEq(tokenDistributorTransferChild.claimPeriodStart(), _claimPeriodStart);
    assertEq(tokenDistributorTransferChild.claimPeriodEnd(), _claimPeriodEnd);
  }

  function test_Emit_DeployTokenDistributor(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);
    vm.expectEmit();
    emit DeployTokenDistributor(
      address(tokenDistributorTransferChild),
      ITokenDistributorFactory.TokenDistributorType.TRANSFER,
      address(mockToken),
      _root,
      _totalClaimable,
      _claimPeriodStart,
      _claimPeriodEnd
    );

    tokenDistributorFactory.deployTokenDistributorTransfer(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
  }

  function test_Return_TokenDistributorTransfer(
    bytes32 _root,
    uint256 _totalClaimable,
    uint256 _claimPeriodStart,
    uint256 _claimPeriodEnd
  ) public happyPath {
    vm.assume(_totalClaimable > 0 && _claimPeriodStart > block.timestamp && _claimPeriodEnd > _claimPeriodStart);
    ITokenDistributorTransfer tokenDistributorTransfer = tokenDistributorFactory.deployTokenDistributorTransfer(
      address(mockToken), _root, _totalClaimable, _claimPeriodStart, _claimPeriodEnd
    );
    assertEq(address(tokenDistributorTransfer), address(tokenDistributorTransferChild));
  }
}

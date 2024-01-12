// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  SystemCoin systemCoin;

  string name = 'HAI Index Token';
  string symbol = 'HAI';

  function setUp() public virtual {
    vm.startPrank(deployer);

    systemCoin = new SystemCoin(name, symbol);

    systemCoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockBalanceOf(address _account, uint256 _balance) internal {
    stdstore.target(address(systemCoin)).sig(IERC20.balanceOf.selector).with_key(_account).checked_write(_balance);
  }

  function _mockTotalSupply(uint256 _totalSupply) internal {
    stdstore.target(address(systemCoin)).sig(IERC20.totalSupply.selector).checked_write(_totalSupply);
  }
}

contract Unit_SystemCoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Set_Name(string memory _name) public happyPath {
    systemCoin = new SystemCoin(_name, symbol);

    assertEq(systemCoin.name(), _name);
  }

  function test_Set_Symbol(string memory _symbol) public happyPath {
    systemCoin = new SystemCoin(name, _symbol);

    assertEq(systemCoin.symbol(), _symbol);
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new SystemCoin(name, symbol);
  }
}

contract Unit_SystemCoin_Mint is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  modifier happyPath(address _dst, uint256 _wad) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_dst);
    _;
  }

  function _assumeHappyPath(address _dst) internal pure {
    vm.assume(_dst != address(0));
  }

  function test_Revert_Unauthorized(address _dst, uint256 _wad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    systemCoin.mint(_dst, _wad);
  }

  function test_Emit_Transfer(address _dst, uint256 _wad) public happyPath(_dst, _wad) {
    vm.expectEmit();
    emit Transfer(address(0), _dst, _wad);

    systemCoin.mint(_dst, _wad);
  }
}

contract Unit_SystemCoin_Burn is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  modifier happyPath(uint256 _wad) {
    vm.startPrank(user);

    _mockValues(_wad);
    _;
  }

  function _mockValues(uint256 _wad) internal {
    _mockBalanceOf(user, _wad);
    _mockTotalSupply(_wad);
  }

  function test_Emit_Transfer(uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Transfer(user, address(0), _wad);

    systemCoin.burn(_wad);
  }
}

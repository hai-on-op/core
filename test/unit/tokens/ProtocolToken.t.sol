// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ProtocolToken protocolToken;

  string name = 'Protocol Token';
  string symbol = 'KITE';

  function setUp() public virtual {
    vm.startPrank(deployer);

    protocolToken = new ProtocolToken(name, symbol);

    protocolToken.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockPaused(bool _paused) internal {
    stdstore.target(address(protocolToken)).sig(Pausable.paused.selector).checked_write(_paused);
  }
}

contract Unit_ProtocolToken_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Set_Name(string memory _name) public happyPath {
    protocolToken = new ProtocolToken(_name, symbol);

    assertEq(protocolToken.name(), _name);
  }

  function test_Set_Symbol(string memory _symbol) public happyPath {
    protocolToken = new ProtocolToken(name, _symbol);

    assertEq(protocolToken.symbol(), _symbol);
  }

  function test_Set_Paused() public happyPath {
    assertEq(protocolToken.paused(), true);
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new ProtocolToken(name, symbol);
  }
}

contract Unit_ProtocolToken_Mint is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  modifier happyPath(address _dst, uint256 _wad) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_dst, _wad);
    _;
  }

  function _assumeHappyPath(address _dst, uint256 _wad) internal pure {
    vm.assume(_dst != address(0));
    vm.assume(_wad <= type(uint208).max);
  }

  function test_Revert_Unauthorized(address _dst, uint256 _wad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    protocolToken.mint(_dst, _wad);
  }

  function test_Emit_Transfer(address _dst, uint256 _wad) public happyPath(_dst, _wad) {
    vm.expectEmit();
    emit Transfer(address(0), _dst, _wad);

    protocolToken.mint(_dst, _wad);
  }
}

contract Unit_ProtocolToken_Burn is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  modifier happyPath(uint256 _wad) {
    _assumeHappyPath(_wad);
    _mockPaused(false);

    vm.prank(authorizedAccount);
    protocolToken.mint(user, _wad);

    vm.startPrank(user);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(_wad <= type(uint208).max);
  }

  function test_Emit_Transfer(uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Transfer(user, address(0), _wad);

    protocolToken.burn(_wad);
  }
}

contract Unit_ProtocolToken_Unpause is Base {
  event Unpaused(address _account);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    protocolToken.unpause();
  }

  function test_Emit_Unpaused() public happyPath {
    vm.expectEmit();
    emit Unpaused(authorizedAccount);

    protocolToken.unpause();
  }
}

contract Unit_ProtocolToken_Clock is Base {
  function test_Return_Timestamp() public {
    assertEq(protocolToken.clock(), block.timestamp);
  }
}

contract Unit_ProtocolToken_CLOCK_MODE is Base {
  function test_Return_Mode() public {
    assertEq(protocolToken.CLOCK_MODE(), 'mode=timestamp');
  }
}

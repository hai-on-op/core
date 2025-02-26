// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';

import {Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

import {StakingToken, IStakingToken} from '@contracts/tokens/StakingToken.sol';
// import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
// import {StakingManagerForTest} from '@test/StakingManagerForTest.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address alice = label('alice');
  address bob = label('bob');

  StakingToken stakingToken;

  IStakingManager mockStakingManager = IStakingManager(mockContract('StakingManager'));
  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));

  string name = 'Staking Token';
  string symbol = 'stKITE';

  function setUp() public virtual {
    vm.startPrank(deployer);

    stakingToken = new StakingToken(name, symbol, address(mockProtocolToken));

    // Set up staking manager
    stakingToken.modifyParameters('stakingManager', abi.encode(address(mockStakingManager)));

    stakingToken.addAuthorization(authorizedAccount);

    mockStakingManager.addAuthorization(authorizedAccount);
    mockProtocolToken.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_StakingToken_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Set_Name(string memory _name) public happyPath {
    stakingToken = new StakingToken(_name, symbol, address(mockProtocolToken));

    assertEq(stakingToken.name(), _name);
  }

  function test_Set_Symbol(string memory _symbol) public happyPath {
    stakingToken = new StakingToken(name, _symbol, address(mockProtocolToken));

    assertEq(stakingToken.symbol(), _symbol);
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new StakingToken(name, symbol, address(mockProtocolToken));
  }
}

contract Unit_StakingToken_Mint is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event StakingTokenMint(address indexed _dst, uint256 _wad);

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

    stakingToken.mint(_dst, _wad);
  }

  function test_Emit_Events(address _dst, uint256 _wad) public happyPath(_dst, _wad) {
    vm.expectEmit();
    emit Transfer(address(0), _dst, _wad);

    vm.expectEmit();
    emit StakingTokenMint(_dst, _wad);

    stakingToken.mint(_dst, _wad);
  }
}

contract Unit_StakingToken_Burn is Base {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event StakingTokenBurn(address indexed _src, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    _assumeHappyPath(_wad);

    vm.prank(authorizedAccount);
    stakingToken.mint(user, _wad);

    vm.startPrank(user);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(_wad <= type(uint208).max);
  }

  function test_Emit_Events(uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Transfer(user, address(0), _wad);

    vm.expectEmit();
    emit StakingTokenBurn(user, _wad);

    stakingToken.burn(_wad);
  }
}

contract Unit_StakingToken_Clock is Base {
  function test_Return_Timestamp() public {
    assertEq(stakingToken.clock(), block.timestamp);
  }
}

contract Unit_StakingToken_CLOCK_MODE is Base {
  function test_Return_Mode() public {
    assertEq(stakingToken.CLOCK_MODE(), 'mode=timestamp');
  }
}

contract Unit_StakingToken_Update is Base {
  modifier happyPath(address _from, address _to, uint256 _value) {
    vm.startPrank(authorizedAccount);
    _assumeHappyPath(_from, _to, _value);
    _;
  }

  function _assumeHappyPath(address _from, address _to, uint256 _value) internal pure {
    vm.assume(_from != address(0));
    vm.assume(_to != address(0));
    vm.assume(_value > 0);
    vm.assume(_value <= 1_000_000e18); // Reasonable maximum value
  }

  function test_Revert_NullStakingManager(address _from, address _to, uint256 _value) public {
    _assumeHappyPath(_from, _to, _value);

    // Deploy a new token without setting the staking manager
    vm.startPrank(authorizedAccount);
    StakingToken newToken = new StakingToken(name, symbol, address(mockProtocolToken));
    vm.stopPrank();

    vm.prank(_from);
    vm.expectRevert(IStakingToken.StakingToken_NullStakingManager.selector);
    // Just try to transfer 0 tokens, which should still trigger _update
    newToken.transfer(_to, 0);
  }

  function test_Revert_TransfersDisabled(address _from, address _to, uint256 _amount) public {
    vm.assume(_from != address(0) && _to != address(0));
    vm.assume(_from != _to);
    _amount = bound(_amount, 0, 1_000_000 * 10 ** 18);

    // Set up staking manager
    vm.stopPrank();
    vm.startPrank(authorizedAccount);
    stakingToken.modifyParameters('stakingManager', abi.encode(address(mockStakingManager)));

    // Mint tokens to _from
    stakingToken.mint(_from, _amount);

    vm.expectRevert(IStakingToken.StakingToken_TransfersDisabled.selector);
    vm.stopPrank();
    vm.startPrank(_from);
    stakingToken.transfer(_to, _amount);
  }

  function test_Call_Checkpoint_OnMint(address _to, uint256 _value) public {
    vm.assume(_to != address(0));
    vm.assume(_value > 0);
    vm.assume(_value <= 1_000_000e18); // Reasonable maximum value

    vm.startPrank(authorizedAccount);

    // Set the staking manager
    stakingToken.modifyParameters('stakingManager', abi.encode(address(mockStakingManager)));

    // Mock and expect the checkpoint call
    vm.mockCall(
      address(mockStakingManager), abi.encodeCall(mockStakingManager.checkpoint, ([address(0), _to])), abi.encode()
    );

    vm.expectCall(address(mockStakingManager), abi.encodeCall(mockStakingManager.checkpoint, ([address(0), _to])));

    stakingToken.mint(_to, _value);
    vm.stopPrank();
  }

  function test_Call_Checkpoint_OnBurn(address _from, uint256 _value) public {
    vm.assume(_from != address(0));
    vm.assume(_value > 0);
    vm.assume(_value <= 1_000_000e18); // Reasonable maximum value

    vm.startPrank(authorizedAccount);

    // Set the staking manager
    stakingToken.modifyParameters('stakingManager', abi.encode(address(mockStakingManager)));

    // Mint tokens first so we can burn them
    stakingToken.mint(authorizedAccount, _value);

    // Mock and expect the checkpoint call
    vm.mockCall(
      address(mockStakingManager),
      abi.encodeCall(mockStakingManager.checkpoint, ([authorizedAccount, address(0)])),
      abi.encode()
    );

    vm.expectCall(
      address(mockStakingManager), abi.encodeCall(mockStakingManager.checkpoint, ([authorizedAccount, address(0)]))
    );

    stakingToken.burn(_value);
    vm.stopPrank();
  }
}

contract Unit_StakingManager_ModifyParameters is Base {
  function test_ModifyParameters_UpdateStakingManager() public {
    address newStakingManager = makeAddr('newStakingManager');

    // Mock that both addresses have code
    vm.mockCall(address(mockStakingManager), abi.encodeWithSignature('extcodesize(address)'), abi.encode(1));
    vm.mockCall(newStakingManager, abi.encodeWithSignature('extcodesize(address)'), abi.encode(1));

    vm.startPrank(authorizedAccount);
    stakingToken.modifyParameters('stakingManager', abi.encode(newStakingManager));
    vm.stopPrank();

    assertEq(address(stakingToken.stakingManager()), newStakingManager);
  }

  function test_ModifyParameters_EnableTransfers() public {
    vm.startPrank(authorizedAccount);

    // Enable transfers
    stakingToken.modifyParameters('transfersEnabled', abi.encode(true));

    // Mint some tokens to test transfer
    stakingToken.mint(alice, 100e18);

    // Stop being authorized account and become alice
    vm.stopPrank();
    vm.startPrank(alice);

    // Transfer should now work
    stakingToken.transfer(bob, 50e18);

    assertEq(stakingToken.balanceOf(alice), 50e18);
    assertEq(stakingToken.balanceOf(bob), 50e18);
  }
}

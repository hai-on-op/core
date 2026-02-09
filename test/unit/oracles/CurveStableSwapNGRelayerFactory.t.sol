// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CurveStableSwapNGRelayerFactory} from '@contracts/factories/CurveStableSwapNGRelayerFactory.sol';
import {CurveStableSwapNGRelayerChild} from '@contracts/factories/CurveStableSwapNGRelayerChild.sol';
import {ICurveStableSwapNG} from '@interfaces/external/ICurveStableSwapNG.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ICurveStableSwapNG mockPool = ICurveStableSwapNG(mockContract('CurveStableSwapNGPool'));
  IERC20Metadata mockBaseToken = IERC20Metadata(mockContract('BaseToken'));
  IERC20Metadata mockQuoteToken = IERC20Metadata(mockContract('QuoteToken'));

  CurveStableSwapNGRelayerFactory curveStableSwapNGRelayerFactory;
  CurveStableSwapNGRelayerChild curveStableSwapNGRelayerChild = CurveStableSwapNGRelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'CurveStableSwapNGRelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    curveStableSwapNGRelayerFactory = new CurveStableSwapNGRelayerFactory();
    label(address(curveStableSwapNGRelayerFactory), 'CurveStableSwapNGRelayerFactory');

    curveStableSwapNGRelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockCoins(uint256 _baseIndex, uint256 _quoteIndex) internal {
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.coins, (_baseIndex)), abi.encode(address(mockBaseToken)));
    vm.mockCall(address(mockPool), abi.encodeCall(mockPool.coins, (_quoteIndex)), abi.encode(address(mockQuoteToken)));
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.symbol, ()), abi.encode(_symbol));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.symbol, ()), abi.encode(_symbol));
  }

  function _mockDecimals() internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.decimals, ()), abi.encode(uint8(18)));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.decimals, ()), abi.encode(uint8(18)));
  }
}

contract Unit_CurveStableSwapNGRelayerFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new CurveStableSwapNGRelayerFactory();
  }
}

contract Unit_CurveStableSwapNGRelayerFactory_DeployCurveStableSwapNGRelayer is Base {
  event NewCurveStableSwapNGRelayer(
    address indexed _curveStableSwapNGRelayer, address _pool, uint256 _baseIndex, uint256 _quoteIndex
  );

  modifier happyPath(uint256 _baseIndex, uint256 _quoteIndex, string memory _symbol) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_baseIndex, _quoteIndex);
    _mockValues(_baseIndex, _quoteIndex, _symbol);
    _;
  }

  function _assumeHappyPath(uint256 _baseIndex, uint256 _quoteIndex) internal pure {
    vm.assume(_baseIndex < type(uint256).max);
    vm.assume(_quoteIndex < type(uint256).max);
    vm.assume(_baseIndex != _quoteIndex);
  }

  function _mockValues(uint256 _baseIndex, uint256 _quoteIndex, string memory _symbol) internal {
    _mockCoins(_baseIndex, _quoteIndex);
    _mockSymbol(_symbol);
    _mockDecimals();
  }

  function test_Revert_Unauthorized(uint256 _baseIndex, uint256 _quoteIndex) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    curveStableSwapNGRelayerFactory.deployCurveStableSwapNGRelayer(address(mockPool), _baseIndex, _quoteIndex);
  }

  function test_Deploy_CurveStableSwapNGRelayerChild(
    uint256 _baseIndex,
    uint256 _quoteIndex,
    string memory _symbol
  ) public happyPath(_baseIndex, _quoteIndex, _symbol) {
    curveStableSwapNGRelayerFactory.deployCurveStableSwapNGRelayer(address(mockPool), _baseIndex, _quoteIndex);

    assertEq(address(curveStableSwapNGRelayerChild).code, type(CurveStableSwapNGRelayerChild).runtimeCode);

    // params
    assertEq(address(curveStableSwapNGRelayerChild.pool()), address(mockPool));
    assertEq(curveStableSwapNGRelayerChild.baseIndex(), _baseIndex);
    assertEq(curveStableSwapNGRelayerChild.quoteIndex(), _quoteIndex);
    assertEq(curveStableSwapNGRelayerChild.baseToken(), address(mockBaseToken));
    assertEq(curveStableSwapNGRelayerChild.quoteToken(), address(mockQuoteToken));
  }

  function test_Set_CurveStableSwapNGRelayers(
    uint256 _baseIndex,
    uint256 _quoteIndex,
    string memory _symbol
  ) public happyPath(_baseIndex, _quoteIndex, _symbol) {
    curveStableSwapNGRelayerFactory.deployCurveStableSwapNGRelayer(address(mockPool), _baseIndex, _quoteIndex);

    assertEq(curveStableSwapNGRelayerFactory.curveStableSwapNGRelayersList()[0], address(curveStableSwapNGRelayerChild));
  }

  function test_Emit_NewCurveStableSwapNGRelayer(
    uint256 _baseIndex,
    uint256 _quoteIndex,
    string memory _symbol
  ) public happyPath(_baseIndex, _quoteIndex, _symbol) {
    vm.expectEmit();
    emit NewCurveStableSwapNGRelayer(
      address(curveStableSwapNGRelayerChild), address(mockPool), _baseIndex, _quoteIndex
    );

    curveStableSwapNGRelayerFactory.deployCurveStableSwapNGRelayer(address(mockPool), _baseIndex, _quoteIndex);
  }

  function test_Return_CurveStableSwapNGRelayer(
    uint256 _baseIndex,
    uint256 _quoteIndex,
    string memory _symbol
  ) public happyPath(_baseIndex, _quoteIndex, _symbol) {
    assertEq(
      address(
        curveStableSwapNGRelayerFactory.deployCurveStableSwapNGRelayer(address(mockPool), _baseIndex, _quoteIndex)
      ),
      address(curveStableSwapNGRelayerChild)
    );
  }
}

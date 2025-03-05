// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {YearnVeloVaultRelayerFactory} from '@contracts/factories/YearnVeloVaultRelayerFactory.sol';
import {YearnVeloVaultRelayerChild} from '@contracts/factories/YearnVeloVaultRelayerChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IYearnVault mockYearnVault = IYearnVault(mockContract('YearnVault'));
  IVeloPool mockVeloPool = IVeloPool(mockContract('VeloPool'));
  IPessimisticVeloLpOracle mockVeloLpOracle = IPessimisticVeloLpOracle(mockContract('PessimisticVeloLpOracle'));

  YearnVeloVaultRelayerFactory yearnVeloVaultRelayerFactory;
  YearnVeloVaultRelayerChild yearnVeloVaultRelayerChild = YearnVeloVaultRelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'YearnVeloVaultRelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    yearnVeloVaultRelayerFactory = new YearnVeloVaultRelayerFactory();
    label(address(yearnVeloVaultRelayerFactory), 'YearnVeloVaultRelayerFactory');

    yearnVeloVaultRelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockYearnVault), abi.encodeCall(mockYearnVault.symbol, ()), abi.encode(_symbol));
    vm.mockCall(address(mockVeloPool), abi.encodeCall(mockVeloPool.symbol, ()), abi.encode(_symbol));
  }
}

contract Unit_YearnVeloVaultRelayerFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new YearnVeloVaultRelayerFactory();
  }
}

contract Unit_YearnVeloVaultRelayerFactory_DeployYearnVeloVaultRelayer is Base {
  event NewYearnVeloVaultRelayer(
    address indexed _yearnVeloVaultRelayer, address _yearnVault, address _veloPool, address _veloLpOracle
  );

  modifier happyPath(string memory _symbol) {
    vm.startPrank(authorizedAccount);

    _mockValues(_symbol);
    _;
  }

  function _mockValues(string memory _symbol) internal {
    _mockSymbol(_symbol);
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    yearnVeloVaultRelayerFactory.deployYearnVeloVaultRelayer(mockYearnVault, mockVeloPool, mockVeloLpOracle);
  }

  function test_Deploy_YearnVeloVaultRelayerChild(string memory _symbol) public happyPath(_symbol) {
    yearnVeloVaultRelayerFactory.deployYearnVeloVaultRelayer(mockYearnVault, mockVeloPool, mockVeloLpOracle);

    assertEq(address(yearnVeloVaultRelayerChild).code, type(YearnVeloVaultRelayerChild).runtimeCode);

    // params
    assertEq(address(yearnVeloVaultRelayerChild.yearnVault()), address(mockYearnVault));
    assertEq(address(yearnVeloVaultRelayerChild.veloPool()), address(mockVeloPool));
    assertEq(address(yearnVeloVaultRelayerChild.veloLpOracle()), address(mockVeloLpOracle));
  }

  function test_Set_YearnVeloVaultRelayers(string memory _symbol) public happyPath(_symbol) {
    yearnVeloVaultRelayerFactory.deployYearnVeloVaultRelayer(mockYearnVault, mockVeloPool, mockVeloLpOracle);

    assertEq(yearnVeloVaultRelayerFactory.yearnVeloVaultRelayersList()[0], address(yearnVeloVaultRelayerChild));
  }

  function test_Emit_NewYearnVeloVaultRelayer(string memory _symbol) public happyPath(_symbol) {
    vm.expectEmit();
    emit NewYearnVeloVaultRelayer(
      address(yearnVeloVaultRelayerChild), address(mockYearnVault), address(mockVeloPool), address(mockVeloLpOracle)
    );

    yearnVeloVaultRelayerFactory.deployYearnVeloVaultRelayer(mockYearnVault, mockVeloPool, mockVeloLpOracle);
  }

  function test_Return_YearnVeloVaultRelayer(string memory _symbol) public happyPath(_symbol) {
    assertEq(
      address(yearnVeloVaultRelayerFactory.deployYearnVeloVaultRelayer(mockYearnVault, mockVeloPool, mockVeloLpOracle)),
      address(yearnVeloVaultRelayerChild)
    );
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {BeefyVeloVaultRelayerFactory} from '@contracts/factories/BeefyVeloVaultRelayerFactory.sol';
import {BeefyVeloVaultRelayerChild} from '@contracts/factories/BeefyVeloVaultRelayerChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IBeefyVaultV7 mockBeefyVault = IBeefyVaultV7(mockContract('BeefyVault'));
  IVeloPool mockVeloPool = IVeloPool(mockContract('VeloPool'));
  IPessimisticVeloLpOracle mockVeloLpOracle = IPessimisticVeloLpOracle(mockContract('PessimisticVeloLpOracle'));

  BeefyVeloVaultRelayerFactory beefyVeloVaultRelayerFactory;
  BeefyVeloVaultRelayerChild beefyVeloVaultRelayerChild = BeefyVeloVaultRelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'BeefyVeloVaultRelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    beefyVeloVaultRelayerFactory = new BeefyVeloVaultRelayerFactory();
    label(address(beefyVeloVaultRelayerFactory), 'BeefyVeloVaultRelayerFactory');

    beefyVeloVaultRelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockBeefyVault), abi.encodeCall(mockBeefyVault.symbol, ()), abi.encode(_symbol));
    vm.mockCall(address(mockVeloPool), abi.encodeCall(mockVeloPool.symbol, ()), abi.encode(_symbol));
  }
}

contract Unit_BeefyVeloVaultRelayerFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new BeefyVeloVaultRelayerFactory();
  }
}

contract Unit_BeefyVeloVaultRelayerFactory_DeployBeefyVeloVaultRelayer is Base {
  event NewBeefyVeloVaultRelayer(
    address indexed _beefyVeloVaultRelayer, address _beefyVault, address _veloPool, address _veloLpOracle
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

    beefyVeloVaultRelayerFactory.deployBeefyVeloVaultRelayer(mockBeefyVault, mockVeloPool, mockVeloLpOracle);
  }

  function test_Deploy_BeefyVeloVaultRelayerChild(string memory _symbol) public happyPath(_symbol) {
    beefyVeloVaultRelayerFactory.deployBeefyVeloVaultRelayer(mockBeefyVault, mockVeloPool, mockVeloLpOracle);

    assertEq(address(beefyVeloVaultRelayerChild).code, type(BeefyVeloVaultRelayerChild).runtimeCode);

    // params
    assertEq(address(beefyVeloVaultRelayerChild.beefyVault()), address(mockBeefyVault));
    assertEq(address(beefyVeloVaultRelayerChild.veloPool()), address(mockVeloPool));
    assertEq(address(beefyVeloVaultRelayerChild.veloLpOracle()), address(mockVeloLpOracle));
  }

  function test_Set_BeefyVeloVaultRelayers(string memory _symbol) public happyPath(_symbol) {
    beefyVeloVaultRelayerFactory.deployBeefyVeloVaultRelayer(mockBeefyVault, mockVeloPool, mockVeloLpOracle);

    assertEq(beefyVeloVaultRelayerFactory.beefyVeloVaultRelayersList()[0], address(beefyVeloVaultRelayerChild));
  }

  function test_Emit_NewBeefyVeloVaultRelayer(string memory _symbol) public happyPath(_symbol) {
    vm.expectEmit();
    emit NewBeefyVeloVaultRelayer(
      address(beefyVeloVaultRelayerChild), address(mockBeefyVault), address(mockVeloPool), address(mockVeloLpOracle)
    );

    beefyVeloVaultRelayerFactory.deployBeefyVeloVaultRelayer(mockBeefyVault, mockVeloPool, mockVeloLpOracle);
  }

  function test_Return_BeefyVeloVaultRelayer(string memory _symbol) public happyPath(_symbol) {
    assertEq(
      address(beefyVeloVaultRelayerFactory.deployBeefyVeloVaultRelayer(mockBeefyVault, mockVeloPool, mockVeloLpOracle)),
      address(beefyVeloVaultRelayerChild)
    );
  }
}

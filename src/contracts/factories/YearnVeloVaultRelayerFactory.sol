// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IYearnVeloVaultRelayerFactory} from '@interfaces/factories/IYearnVeloVaultRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

import {YearnVeloVaultRelayerChild} from '@contracts/factories/YearnVeloVaultRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  YearnVeloVaultRelayerFactory
 * @notice This contract is used to deploy YearnVeloVaultRelayer contracts
 * @dev    The deployed contracts are YearnVeloVaultRelayerChild instances
 */
contract YearnVeloVaultRelayerFactory is Authorizable, IYearnVeloVaultRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed YearnVeloVaultRelayer contracts
  EnumerableSet.AddressSet internal _yearnVeloVaultRelayers;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IYearnVeloVaultRelayerFactory
  function deployYearnVeloVaultRelayer(
    IYearnVault _yearnVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) external isAuthorized returns (IBaseOracle _yearnVeloVaultRelayer) {
    _yearnVeloVaultRelayer = new YearnVeloVaultRelayerChild(_yearnVault, _veloPool, _veloLpOracle);
    _yearnVeloVaultRelayers.add(address(_yearnVeloVaultRelayer));
    emit NewYearnVeloVaultRelayer(
      address(_yearnVeloVaultRelayer), address(_yearnVault), address(_veloPool), address(_veloLpOracle)
    );
  }

  // --- Views ---

  /// @inheritdoc IYearnVeloVaultRelayerFactory
  function yearnVeloVaultRelayersList() external view returns (address[] memory _yearnVeloVaultRelayersList) {
    return _yearnVeloVaultRelayers.values();
  }
}

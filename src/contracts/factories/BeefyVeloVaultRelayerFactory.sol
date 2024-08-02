// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBeefyVeloVaultRelayerFactory} from '@interfaces/factories/IBeefyVeloVaultRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';

import {BeefyVeloVaultRelayerChild} from '@contracts/factories/BeefyVeloVaultRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  BeefyVeloVaultRelayerFactory
 * @notice This contract is used to deploy BeefyVeloVaultRelayer contracts
 * @dev    The deployed contracts are BeefyVeloVaultRelayerChild instances
 */
contract BeefyVeloVaultRelayerFactory is Authorizable, IBeefyVeloVaultRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed BeefyVeloVaultRelayer contracts
  EnumerableSet.AddressSet internal _beefyVeloVaultRelayers;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IBeefyVeloVaultRelayerFactory
  function deployBeefyVeloVaultRelayer(
    IBaseOracle _token0priceSource,
    IBaseOracle _token1priceSource,
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool
  ) external isAuthorized returns (IBaseOracle _beefyVeloVaultRelayer) {
    _beefyVeloVaultRelayer =
      new BeefyVeloVaultRelayerChild(_token0priceSource, _token1priceSource, _beefyVault, _veloPool);
    _beefyVeloVaultRelayers.add(address(_beefyVeloVaultRelayer));
    emit NewBeefyVeloVaultRelayer(
      address(_beefyVeloVaultRelayer),
      address(_token0priceSource),
      address(_token1priceSource),
      address(_beefyVault),
      address(_veloPool)
    );
  }

  // --- Views ---

  /// @inheritdoc IBeefyVeloVaultRelayerFactory
  function beefyVeloVaultRelayersList() external view returns (address[] memory _beefyVeloVaultRelayersList) {
    return _beefyVeloVaultRelayers.values();
  }
}

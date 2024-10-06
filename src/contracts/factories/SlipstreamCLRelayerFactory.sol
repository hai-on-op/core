// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IUniV3RelayerFactory} from '@interfaces/factories/IUniV3RelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {SlipstreamCLRelayerChild} from '@contracts/factories/SlipstreamCLRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  UniV3RelayerFactory
 * @notice This contract is used to deploy UniV3Relayer contracts
 * @dev    The deployed contracts are UniV3RelayerChild instances
 */
contract SlipstreamCLRelayerFactory is Authorizable, IUniV3RelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice Address of the UniswapV3Factory used to fetch the pool address
  // solhint-disable-next-line var-name-mixedcase
  address internal immutable _UNI_V3_FACTORY;

  /// @notice The enumerable set of deployed SlipstreamCLRelayer contracts
  EnumerableSet.AddressSet internal _uniV3Relayers;

  // --- Init ---

  constructor(address _uniV3Factory) Authorizable(msg.sender) {
    _UNI_V3_FACTORY = _uniV3Factory;
  }

  // --- Methods ---

  /// @inheritdoc IUniV3RelayerFactory
  function deployUniV3Relayer(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) external isAuthorized returns (IBaseOracle _uniV3Relayer) {
    _uniV3Relayer = new SlipstreamCLRelayerChild(_UNI_V3_FACTORY, _baseToken, _quoteToken, _feeTier, _quotePeriod);
    _uniV3Relayers.add(address(_uniV3Relayer));
    emit NewUniV3Relayer(address(_uniV3Relayer), _baseToken, _quoteToken, _feeTier, _quotePeriod);
  }

  // --- Views ---

  /// @inheritdoc IUniV3RelayerFactory
  function uniV3RelayersList() external view returns (address[] memory _uniV3RelayersList) {
    return _uniV3Relayers.values();
  }
}

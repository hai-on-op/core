// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICurveStableSwapNGRelayerFactory} from '@interfaces/factories/ICurveStableSwapNGRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {CurveStableSwapNGRelayerChild} from '@contracts/factories/CurveStableSwapNGRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  CurveStableSwapNGRelayerFactory
 * @notice This contract is used to deploy CurveStableSwapNGRelayer contracts
 * @dev    The deployed contracts are CurveStableSwapNGRelayerChild instances
 */
contract CurveStableSwapNGRelayerFactory is Authorizable, ICurveStableSwapNGRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed CurveStableSwapNGRelayer contracts
  EnumerableSet.AddressSet internal _curveStableSwapNGRelayers;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc ICurveStableSwapNGRelayerFactory
  function deployCurveStableSwapNGRelayer(
    address _pool,
    uint256 _baseIndex,
    uint256 _quoteIndex,
    bool _inverted
  ) external isAuthorized returns (IBaseOracle _curveStableSwapNGRelayer) {
    _curveStableSwapNGRelayer = new CurveStableSwapNGRelayerChild(_pool, _baseIndex, _quoteIndex, _inverted);
    _curveStableSwapNGRelayers.add(address(_curveStableSwapNGRelayer));
    emit NewCurveStableSwapNGRelayer(address(_curveStableSwapNGRelayer), _pool, _baseIndex, _quoteIndex, _inverted);
  }

  // --- Views ---

  /// @inheritdoc ICurveStableSwapNGRelayerFactory
  function curveStableSwapNGRelayersList() external view returns (address[] memory _curveStableSwapNGRelayersList) {
    return _curveStableSwapNGRelayers.values();
  }
}

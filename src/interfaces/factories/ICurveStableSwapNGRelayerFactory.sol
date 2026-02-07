// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ICurveStableSwapNGRelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new CurveStableSwapNGRelayer contract is deployed
   * @param _curveStableSwapNGRelayer Address of the deployed CurveStableSwapNGRelayer contract
   * @param _pool Address of the CurveStableSwapNG pool
   * @param _oracleIndex Index used for Curve's price_oracle(i) (prices coin i+1 vs coin0)
   * @param _inverted Whether to invert the oracle output (quote/base instead of base/quote)
   */
  event NewCurveStableSwapNGRelayer(
    address indexed _curveStableSwapNGRelayer, address _pool, uint256 _oracleIndex, bool _inverted
  );

  // --- Methods ---

  /**
   * @notice Deploys a new CurveStableSwapNGRelayer contract
   * @param _pool Address of the CurveStableSwapNG pool
   * @param _oracleIndex Index used for Curve's price_oracle(i) (prices coin i+1 vs coin0)
   * @param _inverted Whether to invert the oracle output (quote/base instead of base/quote)
   * @return _curveStableSwapNGRelayer Address of the deployed CurveStableSwapNGRelayer contract
   */
  function deployCurveStableSwapNGRelayer(
    address _pool,
    uint256 _oracleIndex,
    bool _inverted
  ) external returns (IBaseOracle _curveStableSwapNGRelayer);

  // --- Views ---

  /**
   * @notice Getter for the list of CurveStableSwapNGRelayer contracts
   * @return _curveStableSwapNGRelayersList List of CurveStableSwapNGRelayer contracts
   */
  function curveStableSwapNGRelayersList() external view returns (address[] memory _curveStableSwapNGRelayersList);
}

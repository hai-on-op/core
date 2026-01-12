// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title ISwapStrategy
 * @notice Interface for swap strategies that convert collateral to HAI
 */
interface ISwapStrategy {
  /**
   * @notice Estimates the amount of HAI that would be received from swapping collateral
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _collateralAmount Amount of collateral to swap [wad]
   * @return _estimatedHai Estimated amount of HAI that would be received [wad]
   */
  function estimateSwapToHai(bytes32 _collateralType, uint256 _collateralAmount) external view returns (uint256 _estimatedHai);

  /**
   * @notice Swaps collateral to HAI
   * @param  _collateralType Bytes32 representation of the collateral type
   * @param  _collateralAmount Amount of collateral to swap [wad]
   * @return _haiReceived Amount of HAI received [wad]
   */
  function swapToHai(bytes32 _collateralType, uint256 _collateralAmount) external returns (uint256 _haiReceived);

  /**
   * @notice Checks if this strategy can handle a specific collateral type
   * @param  _collateralType Bytes32 representation of the collateral type
   * @return _canHandle True if this strategy can handle the collateral type
   */
  function canHandle(bytes32 _collateralType) external view returns (bool _canHandle);
}


// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title IStrategyStep
 * @notice Stateless step primitive used by StabilityPool liquidation strategy pipelines
 */
interface IStrategyStep {
  /// @notice Step family identifier used for fallback slippage config
  function stepType() external pure returns (bytes32 _stepType);

  /// @notice Input token consumed by this step
  function inputToken(bytes calldata _data) external pure returns (address _inputToken);

  /// @notice Output tokens emitted by this step (order must match preview/execute outputs)
  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens);

  /// @notice Preview outputs for amountIn
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut);

  /// @notice Execute step and return actual outputs for amountIn
  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut);
}

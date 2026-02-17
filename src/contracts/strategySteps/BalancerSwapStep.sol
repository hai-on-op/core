// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IBalancerVault} from '@interfaces/external/IStrategyStepExternal.sol';

contract BalancerSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  struct Data {
    address vault;
    bytes32 poolId;
    address tokenIn;
    address tokenOut;
  }

  bytes32 internal constant _STEP_TYPE = bytes32('BALANCER_SWAP');

  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.tokenIn;
  }

  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.tokenOut;
  }

  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    IBalancerVault.BatchSwapStep[] memory _swaps = new IBalancerVault.BatchSwapStep[](1);
    _swaps[0] = IBalancerVault.BatchSwapStep({
      poolId: _decoded.poolId,
      assetInIndex: 0,
      assetOutIndex: 1,
      amount: _amountIn,
      userData: bytes('')
    });

    address[] memory _assets = new address[](2);
    _assets[0] = _decoded.tokenIn;
    _assets[1] = _decoded.tokenOut;

    IBalancerVault.FundManagement memory _funds = IBalancerVault.FundManagement({
      sender: address(this),
      fromInternalBalance: false,
      recipient: payable(address(this)),
      toInternalBalance: false
    });

    int256[] memory _deltas =
      IBalancerVault(_decoded.vault).queryBatchSwap(IBalancerVault.SwapKind.GIVEN_IN, _swaps, _assets, _funds);
    _amountsOut[0] = uint256(-_deltas[1]);
  }

  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    IERC20(_decoded.tokenIn).forceApprove(_decoded.vault, _amountIn);
    uint256 _minOut = _minOuts.length > 0 ? _minOuts[0] : 0;

    IBalancerVault.SingleSwap memory _singleSwap = IBalancerVault.SingleSwap({
      poolId: _decoded.poolId,
      kind: IBalancerVault.SwapKind.GIVEN_IN,
      assetIn: _decoded.tokenIn,
      assetOut: _decoded.tokenOut,
      amount: _amountIn,
      userData: bytes('')
    });

    IBalancerVault.FundManagement memory _funds = IBalancerVault.FundManagement({
      sender: address(this),
      fromInternalBalance: false,
      recipient: payable(address(this)),
      toInternalBalance: false
    });

    _amountsOut[0] = IBalancerVault(_decoded.vault).swap(_singleSwap, _funds, _minOut, block.timestamp);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IVeloCLRouter} from '@interfaces/external/IStrategyStepExternal.sol';

interface IVeloCLQuoter {
  function quoteExactInputSingle(
    address _tokenIn,
    address _tokenOut,
    int24 _tickSpacing,
    uint256 _amountIn,
    uint160 _sqrtPriceLimitX96
  ) external returns (uint256 _amountOut);
}

contract VeloCLSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  struct Data {
    address quoter;
    address router;
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    uint160 sqrtPriceLimitX96;
    uint256 deadlineBuffer;
  }

  bytes32 internal constant _STEP_TYPE = bytes32('VELO_CL_SWAP');

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

    (bool _ok, bytes memory _ret) = _decoded.quoter.staticcall(
      abi.encodeWithSelector(
        IVeloCLQuoter.quoteExactInputSingle.selector,
        _decoded.tokenIn,
        _decoded.tokenOut,
        _decoded.tickSpacing,
        _amountIn,
        _decoded.sqrtPriceLimitX96
      )
    );
    if (!_ok || _ret.length < 32) revert();
    _amountsOut[0] = abi.decode(_ret, (uint256));
  }

  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    IERC20(_decoded.tokenIn).forceApprove(_decoded.router, _amountIn);
    uint256 _minOut = _minOuts.length > 0 ? _minOuts[0] : 0;
    IVeloCLRouter.ExactInputSingleParams memory _params = IVeloCLRouter.ExactInputSingleParams({
      tokenIn: _decoded.tokenIn,
      tokenOut: _decoded.tokenOut,
      tickSpacing: _decoded.tickSpacing,
      recipient: address(this),
      deadline: block.timestamp + _decoded.deadlineBuffer,
      amountIn: _amountIn,
      amountOutMinimum: _minOut,
      sqrtPriceLimitX96: _decoded.sqrtPriceLimitX96
    });
    _amountsOut[0] = IVeloCLRouter(_decoded.router).exactInputSingle(_params);
  }
}

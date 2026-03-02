// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';

contract MockConfigurableStrategyStepForTest is IStrategyStep {
  struct Data {
    address tokenIn;
    address tokenOut;
    uint256 previewMultiplierWad;
    uint256 executeMultiplierWad;
  }

  constructor(bytes32) {}

  function stepType() external pure returns (bytes32 __stepType) {
    return bytes32('STEP');
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

  function preview(bytes calldata _data, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    _amountsOut[0] = (_amountIn * _decoded.previewMultiplierWad) / 1e18;
  }

  function execute(bytes calldata _data, uint256 _amountIn, uint256[] calldata)
    external
    returns (uint256[] memory _amountsOut)
  {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    _amountsOut[0] = (_amountIn * _decoded.executeMultiplierWad) / 1e18;
    if (_amountsOut[0] > 0) {
      ERC20ForTest(_decoded.tokenOut).mint(address(this), _amountsOut[0]);
    }
  }
}

contract MockPreviewLengthMismatchStepForTest is IStrategyStep {
  struct Data {
    address tokenIn;
    address tokenOut;
  }

  function stepType() external pure returns (bytes32 _stepType) {
    return bytes32('MISMATCH_PREVIEW');
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

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](2);
    _amountsOut[0] = _amountIn;
    _amountsOut[1] = _amountIn;
  }

  function execute(bytes calldata _data, uint256 _amountIn, uint256[] calldata)
    external
    returns (uint256[] memory _amountsOut)
  {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
    ERC20ForTest(_decoded.tokenOut).mint(address(this), _amountIn);
  }
}

contract MockExecuteLengthMismatchStepForTest is IStrategyStep {
  struct Data {
    address tokenIn;
    address tokenOut;
  }

  function stepType() external pure returns (bytes32 _stepType) {
    return bytes32('MISMATCH_EXECUTE');
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

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }

  function execute(bytes calldata _data, uint256 _amountIn, uint256[] calldata)
    external
    returns (uint256[] memory _amountsOut)
  {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](2);
    _amountsOut[0] = _amountIn;
    _amountsOut[1] = 1;
    ERC20ForTest(_decoded.tokenOut).mint(address(this), _amountIn);
  }
}

contract MockRevertNoReasonStepForTest is IStrategyStep {
  struct Data {
    address tokenIn;
    address tokenOut;
  }

  function stepType() external pure returns (bytes32 _stepType) {
    return bytes32('REVERT_NO_REASON');
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

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }

  function execute(bytes calldata, uint256, uint256[] calldata) external pure returns (uint256[] memory) {
    assembly {
      revert(0, 0)
    }
  }
}

contract MockRevertReasonStepForTest is IStrategyStep {
  error MockRevertReasonStepForTest_Reverted();

  struct Data {
    address tokenIn;
    address tokenOut;
  }

  function stepType() external pure returns (bytes32 _stepType) {
    return bytes32('REVERT_WITH_REASON');
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

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }

  function execute(bytes calldata, uint256, uint256[] calldata) external pure returns (uint256[] memory) {
    revert MockRevertReasonStepForTest_Reverted();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';

contract MockStabilityPoolEmissionsControllerForTest {
  error MockStabilityPoolEmissionsControllerForTest_OnlyReceiver();

  ERC20ForTest public kite;
  address public stabilityRewardsReceiver;
  uint256 public amountToClaim;

  constructor(ERC20ForTest _kite, address _stabilityRewardsReceiver) {
    kite = _kite;
    stabilityRewardsReceiver = _stabilityRewardsReceiver;
  }

  function claimRewardsForStabilityPool() external returns (uint256 _amount) {
    if (msg.sender != stabilityRewardsReceiver) {
      revert MockStabilityPoolEmissionsControllerForTest_OnlyReceiver();
    }
    _amount = amountToClaim;
    amountToClaim = 0;
    if (_amount > 0) {
      kite.transfer(msg.sender, _amount);
    }
  }

  function setStabilityRewardsReceiver(address _receiver) external {
    stabilityRewardsReceiver = _receiver;
  }

  function setAmountToClaim(uint256 _amount) external {
    amountToClaim = _amount;
  }
}

contract MockStabilityPoolStrategyStepForTest is IStrategyStep {
  bytes32 internal constant _STEP_TYPE = bytes32('MOCK');

  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    (_inputToken,) = abi.decode(_data, (address, address));
  }

  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    (, address _output) = abi.decode(_data, (address, address));
    _outputTokens = new address[](1);
    _outputTokens[0] = _output;
  }

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }

  function execute(bytes calldata, uint256 _amountIn, uint256[] calldata)
    external
    pure
    returns (uint256[] memory _amountsOut)
  {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }
}

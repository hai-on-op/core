// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';

contract MockCollateralJoinFactoryForTest {
  mapping(bytes32 => address) public collateralJoins;

  function setCollateralJoin(bytes32 _cType, address _join) external {
    collateralJoins[_cType] = _join;
  }
}

contract MockCollateralAuctionHouseFactoryForTest {
  mapping(bytes32 => address) public collateralAuctionHouses;

  function setCollateralAuctionHouse(bytes32 _cType, address _auctionHouse) external {
    collateralAuctionHouses[_cType] = _auctionHouse;
  }
}

contract MockCollateralJoinForTest {
  ERC20ForTest public collateralToken;
  uint256 public multiplier;
  uint256 public lastExitAmount;

  constructor(ERC20ForTest _collateralToken, uint256 _multiplier) {
    collateralToken = _collateralToken;
    multiplier = _multiplier;
  }

  function collateral() external view returns (ERC20ForTest _collateral) {
    return collateralToken;
  }

  function exit(address _account, uint256 _wei) external {
    lastExitAmount = _wei;
    collateralToken.mint(_account, _wei);
  }
}

contract MockSingleOutputMultiplierStepForTest is IStrategyStep {
  bytes32 internal constant _STEP_TYPE = bytes32('MOCK');

  struct Data {
    address tokenIn;
    address tokenOut;
    uint256 outputMultiplierWad;
  }

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

  function preview(bytes calldata _data, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    _amountsOut[0] = (_amountIn * _decoded.outputMultiplierWad) / 1e18;
  }

  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata
  ) external pure returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    _amountsOut[0] = (_amountIn * _decoded.outputMultiplierWad) / 1e18;
  }
}

contract MockAuctionHouseForTest {
  bytes32 public collateralType;

  constructor(bytes32 _collateralType) {
    collateralType = _collateralType;
  }
}

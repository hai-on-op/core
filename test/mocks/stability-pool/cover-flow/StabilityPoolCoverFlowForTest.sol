// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {RAY} from '@libraries/Math.sol';

contract MockSAFEEngineForTest {
  error MockSAFEEngineForTest_NotSAFEAllowed();

  mapping(address => uint256) public coinBalances;
  mapping(address => uint256) public approveCalls;
  mapping(address => mapping(address => bool)) public safeRights;

  function coinBalance(address _account) external view returns (uint256 _balance) {
    return coinBalances[_account];
  }

  function setCoinBalance(address _account, uint256 _rad) external {
    coinBalances[_account] = _rad;
  }

  function increaseCoinBalance(address _account, uint256 _rad) external {
    coinBalances[_account] += _rad;
  }

  function decreaseCoinBalance(address _account, uint256 _rad) external {
    coinBalances[_account] -= _rad;
  }

  function approveSAFEModification(address _account) external {
    safeRights[msg.sender][_account] = true;
    approveCalls[_account] += 1;
  }

  function transferInternalCoins(address _source, address _destination, uint256 _rad) external {
    if (_source != msg.sender && !safeRights[_source][msg.sender]) revert MockSAFEEngineForTest_NotSAFEAllowed();
    coinBalances[_source] -= _rad;
    coinBalances[_destination] += _rad;
  }
}

contract MockCoinJoinForTest {
  MockSAFEEngineForTest public engine;
  ERC20ForTest public systemCoinToken;

  uint256 public joinCalls;
  uint256 public exitCalls;
  uint256 public lastJoinWad;
  uint256 public lastExitWad;

  constructor(MockSAFEEngineForTest _engine, ERC20ForTest _systemCoinToken) {
    engine = _engine;
    systemCoinToken = _systemCoinToken;
  }

  function safeEngine() external view returns (MockSAFEEngineForTest _safeEngine) {
    return engine;
  }

  function join(address _account, uint256 _wad) external {
    joinCalls += 1;
    lastJoinWad = _wad;
    systemCoinToken.transferFrom(msg.sender, address(this), _wad);
    engine.increaseCoinBalance(_account, _wad * RAY);
  }

  function exit(address _account, uint256 _wad) external {
    exitCalls += 1;
    lastExitWad = _wad;
    engine.transferInternalCoins(msg.sender, address(this), _wad * RAY);
    systemCoinToken.mint(_account, _wad);
  }
}

contract MockCoverAuctionHouseForTest {
  bytes32 internal cType;
  MockSAFEEngineForTest internal safeEngine;

  uint256 internal estimatedCollateralBought;
  uint256 internal estimatedAdjustedBid;
  uint256 internal actualCollateralBought;
  uint256 internal actualAdjustedBid;

  constructor(bytes32 _cType, MockSAFEEngineForTest _safeEngine) {
    cType = _cType;
    safeEngine = _safeEngine;
  }

  function collateralType() external view returns (bytes32 _collateralType) {
    return cType;
  }

  function setQuote(
    uint256 _estimatedCollateralBought,
    uint256 _estimatedAdjustedBid,
    uint256 _actualCollateralBought,
    uint256 _actualAdjustedBid
  ) external {
    estimatedCollateralBought = _estimatedCollateralBought;
    estimatedAdjustedBid = _estimatedAdjustedBid;
    actualCollateralBought = _actualCollateralBought;
    actualAdjustedBid = _actualAdjustedBid;
  }

  function getCollateralBought(
    uint256,
    uint256
  ) external view returns (uint256 _collateralBought, uint256 _adjustedBid) {
    return (estimatedCollateralBought, estimatedAdjustedBid);
  }

  function auctions(uint256) external view returns (ICollateralAuctionHouse.Auction memory _auction) {
    uint256 _maxAdjustedBid = estimatedAdjustedBid > actualAdjustedBid ? estimatedAdjustedBid : actualAdjustedBid;
    uint256 _amountToSell =
      estimatedCollateralBought > actualCollateralBought ? estimatedCollateralBought : actualCollateralBought;
    uint256 _amountToRaise = _maxAdjustedBid == 0 ? 0 : (_maxAdjustedBid * RAY) - 1;

    return ICollateralAuctionHouse.Auction({
      amountToSell: _amountToSell,
      amountToRaise: _amountToRaise,
      initialTimestamp: block.timestamp,
      forgoneCollateralReceiver: address(0),
      auctionIncomeRecipient: address(0)
    });
  }

  function buyCollateral(uint256, uint256) external returns (uint256 _collateralBought, uint256 _adjustedBid) {
    if (actualAdjustedBid > 0) {
      safeEngine.decreaseCoinBalance(msg.sender, actualAdjustedBid * RAY);
    }
    return (actualCollateralBought, actualAdjustedBid);
  }
}

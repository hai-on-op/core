// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/*
  Coded for Let's get HAI and the Money God with 🥕 by
                 .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/
*/

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract ExpensesAuctioneer is Authorizable, Modifiable, Disableable {
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  bytes32 public constant C_TYPE = bytes32('KITE');

  ISAFEEngine public immutable safeEngine;

  ICollateralJoin public protocolJoin;
  IOracleRelayer public oracleRelayer;
  ICollateralAuctionHouse public collateralAuctionHouse;

  mapping(uint256 _auctionId => uint256 _expectedRaise) public expectedRaise;

  struct ExpensesAuctioneerParams {
    address recipient;
    uint256 /* WAD */ usdAmountPerAuction;
    uint256 /* WAD */ expensesPerYear;
    uint256 /* WAD */ sellBuffer;
    uint256 /* seconds */ cooldownPeriod;
    uint256 /* seconds */ auctionDuration;
  }

  ExpensesAuctioneerParams public _params;

  function params() external view returns (ExpensesAuctioneerParams memory) {
    return _params;
  }

  uint256 public constant ONE_YEAR = 365 days;

  // --- Init ---

  constructor(
    address _safeEngine,
    address _protocolJoin,
    address _oracleRelayer,
    ExpensesAuctioneerParams memory __params
  ) Authorizable(msg.sender) validParams updateExpenses {
    safeEngine = ISAFEEngine(_safeEngine);
    _setProtocolJoin(_protocolJoin);
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    _params = __params;
    // NOTE: not initializing collateralAuctionHouse as it needs to be deployed after this contract
  }

  error AuctionIsStillActive();
  error AuctioneerIsInCooldown();
  error NotEnoughDebt();
  error NotEnoughKite();
  error InvalidCAH();

  event RaisedUSDAmount(uint256 amount);
  event CancelledRaisedUSDAmount(uint256 amount);

  uint256 internal _lastMarketPrice;
  uint256 internal _accumulatedExpenses;
  uint256 internal _processedExpenses;
  uint256 internal _lastUpdate;
  uint256 internal _lastAuction;

  function accumulatedExpenses() external view returns (uint256) {
    return _accumulatedExpenses;
  }

  function processedExpenses() external view returns (uint256) {
    return _processedExpenses;
  }

  function outstandingDebt() public view returns (uint256) {
    if (_processedExpenses >= _accumulatedExpenses) return 0;
    return _accumulatedExpenses - _processedExpenses;
  }

  function pokeExpenses() external updateExpenses {}

  modifier updateExpenses() {
    // accumulated debt + time since last update * debt rate
    uint256 _timestamp = block.timestamp;
    _accumulatedExpenses += (_params.expensesPerYear * (_timestamp - _lastUpdate) / ONE_YEAR);
    _lastUpdate = _timestamp;
    _;
  }

  function extraordinaryExpense(uint256 _amount) external isAuthorized updateExpenses {
    _accumulatedExpenses += _amount;
  }

  function cancelExpense(uint256 _amount) external isAuthorized updateExpenses {
    _accumulatedExpenses -= _amount;
  }

  function joinKiteBalance() public {
    IERC20 protocolToken = ICollateralJoin(protocolJoin).collateral();
    uint256 _balance = protocolToken.balanceOf(address(this));
    if (_balance == 0) return;
    ICollateralJoin(protocolJoin).join(address(this), _balance);
  }

  function exitKiteBalance(address _to) external whenDisabled isAuthorized {
    uint256 _kiteBalance = safeEngine.tokenCollateral(C_TYPE, address(this));
    ICollateralJoin(protocolJoin).exit(_to, _kiteBalance);
  }

  /// @notice Starts an auction of KITE for HAI, with a USD amount
  /// @dev    Checks that time has passed, and that theres enough outstanding debt
  function auctionExpenses() external updateExpenses whenEnabled returns (uint256 _auctionId) {
    // ensure balance is higher than `USD amount to auction`
    if (outstandingDebt() < _params.usdAmountPerAuction) revert NotEnoughDebt();
    // ensure time has passed since last auction
    if (block.timestamp - _lastAuction < _params.cooldownPeriod) revert AuctioneerIsInCooldown();
    // query OracleRelayer for KITE/USD price
    uint256 _kiteUsdPrice = oracleRelayer.cParams(C_TYPE).oracle.read();
    // query SAFEEngine for redemption price / OracleRelayer for HAI/USD price
    uint256 _haiUsdPrice = oracleRelayer.redemptionPrice();
    // calculate how much HAI is needed (mkt/redemption price) to cover debt
    uint256 _amountToRaise = (_params.usdAmountPerAuction * 1e9).rdiv(_haiUsdPrice);
    // calculate how mich KITE is needed + 10% buffer
    uint256 _amountToSell = _params.usdAmountPerAuction.wdiv(_kiteUsdPrice);
    // ensure KITE is available
    joinKiteBalance();
    if (safeEngine.tokenCollateral(C_TYPE, address(this)) < _amountToSell) revert NotEnoughKite();
    // start auction
    _auctionId = collateralAuctionHouse.startAuction({
      _forgoneCollateralReceiver: address(this),
      _auctionIncomeRecipient: _params.recipient,
      _amountToRaise: _amountToRaise * WAD, // convert RAY to RAD
      _collateralToSell: _amountToSell.wmul(_params.sellBuffer)
    });
    // register last auction timestamp
    _lastAuction = block.timestamp;
  }

  function terminateAuction(uint256 _auctionId) external updateExpenses {
    // check auction state
    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(_auctionId);
    // check time has passed since auction started
    if (block.timestamp < _auction.initialTimestamp + _params.auctionDuration) revert AuctionIsStillActive();
    // call terminateAuctionPrematurely
    // NOTE: it calls removeCoinsFromAuction(_auction.amountToRaise) so we need to cancel it
    collateralAuctionHouse.terminateAuctionPrematurely(_auctionId);
    // calculate how much USD that was trying to cover (_lastMarketPrice is updated in removeCoinsFromAuction)
    uint256 _remainingToRaiseUSDAmount = (_auction.amountToRaise / RAY).wmul(_lastMarketPrice);
    // substract the amount to cancel the effect from removeCoinsFromAuction
    _processedExpenses -= _remainingToRaiseUSDAmount;
    emit CancelledRaisedUSDAmount(_remainingToRaiseUSDAmount);
  }

  /// @notice This function get's called by the CAH when a bid is placed
  /// @dev    May also be called by an authorized address to register OTC arrangements
  function removeCoinsFromAuction(uint256 _coinAmount) external isAuthorized updateExpenses {
    // query SAFEEngine for redemption price
    _lastMarketPrice = oracleRelayer.marketPrice();
    // calculate how much USD that covers
    uint256 _raisedUSDAmount = (_coinAmount / RAY).wmul(_lastMarketPrice);
    // substract the amount of USD from the outstanding debt
    _processedExpenses += _raisedUSDAmount;
    emit RaisedUSDAmount(_raisedUSDAmount);
  }

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();

    if (_param == 'protocolJoin') protocolJoin = ICollateralJoin(_address);
    else if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'collateralAuctionHouse') _setCollateralAuctionHouse(_address);
    else if (_param == 'recipient') _params.recipient = _address;
    else if (_param == 'usdAmountPerAuction') _params.usdAmountPerAuction = _data.toUint256();
    else if (_param == 'expensesPerYear') _params.expensesPerYear = _data.toUint256();
    else if (_param == 'sellBuffer') _params.sellBuffer = _data.toUint256();
    else if (_param == 'cooldownPeriod') _params.cooldownPeriod = _data.toUint256();
    else if (_param == 'auctionDuration') _params.auctionDuration = _data.toUint256();
    else revert UnrecognizedParam();
  }

  function _setCollateralAuctionHouse(address _address) internal {
    _address.assertHasCode();

    if (address(collateralAuctionHouse) != address(0)) {
      _removeAuthorization(address(collateralAuctionHouse));
      safeEngine.denySAFEModification(address(collateralAuctionHouse));
    }

    collateralAuctionHouse = ICollateralAuctionHouse(_address);
    if (collateralAuctionHouse.collateralType() != C_TYPE) revert InvalidCAH();
    _addAuthorization(_address);
    safeEngine.approveSAFEModification(_address);
  }

  function _setProtocolJoin(address _address) internal {
    _address.assertHasCode();
    IERC20 protocolToken;
    if (address(protocolJoin) != address(0)) {
      protocolToken = protocolJoin.collateral();
      protocolToken.approve(address(protocolJoin), 0);
    }

    protocolToken = ICollateralJoin(_address).collateral();
    protocolToken.approve(_address, type(uint256).max);
    protocolJoin = ICollateralJoin(_address);
  }

  function _validateParameters() internal view override {
    address(oracleRelayer).assertHasCode();
    _params.recipient.assertNonNull();
  }
}

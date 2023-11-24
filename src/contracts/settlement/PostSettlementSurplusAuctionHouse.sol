// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  IPostSettlementSurplusAuctionHouse,
  ICommonSurplusAuctionHouse
} from '@interfaces/settlement/IPostSettlementSurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  PostSettlementSurplusAuctionHouse
 * @notice This contract enables the sell of system coins in exchange for protocol tokens after Global Settlement is triggered
 * @dev    The reason to auction the post settlement surplus is to avoid incentives to trigger Global Settlement if the system has a surplus
 */
contract PostSettlementSurplusAuctionHouse is Authorizable, Modifiable, IPostSettlementSurplusAuctionHouse {
  using Encoding for bytes;
  using SafeERC20 for IProtocolToken;
  using Assertions for address;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');

  // --- Data ---

  /// @inheritdoc ICommonSurplusAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 => Auction) public _auctions;

  /// @inheritdoc ICommonSurplusAuctionHouse
  function auctions(uint256 _id) external view returns (Auction memory _auction) {
    return _auctions[_id];
  }

  /// @inheritdoc ICommonSurplusAuctionHouse
  uint256 public auctionsStarted;

  // --- Registry ---

  /// @inheritdoc ICommonSurplusAuctionHouse
  ISAFEEngine public safeEngine;
  /// @inheritdoc ICommonSurplusAuctionHouse
  IProtocolToken public protocolToken;

  // --- Params ---

  /// @inheritdoc IPostSettlementSurplusAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  PostSettlementSAHParams public _params;

  /// @inheritdoc IPostSettlementSurplusAuctionHouse
  function params() external view returns (PostSettlementSAHParams memory _pssahParams) {
    return _params;
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _protocolToken Address of the ProtocolToken contract
   * @param  _pssahParams Initial valid PostSettlementSAH parameters struct
   */
  constructor(
    address _safeEngine,
    address _protocolToken,
    PostSettlementSAHParams memory _pssahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    protocolToken = IProtocolToken(_protocolToken);

    _params = _pssahParams;
  }

  // --- Auction ---

  /// @inheritdoc ICommonSurplusAuctionHouse
  function startAuction(uint256 _amountToSell, uint256 _initialBid) external isAuthorized returns (uint256 _id) {
    _id = ++auctionsStarted;

    _auctions[_id] = Auction({
      bidAmount: _initialBid,
      amountToSell: _amountToSell,
      highBidder: msg.sender,
      bidExpiry: 0,
      auctionDeadline: block.timestamp + _params.totalAuctionLength
    });

    safeEngine.transferInternalCoins(msg.sender, address(this), _amountToSell);

    emit StartAuction({
      _id: _id,
      _auctioneer: msg.sender,
      _blockTimestamp: block.timestamp,
      _amountToSell: _amountToSell,
      _amountToRaise: _initialBid,
      _auctionDeadline: _auctions[_id].auctionDeadline
    });
  }

  /// @inheritdoc ICommonSurplusAuctionHouse
  function restartAuction(uint256 _id) external {
    if (_id == 0 || _id > auctionsStarted) revert SAH_AuctionNeverStarted();
    Auction storage _auction = _auctions[_id];
    if (_auction.auctionDeadline > block.timestamp) revert SAH_AuctionNotFinished();
    if (_auction.bidExpiry != 0) revert SAH_BidAlreadyPlaced();
    _auction.auctionDeadline = block.timestamp + _params.totalAuctionLength;
    emit RestartAuction(_id, block.timestamp, _auction.auctionDeadline);
  }

  /// @inheritdoc ICommonSurplusAuctionHouse
  function increaseBidSize(uint256 _id, uint256 _bid) external {
    Auction storage _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert SAH_HighBidderNotSet();
    if (_auction.bidExpiry <= block.timestamp && _auction.bidExpiry != 0) revert SAH_BidAlreadyExpired();
    if (_auction.auctionDeadline <= block.timestamp) revert SAH_AuctionAlreadyExpired();
    if (_bid <= _auction.bidAmount) revert SAH_BidNotHigher();
    if (_bid * WAD < _params.bidIncrease * _auction.bidAmount) revert SAH_InsufficientIncrease();

    // The amount that will be transferred to the auction house
    uint256 _deltaBidAmount = _bid;

    // Check if this is the first bid or not
    if (_auction.bidExpiry != 0) {
      // Since this is not the first bid, it might be that we need to repay the previous bidder
      if (msg.sender != _auction.highBidder) {
        protocolToken.safeTransferFrom(msg.sender, _auction.highBidder, _auction.bidAmount);

        _auction.highBidder = msg.sender;
      }
      // Either we just repaid the previous bidder,
      // or this user is also the previous bidder and is incrementing his bid
      _deltaBidAmount -= _auction.bidAmount;
    } else {
      // This is the first bid
      _auction.highBidder = msg.sender;
    }

    _auction.bidAmount = _bid;
    _auction.bidExpiry = block.timestamp + _params.bidDuration;

    protocolToken.safeTransferFrom(msg.sender, address(this), _deltaBidAmount);

    emit IncreaseBidSize({
      _id: _id,
      _bidder: msg.sender,
      _blockTimestamp: block.timestamp,
      _raisedAmount: _bid,
      _soldAmount: _auction.amountToSell,
      _bidExpiry: _auction.bidExpiry
    });
  }

  /// @inheritdoc ICommonSurplusAuctionHouse
  function settleAuction(uint256 _id) external {
    Auction memory _auction = _auctions[_id];
    if (_auction.bidExpiry == 0 || (_auction.bidExpiry > block.timestamp && _auction.auctionDeadline > block.timestamp))
    {
      revert SAH_AuctionNotFinished();
    }

    safeEngine.transferInternalCoins(address(this), _auction.highBidder, _auction.amountToSell);
    protocolToken.burn(_auction.bidAmount);

    emit SettleAuction(_id, block.timestamp, _auction.highBidder, _auction.bidAmount);
    delete _auctions[_id];
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'protocolToken') protocolToken = IProtocolToken(_address);
    else if (_param == 'bidIncrease') _params.bidIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = _uint256;
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(protocolToken).assertHasCode();
  }
}

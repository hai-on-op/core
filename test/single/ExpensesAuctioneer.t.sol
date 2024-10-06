// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';
import {ICollateralAuctionHouse, CollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {ExpensesAuctioneer} from '@contracts/governance/ExpensesAuctioneer.sol';
import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';

import {CoinForTest} from '@test/mocks/CoinForTest.sol';
import {DisableableForTest} from '@test/mocks/DisableableForTest.sol';
import {IOracleRelayer, OracleRelayerForTest} from '@test/mocks/OracleRelayerForTest.sol';
import {OracleForTest, IBaseOracle} from '@test/mocks/OracleForTest.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
  function prank(address) public virtual;
  function startPrank(address) public virtual;
  function etch(address, bytes calldata) public virtual;
  function expectRevert(bytes4) public virtual;
}

contract SingleExpensesAuctioneerTest is DSTest {
  Hevm hevm;

  ExpensesAuctioneer expensesAuctioneer;
  CollateralAuctionHouse kiteCollateralAuctionHouse;
  SAFEEngine safeEngine;
  OracleRelayerForTest oracleRelayer;
  OracleForTest systemCoinOracle;
  CoinForTest protocolToken;
  OracleForTest protocolTokenOracle;
  CollateralJoin protocolTokenJoin;

  address constant RECIPIENT = address(420);
  address constant BIDDER = address(69);

  uint256 constant ONE = 10 ** 27;
  uint256 constant MINUS_50_PERCENT_IN_10_HOURS = 999_980_746_097_009_882_063_724_393;
  bytes32 constant KITE = bytes32('KITE');
  uint256 constant KITE_PRICE = 10e18;
  uint256 constant HAI_PRICE = 1e18;

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * ONE;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});

    safeEngine = new SAFEEngine(_safeEngineParams);

    protocolToken = new CoinForTest('', '');
    protocolTokenJoin = new CollateralJoin(address(safeEngine), KITE, address(protocolToken));
    safeEngine.addAuthorization(address(protocolTokenJoin));

    systemCoinOracle = new OracleForTest(HAI_PRICE);

    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: 1e45, redemptionRateLowerBound: 1});
    oracleRelayer = new OracleRelayerForTest(address(safeEngine), IBaseOracle(systemCoinOracle), _oracleRelayerParams);
    safeEngine.addAuthorization(address(oracleRelayer));
    oracleRelayer.setRedemptionPrice(1e27);

    protocolTokenOracle = new OracleForTest(KITE_PRICE);

    oracleRelayer.initializeCollateralType(
      KITE,
      abi.encode(
        IOracleRelayer.OracleRelayerCollateralParams({
          oracle: IBaseOracle(protocolTokenOracle),
          safetyCRatio: 1e27,
          liquidationCRatio: 1e27
        })
      )
    );

    oracleRelayer.updateCollateralPrice(KITE);

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _pssahParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minimumBid: 100e18,
      minDiscount: 1e18,
      maxDiscount: 0.5e18,
      perSecondDiscountUpdateRate: MINUS_50_PERCENT_IN_10_HOURS
    });

    ExpensesAuctioneer.ExpensesAuctioneerParams memory _expensesAuctioneerParams = ExpensesAuctioneer
      .ExpensesAuctioneerParams({
      recipient: RECIPIENT,
      usdAmountPerAuction: 1000 ether, // 1000 USD per auction
      expensesPerYear: 365 * 1000 ether, // 1000 USD per day
      sellBuffer: 1.1 ether, // + 10%
      cooldownPeriod: 1 days,
      auctionDuration: 1 days
    });

    expensesAuctioneer = new ExpensesAuctioneer(
      address(safeEngine), address(protocolTokenJoin), address(oracleRelayer), _expensesAuctioneerParams
    );

    kiteCollateralAuctionHouse = new CollateralAuctionHouse(
      address(safeEngine), address(expensesAuctioneer), address(oracleRelayer), KITE, _pssahParams
    );

    expensesAuctioneer.modifyParameters('collateralAuctionHouse', abi.encode(address(kiteCollateralAuctionHouse)));

    protocolToken.mint(1000 ether);
    protocolToken.transfer(address(expensesAuctioneer), 1000 ether);
    expensesAuctioneer.joinKiteBalance();

    safeEngine.createUnbackedDebt(BIDDER, BIDDER, 1000e45);
    hevm.prank(BIDDER);
    safeEngine.approveSAFEModification(address(kiteCollateralAuctionHouse));
  }

  function test_modify_parameters() public {
    CollateralJoin _newProtocolJoin = new CollateralJoin(address(safeEngine), KITE, address(protocolToken));
    expensesAuctioneer.modifyParameters('protocolJoin', abi.encode(_newProtocolJoin));
    hevm.etch(address(0x5678), abi.encode(0xF)); // ensure oracleRelayer has code
    expensesAuctioneer.modifyParameters('oracleRelayer', abi.encode(0x5678));
    CollateralAuctionHouse _newCollateralAuctionHouse = new CollateralAuctionHouse(
      address(safeEngine),
      address(expensesAuctioneer),
      address(oracleRelayer),
      KITE,
      ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: 100e18,
        minDiscount: 1e18,
        maxDiscount: 0.5e18,
        perSecondDiscountUpdateRate: MINUS_50_PERCENT_IN_10_HOURS
      })
    );
    expensesAuctioneer.modifyParameters('collateralAuctionHouse', abi.encode(_newCollateralAuctionHouse));
    expensesAuctioneer.modifyParameters('recipient', abi.encode(0x13141516));
    expensesAuctioneer.modifyParameters('usdAmountPerAuction', abi.encode(100));
    expensesAuctioneer.modifyParameters('expensesPerYear', abi.encode(200));
    expensesAuctioneer.modifyParameters('sellBuffer', abi.encode(300));
    expensesAuctioneer.modifyParameters('cooldownPeriod', abi.encode(400));
    expensesAuctioneer.modifyParameters('auctionDuration', abi.encode(500));

    assertTrue(address(expensesAuctioneer.protocolJoin()) == address(_newProtocolJoin));
    assertTrue(address(expensesAuctioneer.oracleRelayer()) == address(0x5678));
    assertTrue(address(expensesAuctioneer.collateralAuctionHouse()) == address(_newCollateralAuctionHouse));
    assertTrue(expensesAuctioneer.params().recipient == address(0x13141516));
    assertTrue(expensesAuctioneer.params().usdAmountPerAuction == 100);
    assertTrue(expensesAuctioneer.params().expensesPerYear == 200);
    assertTrue(expensesAuctioneer.params().sellBuffer == 300);
    assertTrue(expensesAuctioneer.params().cooldownPeriod == 400);
    assertTrue(expensesAuctioneer.params().auctionDuration == 500);
  }

  function test_auction_expenses() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();

    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);

    assertEq(_auction.amountToSell, 110 ether); // sell 100 KITE ($1000) + 10% buffer
    assertEq(_auction.amountToRaise, 1000e45); // raise 1000 HAI (@1 RP)
    assertEq(_auction.initialTimestamp, block.timestamp);
    assertEq(_auction.forgoneCollateralReceiver, address(expensesAuctioneer));
    assertEq(_auction.auctionIncomeRecipient, RECIPIENT);
  }

  function test_buy_auction() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 1000e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(_auction.initialTimestamp, 0);
    assertEq(_auction.forgoneCollateralReceiver, address(0));
    assertEq(_auction.auctionIncomeRecipient, address(0));

    // Check that it covered 1000 HAI (@1 RP) = $1000 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 1000e18);
  }

  function test_partial_buy_auction() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 500e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 60 ether); // 50 KITE ($500) + 10% buffer
    assertEq(_auction.amountToRaise, 500e45); // raise 500 HAI (@1 RP)
    assertEq(_auction.initialTimestamp, block.timestamp);
    assertEq(_auction.forgoneCollateralReceiver, address(expensesAuctioneer));
    assertEq(_auction.auctionIncomeRecipient, address(RECIPIENT));

    // Check that it covered 1000 HAI (@1 RP) = $1000 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 500e18);
  }

  function test_buy_auction_with_new_redemption_price() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    oracleRelayer.setRedemptionPrice(2e27);

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 500e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 10 ether); // the 10% buffer
    assertEq(_auction.amountToRaise, 500e45); // raise 500 HAI (@2 RP)

    // Check that it covered 500 HAI (@1 MP) = $500 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 500e18);
  }

  function test_buy_auction_with_new_market_price() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    systemCoinOracle.setPriceAndValidity(2e18, true);

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 500e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 60 ether); // 50% of initial Kite + the 10% buffer
    assertEq(_auction.amountToRaise, 500e45); // raise 500 HAI (@1 RP)

    // Check that it covered 500 HAI (@2 MP) = $1000 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 1000e18);
  }

  function test_buy_auction_with_new_kite_price() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    protocolTokenOracle.setPriceAndValidity(5e18, true);

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 500e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 10 ether); // the 10% buffer
    assertEq(_auction.amountToRaise, 500e45); // raise 500 HAI (@1 RP)

    // Check that it covered 500 HAI (@1 RP) = $500 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 500e18);
  }

  function test_buy_auction_with_discounted_kite_price() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();

    hevm.warp(block.timestamp + 10 * 3600);
    expensesAuctioneer.pokeExpenses();
    uint256 _outstandingDebt = expensesAuctioneer.outstandingDebt();

    hevm.prank(BIDDER);
    kiteCollateralAuctionHouse.buyCollateral(_auctionId, 500e18);

    // Check that the auction is deleted
    ICollateralAuctionHouse.Auction memory _auction = kiteCollateralAuctionHouse.auctions(_auctionId);
    assertEq(_auction.amountToSell, 10 ether); // the 10% buffer
    assertEq(_auction.amountToRaise, 500e45); // raise 500 HAI (@1 RP)

    // Check that it covered 500 HAI (@1 RP) = $500 of debt
    assertEq(_outstandingDebt - expensesAuctioneer.outstandingDebt(), 500e18);
  }

  function test_cooldown() public {
    hevm.warp(block.timestamp + 1 days);
    expensesAuctioneer.auctionExpenses();

    hevm.expectRevert(ExpensesAuctioneer.AuctioneerIsInCooldown.selector);
    expensesAuctioneer.auctionExpenses();

    hevm.warp(block.timestamp + 1 days);
    expensesAuctioneer.auctionExpenses();
  }

  function test_terminate_auction() public {
    hevm.warp(block.timestamp + 1 days);
    uint256 _auctionId = expensesAuctioneer.auctionExpenses();

    hevm.expectRevert(ExpensesAuctioneer.AuctionIsStillActive.selector);
    expensesAuctioneer.terminateAuction(_auctionId);

    hevm.warp(block.timestamp + 1 days);
    expensesAuctioneer.terminateAuction(_auctionId);
  }

  function test_not_enough_debt() public {
    hevm.expectRevert(ExpensesAuctioneer.NotEnoughDebt.selector);
    expensesAuctioneer.auctionExpenses();
  }
}

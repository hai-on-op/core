// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

bytes32 constant TKN = bytes32('TKN');
uint256 constant TEST_ETH_PRICE = 1000e18; // 1 ETH = 1000 HAI
uint256 constant TEST_TKN_PRICE = 1e18; // 1 TKN = 1 HAI

uint256 constant INITIAL_DEBT_AUCTION_MINTED_TOKENS = 1e18;
uint256 constant ONE_HUNDRED_COINS = 100e45;
uint256 constant PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY = 50e27;

address constant SURPLUS_AUCTION_BID_RECEIVER = address(420);

//  420000 00000000000000000000000000000000000000000000

abstract contract TestParams is Contracts, Params {
  // --- ForTest Params ---

  function _getEnvironmentParams() internal override {
    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      // safeDebtCeiling: 1_000_000 * WAD, // WAD
      // globalDebtCeiling: 55_000_000 * RAD // initially disabled
      safeDebtCeiling: 1_000_000_000_000_000_000_000_000, // WAD
      globalDebtCeiling: 55_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000 // initially disabled
        // 55000000000000000000000000000000000000000000000000000
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 86_400, // no delay
      popDebtDelay: 1800, // no delay
      disableCooldown: 259_200, // no cooldown
      surplusAmount: 42_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000, // 100 HAI
      surplusBuffer: 100_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000, // no buffer
      debtAuctionMintedTokens: 10_000_000_000_000_000_000_000, // 1 KITE
      debtAuctionBidSize: 1_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000_000
    });
    // 100 HAI

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18, // -5 %
      amountSoldIncrease: 1.5e18, // +50 %
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 1 hours,
      totalAuctionLength: 1 days,
      bidReceiver: SURPLUS_AUCTION_BID_RECEIVER,
      recyclingPercentage: 0.5e18 // 50% is burned
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 10_000 * RAD, // 10_000 HAI
      saviourGasLimit: 10_000_000 // 10M gas
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      treasuryCapacity: 1000e45, // 1_000 HAI
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY, // no global SF
      maxStabilityFeeRange: RAY - 1, // no range restriction
      maxSecondaryReceivers: 1 // stabilityFeeTreasury
    });

    delete _taxCollectorSecondaryTaxReceiver; // avoid stacking old data on each push

    _taxCollectorSecondaryTaxReceiver.push(
      ITaxCollector.TaxReceiver({
        receiver: address(stabilityFeeTreasury),
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.5e18 // [wad%]
      })
    );

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: RAY * WAD, // RAY
      redemptionRateLowerBound: 1 // RAY
    });

    _pidControllerParams = IPIDController.PIDControllerParams({
      perSecondCumulativeLeak: MINUS_1_PERCENT_PER_HOUR, // RAD
      noiseBarrier: WAD, // no noise barrier
      feedbackOutputLowerBound: -int256(RAY - 1), // unbounded
      feedbackOutputUpperBound: RAD, // unbounded
      integralPeriodSize: 1 hours
    });

    _pidControllerGains = IPIDController.ControllerGains({
      kp: 1e18, // WAD
      ki: 1e18 // WAD
    });

    _pidRateSetterParams = IPIDRateSetter.PIDRateSetterParams({updateRateDelay: 1 days});

    // --- Collateral Params ---
    // NOTE: all collateral types have the same params in test environment
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      _oracleRelayerCParams[_cType] = IOracleRelayer.OracleRelayerCollateralParams({
        oracle: delayedOracle[_cType],
        safetyCRatio: 1.35e27, // 135%
        liquidationCRatio: 1.35e27 // 135%
      });

      _taxCollectorCParams[_cType] = ITaxCollector.TaxCollectorCollateralParams({
        // NOTE: 5%/yr => 1.05^(1/yr) = 1 + 1.54713e-9
        stabilityFee: RAY + 1.54713e18 // RAY
      });

      _safeEngineCParams[_cType] = ISAFEEngine.SAFEEngineCollateralParams({
        debtCeiling: 1_000_000_000 * RAD, // RAD
        debtFloor: 0 // RAD
      });

      _liquidationEngineCParams[_cType] = ILiquidationEngine.LiquidationEngineCollateralParams({
        collateralAuctionHouse: address(collateralAuctionHouse[_cType]),
        liquidationPenalty: 1.1e18, // WAD
        liquidationQuantity: 100_000e45 // RAD
      });

      _collateralAuctionHouseParams[_cType] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: 0, // no min
        minDiscount: WAD, // no discount
        maxDiscount: 0.9e18, // -10%
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR // RAY
      });
    }

    // --- Global Settlement Params ---

    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
    _postSettlementSAHParams = IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 900,
      totalAuctionLength: 1800
    });
  }
}

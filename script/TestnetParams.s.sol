// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

abstract contract TestnetParams is Contracts, Params {
  // --- Testnet Params ---
  uint256 constant OP_SEPOLIA_HAI_PRICE_DEVIATION = 0.995e18; // -0.5%
  address constant OP_SEPOLIA_ADMIN_SAFE = 0xCAFd432b7EcAfff352D92fcB81c60380d437E99D;

  function _getEnvironmentParams() internal override {
    // Setup delegated collateral joins
    delegatee[OP] = address(haiDelegatee);

    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 1_000_000 * WAD, // WAD
      globalDebtCeiling: 100_000_000 * RAD // initially disabled
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 2100, // 35 minutes
      popDebtDelay: 15, // 15 seconds
      disableCooldown: 3 days,
      surplusAmount: 1000 * RAD, // 1k HAI
      surplusBuffer: 1050 * RAD, // 1050 HAI
      debtAuctionMintedTokens: 10_000 * WAD, // 10k KITE
      debtAuctionBidSize: 1000 * RAD // 1k HAI
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.025e18, // -2.5 %
      amountSoldIncrease: 1.5e18, // +50 %
      bidDuration: 600, // 10 minutes
      totalAuctionLength: 1800 // 30 minutes
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      // bidDuration: 6 hours,
      bidDuration: 600,
      // totalAuctionLength: 1 days,
      totalAuctionLength: 1800,
      bidReceiver: governor,
      recyclingPercentage: 0 // 100% is burned
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 10_000_000 * RAD, // 10M HAI
      saviourGasLimit: 10_000_000 // 10M gas
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      treasuryCapacity: 1_000_000 * RAD, // 1M HAI
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY, // no global SF
      maxStabilityFeeRange: RAY - MINUS_0_5_PERCENT_PER_HOUR, // +- 0.5% per hour
      maxSecondaryReceivers: 5
    });

    delete _taxCollectorSecondaryTaxReceiver; // avoid stacking old data on each push

    _taxCollectorSecondaryTaxReceiver.push(
      ITaxCollector.TaxReceiver({
        receiver: address(stabilityFeeTreasury),
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.2e18 // 20%
      })
    );

    _taxCollectorSecondaryTaxReceiver.push(
      ITaxCollector.TaxReceiver({
        receiver: OP_SEPOLIA_ADMIN_SAFE,
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.21e18 // 21%
      })
    );

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: PLUS_950_PERCENT_PER_YEAR, // +950%/yr
      // redemptionRateUpperBound: 1000000074561623060142516377, // +950%/yr
      redemptionRateLowerBound: MINUS_90_PERCENT_PER_YEAR // -90%/yr
        // redemptionRateLowerBound: 99999999999997789272222624 // -90%/yr
    });

    _pidControllerParams = IPIDController.PIDControllerParams({
      perSecondCumulativeLeak: 999_999_711_200_000_000_000_000_000, // HALF_LIFE_30_DAYS
      // noiseBarrier: 0.995e18, // 0.5%
      noiseBarrier: 999_999_999_841_846_100,
      feedbackOutputLowerBound: -int256(RAY - 1), // unbounded
      feedbackOutputUpperBound: RAD, // unbounded
      integralPeriodSize: 1 hours
    });

    _pidControllerGains = IPIDController.ControllerGains({
      kp: int256(PROPORTIONAL_GAIN), // imported from RAI
      ki: int256(INTEGRAL_GAIN) // imported from RAI
    });

    _pidRateSetterParams = IPIDRateSetter.PIDRateSetterParams({updateRateDelay: 1 hours});

    // --- Global Settlement Params ---
    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
    _postSettlementSAHParams = IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 3 hours,
      totalAuctionLength: 1 days
    });

    // --- Collateral Default Params ---
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      _oracleRelayerCParams[_cType] = IOracleRelayer.OracleRelayerCollateralParams({
        oracle: delayedOracle[_cType],
        safetyCRatio: 1.5e27, // 150%
        liquidationCRatio: 1.5e27 // 150%
      });

      _taxCollectorCParams[_cType] = ITaxCollector.TaxCollectorCollateralParams({
        // NOTE: 42%/yr => 1.42^(1/yr) = 1 + 11,11926e-9
        stabilityFee: RAY + 11.11926e18 // + 42%/yr
      });

      _safeEngineCParams[_cType] = ISAFEEngine.SAFEEngineCollateralParams({
        debtCeiling: 10_000_000 * RAD, // 10M HAI
        debtFloor: 1 * RAD // 1 HAI
      });

      _liquidationEngineCParams[_cType] = ILiquidationEngine.LiquidationEngineCollateralParams({
        collateralAuctionHouse: address(collateralAuctionHouse[_cType]),
        liquidationPenalty: 1.1e18, // 10%
        liquidationQuantity: 1000 * RAD // 1000 HAI
      });

      _collateralAuctionHouseParams[_cType] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: WAD, // 1 HAI
        minDiscount: WAD, // no discount
        maxDiscount: 0.9e18, // -10%
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR // RAY
      });
    }

    // --- Collateral Specific Params ---
    _oracleRelayerCParams[WETH].safetyCRatio = 1.35e27; // 135%
    _oracleRelayerCParams[WETH].liquidationCRatio = 1.35e27; // 135%
    _taxCollectorCParams[WETH].stabilityFee = RAY + 1.54713e18; // + 5%/yr
    _safeEngineCParams[WETH].debtCeiling = 100_000_000 * RAD; // 100M HAI

    _liquidationEngineCParams[OP].liquidationPenalty = 1.2e18; // 20%
    _collateralAuctionHouseParams[OP].maxDiscount = 0.5e18; // -50%

    _collateralAuctionHouseParams[TOTEM].perSecondDiscountUpdateRate = 999_985_366_702_115_272_120_527_460;

    // --- Governance Params ---
    _governorParams = IHaiGovernor.HaiGovernorParams({
      votingDelay: 12 hours, // 43_200
      votingPeriod: 36 hours, // 129_600
      proposalThreshold: 5000 * WAD, // 5k KITE
      quorumNumeratorValue: 1, // 1%
      quorumVoteExtension: 1 days, // 86_400
      timelockMinDelay: 1 days // 86_400
    });

    _tokenDistributorParams = ITokenDistributor.TokenDistributorParams({
      root: 0x6fc714df6371f577a195c2bfc47da41aa0ea15bba2651df126f3713a232244be,
      totalClaimable: 1_000_000 * WAD, // 1M HAI
      claimPeriodStart: block.timestamp + 1 days,
      claimPeriodEnd: 1_735_689_599 // 1/1/2025 (GMT+0) - 1s
    });
  }
}

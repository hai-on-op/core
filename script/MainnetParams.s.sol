// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

abstract contract MainnetParams is Contracts, Params {
  address constant OP_ADMIN_SAFE = 0x468c572c41DB8B206B3919AC9a41ad8dE2eAc822;

  // --- Mainnet Params ---
  function _getEnvironmentParams() internal override {
    // Setup delegated collateral joins
    delegatee[OP] = address(haiDelegatee);

    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 1_000_000 * WAD, // WAD
      globalDebtCeiling: 55_000_000 * RAD // initially disabled
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 1 days,
      popDebtDelay: 14 days,
      disableCooldown: 3 days,
      surplusAmount: 42_000 * RAD, // 42k HAI
      surplusBuffer: 100_000 * RAD, // 100k HAI
      debtAuctionMintedTokens: 10_000 * WAD, // 10k KITE
      debtAuctionBidSize: 10_000 * RAD // 10k HAI
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.025e18, // -2.5 %
      amountSoldIncrease: 1.5e18, // +50 %
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 6 hours,
      totalAuctionLength: 1 days,
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
        receiver: OP_ADMIN_SAFE,
        canTakeBackTax: true, // [bool]
        taxPercentage: 0.21e18 // 21%
      })
    );

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: PLUS_950_PERCENT_PER_YEAR, // +950%/yr
      redemptionRateLowerBound: MINUS_90_PERCENT_PER_YEAR // -90%/yr
    });

    _pidControllerParams = IPIDController.PIDControllerParams({
      perSecondCumulativeLeak: HALF_LIFE_30_DAYS, // 0.999998e27
      noiseBarrier: 0.995e18, // 0.5%
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

    // --- Collateral Specific Params ---
    // ------------ WETH ------------
    _safeEngineCParams[WETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 25_000_000 * RAD, // 25M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[WETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[WETH],
      safetyCRatio: 1.3e27, // 130%
      liquidationCRatio: 1.25e27 // 125%
    });

    _taxCollectorCParams[WETH].stabilityFee = PLUS_1_5_PERCENT_PER_YEAR; // 1.5%/yr

    _liquidationEngineCParams[WETH] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[WETH]),
      liquidationPenalty: 1.1e18, // 10%
      liquidationQuantity: 50_000 * RAD // 50k HAI
    });

    _collateralAuctionHouseParams[WETH] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100 HAI
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: MINUS_10_PERCENT_IN_2_HOURS // -10% / 2hs
    });

    // ------------ WSTETH ------------
    _safeEngineCParams[WSTETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 25_000_000 * RAD, // 25M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[WSTETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[WSTETH],
      safetyCRatio: 1.35e27, // 135%
      liquidationCRatio: 1.3e27 // 130%
    });

    _taxCollectorCParams[WSTETH].stabilityFee = PLUS_2_PERCENT_PER_YEAR; // 2%/yr

    _liquidationEngineCParams[WSTETH] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[WSTETH]),
      liquidationPenalty: 1.1e18, // 10%
      liquidationQuantity: 50_000 * RAD // 50k HAI
    });

    _collateralAuctionHouseParams[WSTETH] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100 HAI
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: MINUS_10_PERCENT_IN_2_HOURS // -10% / 2hs
    });

    // ------------ OP ------------
    _safeEngineCParams[OP] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 5_000_000 * RAD, // 5M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[OP] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[OP],
      safetyCRatio: 1.8e27, // 180%
      liquidationCRatio: 1.75e27 // 175%
    });

    _taxCollectorCParams[OP].stabilityFee = PLUS_5_PERCENT_PER_YEAR; // 5%/yr

    _liquidationEngineCParams[OP] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[OP]),
      liquidationPenalty: 1.15e18, // 15%
      liquidationQuantity: 50_000 * RAD // 50k HAI
    });

    _collateralAuctionHouseParams[OP] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100 HAI
      minDiscount: 1e18, // no discount
      maxDiscount: 0.85e18, // -15%
      perSecondDiscountUpdateRate: MINUS_15_PERCENT_IN_2_HOURS // -15% / 2hs
    });

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
      root: 0xfb2ccf2133c19008b5bb590df11d243c8bf4ad5c9a8210d86f7f1f78ee46d634,
      totalClaimable: 1_000_000 * WAD, // 1M HAI
      claimPeriodStart: 1_707_782_400, // 13/2/2024 (GMT+0)
      claimPeriodEnd: 1_735_689_599 // 1/1/2025 (GMT+0) - 1s
    });
  }
}

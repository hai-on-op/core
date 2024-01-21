// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

abstract contract MainnetParams is Contracts, Params {
  // --- Mainnet Params ---
  function _getEnvironmentParams() internal override {
    // Setup delegated collateral joins
    delegatee[OP] = address(haiDelegatee);

    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 1_000_000 * WAD, // WAD
      globalDebtCeiling: 0 // initially disabled
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 1 days,
      popDebtDelay: 14 days,
      disableCooldown: 3 days,
      surplusAmount: 42_000 * RAD, // 42k HAI
      surplusBuffer: 100_000 * RAD, // 100k HAI
      debtAuctionMintedTokens: 10_000 * WAD, // 10k KITE
      debtAuctionBidSize: 1000 * RAD // 1k HAI
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
      maxSecondaryReceivers: 5 // stabilityFeeTreasury
    });

    // TODO: set multiple secondary receivers
    _taxCollectorSecondaryTaxReceiver = ITaxCollector.TaxReceiver({
      receiver: address(stabilityFeeTreasury),
      canTakeBackTax: true, // [bool]
      taxPercentage: 0.5e18 // [wad%]
    });

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: 1_000_000_074_561_623_060_142_516_377, // +950%/yr
      redemptionRateLowerBound: 99_999_999_999_997_789_272_222_624 // -90%/yr
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
      safetyCRatio: 1.35e27, // 135%
      liquidationCRatio: 1.3e27 // 130%
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
      perSecondDiscountUpdateRate: 999_985_366_702_115_272_120_527_460 // -10% / 2hs
    });

    // ------------ WSTETH ------------
    _safeEngineCParams[WSTETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 25_000_000 * RAD, // 25M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[WSTETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[WSTETH],
      safetyCRatio: 1.4e27, // 140%
      liquidationCRatio: 1.35e27 // 135%
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
      perSecondDiscountUpdateRate: 999_985_366_702_115_272_120_527_460 // -10% / 2hs
    });

    // ------------ OP ------------
    _safeEngineCParams[OP] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 5_000_000 * RAD, // 5M HAI
      debtFloor: 150 * RAD // 150 HAI
    });

    _oracleRelayerCParams[OP] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[OP],
      safetyCRatio: 1.65e27, // 165%
      liquidationCRatio: 1.6e27 // 160%
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
      maxDiscount: 0.85e18, // -10%
      perSecondDiscountUpdateRate: 999_977_428_181_205_977_622_596_568 // -15% / 2hs
    });

    // --- Governance Params ---
    _governorParams = IHaiGovernor.HaiGovernorParams({
      votingDelay: 43_200, // 12 hours
      votingPeriod: 129_600, // 36 hours
      proposalThreshold: 5000 * WAD, // 5k
      quorumNumeratorValue: 1, // 1%
      quorumVoteExtension: 86_400, // 1 day
      timelockMinDelay: 86_400 // 1 day
    });

    _tokenDistributorParams = ITokenDistributor.TokenDistributorParams({
      root: bytes32(keccak256('420')), // TODO: set root
      totalClaimable: 1_000_000 * WAD, // 1M HAI
      claimPeriodStart: 1_707_782_400, // 13/2/24 (GMT)
      claimPeriodEnd: 1_735_689_599 // 1/1/2025 (GMT) - 1s
    });
  }
}

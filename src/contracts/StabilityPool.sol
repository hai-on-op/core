// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
    ERC4626
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@libraries/Math.sol";
import {IStabilityPool} from "@interfaces/IStabilityPool.sol";
import {ISwapStrategy} from "@interfaces/ISwapStrategy.sol";
import {IEmissionsController} from "@interfaces/IEmissionsController.sol";
import {IOracleRelayer} from "@interfaces/IOracleRelayer.sol";
import {ICollateralAuctionHouse} from "@interfaces/ICollateralAuctionHouse.sol";
import {IProtocolToken} from "@interfaces/tokens/IProtocolToken.sol";
import {ISystemCoin} from "@interfaces/tokens/ISystemCoin.sol";
import {IBaseOracle} from "@interfaces/oracles/IBaseOracle.sol";
import {Authorizable} from "@contracts/utils/Authorizable.sol";

/**
 * @title StabilityPool
 * @notice ERC4626 vault where users deposit HAI and receive sHAI shares, with KITE reward distribution
 * @dev Implements integral-based reward tracking with lazy update pattern for transferable shares
 */
contract StabilityPool is ERC4626, Authorizable, IStabilityPool {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // --- Registry ---

    /// @inheritdoc IStabilityPool
    ISystemCoin public systemCoin;

    /// @inheritdoc IStabilityPool
    IProtocolToken public protocolToken;

    /// @inheritdoc IStabilityPool
    IOracleRelayer public oracleRelayer;

    /// @inheritdoc IStabilityPool
    IEmissionsController public emissionsController;

    // --- Data ---

    /// @inheritdoc IStabilityPool
    uint256 public kiteRewardIntegral;

    /// @inheritdoc IStabilityPool
    mapping(address => uint256) public kiteRewardIntegralFor;

    /// @inheritdoc IStabilityPool
    uint256 public kiteRewardRemaining;

    /// @inheritdoc IStabilityPool
    mapping(bytes32 => ISwapStrategy) public swapStrategies;

    // --- Init ---

    /**
     * @param  _systemCoin Address of the system coin
     * @param  _protocolToken Address of the protocol token
     * @param  _oracleRelayer Address of the OracleRelayer contract
     * @param  _emissionsController Address of the EmissionsController contract
     */
    constructor(
        address _systemCoin,
        address _protocolToken,
        address _oracleRelayer,
        address _emissionsController,
    ) ERC4626(IERC20(_systemCoin)) ERC20("Staked HAI", "sHAI") Authorizable(msg.sender) {
        protocolToken = IProtocolToken(_protocolToken);
        oracleRelayer = IOracleRelayer(_oracleRelayer);
        emissionsController = IEmissionsController(_emissionsController);
    }

    // --- Methods ---

    /// @inheritdoc IStabilityPool
    function claimRewardsFromEmissionsController()
        external
        returns (uint256 _amount)
    {
        _amount = emissionsController.claimRewardsForStabilityPool();
        if (_amount > 0) {
            // KITE is transferred to this contract by EmissionsController
            // Update reward integral will detect it on next call
            emit ClaimRewardsFromEmissionsController(_amount);
        }
    }

    // Note: claimRewards() removed - rewards are only claimable when withdrawing shares


    /**
     * @notice Returns the amount of claimable KITE for a user
     * @param  _user Address of the user
     * @return _amount Amount of claimable KITE [wad]
     */
    function pendingRewards(
        address _user
    ) external view returns (uint256 _amount) {
        uint256 _userBalance = balanceOf(_user);
        uint256 _userIntegral = kiteRewardIntegralFor[_user];

        // Calculate current integral (including any unclaimed KITE)
        uint256 _currentIntegral = kiteRewardIntegral;
        uint256 _currentKiteBalance = protocolToken.balanceOf(address(this));
        if (_currentKiteBalance > kiteRewardRemaining) {
            uint256 _newKite = _currentKiteBalance - kiteRewardRemaining;
            uint256 _totalSupply = totalSupply();
            if (_totalSupply > 0) {
                _currentIntegral += (_newKite * WAD) / _totalSupply;
            }
        }

        _amount = (_userBalance * (_currentIntegral - _userIntegral)) / WAD;
    }

    // --- Auction Covering ---

    /**
     * @notice Purchases collateral from auction and swaps it back to HAI if profitable
     * @dev    Joins HAI from ERC20 to SAFEEngine, bids in auction, receives collateral in SAFEEngine
     * @dev    Swap strategy handles collateral from SAFEEngine and swaps to HAI
     * @param  _auctionHouse Address of the CollateralAuctionHouse contract
     * @param  _auctionId Id of the auction
     * @param  _bidAmount Amount of HAI to bid [wad]
     * @param  _collateralType Bytes32 representation of the collateral type
     * @return _profit Amount of HAI profit (can be negative if unprofitable) [wad]
     */
    function coverAndRepayDebt(
        address _auctionHouse,
        uint256 _auctionId,
        uint256 _bidAmount,
        bytes32 _collateralType
    ) external returns (int256 _profit) {
        // Check swap strategy exists
        ISwapStrategy _strategy = swapStrategies[_collateralType];
        if (address(_strategy) == address(0))
            revert StabilityPool_NoSwapStrategy();

        // Get auction details
        ICollateralAuctionHouse _auction = ICollateralAuctionHouse(
            _auctionHouse
        );
        (uint256 _collateralBought, uint256 _adjustedBid) = _auction
            .getCollateralBought(_auctionId, _bidAmount);

        if (_collateralBought == 0) {
            // No collateral to buy
            return int256(0);
        }

        // Profitability Check 1: Purchase price check
        uint256 _redemptionPrice = oracleRelayer.calcRedemptionPrice();
        (IBaseOracle _oracle, , ) = oracleRelayer._cParams(_collateralType);
        uint256 _collateralPriceUsd = _oracle.read(); // Price in USD (18 decimals)

        // Calculate USD values
        // HAI bid USD value = adjustedBid * redemptionPrice (both in RAY, result in RAY)
        // Convert to WAD for comparison: (adjustedBid * redemptionPrice) / RAY
        uint256 _haiBidUsdValue = (_adjustedBid * _redemptionPrice) / RAY;

        // Collateral USD value = collateralBought * collateralPriceUsd (both in WAD)
        uint256 _collateralUsdValue = (_collateralBought *
            _collateralPriceUsd) / WAD;

        // Check if purchase is at least break-even
        if (_collateralUsdValue < _haiBidUsdValue) {
            revert StabilityPool_NotProfitable();
        }

        // Profitability Check 2: Swap profitability
        uint256 _estimatedHaiReceived = _strategy.estimateSwapToHai(
            _collateralType,
            _collateralBought
        );
        uint256 _estimatedHaiUsdValue = (_estimatedHaiReceived *
            _redemptionPrice) / RAY;

        // Check if swap is profitable
        if (_estimatedHaiUsdValue <= _haiBidUsdValue) {
            revert StabilityPool_NotProfitable();
        }

        // Execute purchase - auction transfers collateral to this contract in SAFEEngine
        // Note: HAI must already be available for the auction (handled externally)
        (uint256 _actualCollateralBought, uint256 _actualAdjustedBid) = _auction
            .buyCollateral(_auctionId, _bidAmount);

        // Execute swap - swap strategy handles collateral from SAFEEngine and swaps to HAI
        // The swap strategy should transfer HAI (ERC20) back to this contract
        uint256 _haiReceived = _strategy.swapToHai(
            _collateralType,
            _actualCollateralBought
        );

        // Calculate profit
        _profit = int256(_haiReceived) - int256(_actualAdjustedBid);

        emit CoverAndRepayDebt(
            _auctionId,
            _collateralType,
            _actualCollateralBought,
            _actualAdjustedBid,
            _haiReceived
        );
    }

    // --- Swap Strategy Management ---

    /**
     * @notice Sets a swap strategy for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     * @param  _strategy Address of the swap strategy contract
     */
    function setSwapStrategy(
        bytes32 _collateralType,
        ISwapStrategy _strategy
    ) external isAuthorized {
        if (address(_strategy) == address(0))
            revert StabilityPool_InvalidSwapStrategy();
        swapStrategies[_collateralType] = _strategy;
        emit SetSwapStrategy(_collateralType, address(_strategy));
    }

    /**
     * @notice Removes a swap strategy for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     */
    function removeSwapStrategy(bytes32 _collateralType) external isAuthorized {
        delete swapStrategies[_collateralType];
        emit RemoveSwapStrategy(_collateralType);
    }





    /**
     * @notice Updates the reward integral when new KITE is detected
     * @dev Uses lazy update pattern - checks if KITE balance increased
     */
    /**
     * @notice Updates the reward integral when new KITE is detected
     * @dev Uses lazy update pattern - checks if KITE balance increased
     */
    function _updateRewardIntegral() internal {
        uint256 _currentKiteBalance = protocolToken.balanceOf(address(this));
        if (_currentKiteBalance > kiteRewardRemaining) {
            uint256 _newKite = _currentKiteBalance - kiteRewardRemaining;
            uint256 _totalSupply = totalSupply();
            if (_totalSupply > 0) {
                // Add new KITE to integral: (newKite * 1e18) / totalSupply
                kiteRewardIntegral += (_newKite * WAD) / _totalSupply;
            }
            kiteRewardRemaining = _currentKiteBalance;
        }
    }

    /**
     * @notice Override ERC20 _update hook to checkpoint rewards on mints
     * @dev Simplified: Only checkpoints on mints. Transfers don't need checkpoint logic
     *      since rewards are only claimable on withdrawal
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        // Update reward integral if new KITE was deposited
        _updateRewardIntegral();

        // Only checkpoint on mints (new shares being created)
        // Transfers don't need checkpoint logic - rewards move with shares and are claimable on withdrawal
        if (from == address(0) && to != address(0)) {
            // Mint: new shares being created
            // If new user (no shares before mint), set checkpoint to current integral (can't claim past rewards)
            // If existing user, keep their current checkpoint (they can claim rewards on new shares)
            if (balanceOf(to) == 0) {
                kiteRewardIntegralFor[to] = kiteRewardIntegral;
            }
            // If receiver already has shares, keep their current checkpoint (don't change it)
        }

        // Call parent _update to perform the actual transfer/mint/burn
        super._update(from, to, value);
    }

    /**
     * @notice Override _deposit to claim rewards from EmissionsController before deposit
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // Claim rewards from EmissionsController before deposit
        claimRewardsFromEmissionsController();
        super._deposit(caller, receiver, assets, shares);
    }

    /**
     * @notice Override _withdraw to distribute KITE proportionally when users withdraw/redeem
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        // Update reward integral
        _updateRewardIntegral();

        // Calculate proportional KITE for the shares being withdrawn
        uint256 _userIntegral = kiteRewardIntegralFor[owner];
        uint256 _claimableKite = (shares *
            (kiteRewardIntegral - _userIntegral)) / WAD;

        // Update user's checkpoint
        kiteRewardIntegralFor[owner] = kiteRewardIntegral;

        // Transfer proportional KITE to receiver if any
        // Rewards are automatically distributed when withdrawing shares
        if (_claimableKite > 0) {
            kiteRewardRemaining -= _claimableKite;
            protocolToken.safeTransfer(receiver, _claimableKite);
            emit ClaimRewards(owner, _claimableKite);
        }

        // Call parent _withdraw to perform the actual withdrawal
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ISwapStrategy} from "@interfaces/ISwapStrategy.sol";
import {IProtocolToken} from "@interfaces/tokens/IProtocolToken.sol";
import {ISystemCoin} from "@interfaces/tokens/ISystemCoin.sol";

/**
 * @title IStabilityPool
 * @notice Interface for the StabilityPool ERC4626 vault with KITE rewards
 */
interface IStabilityPool is IERC4626 {
    // --- Events ---

    /**
     * @notice Emitted when rewards are claimed
     * @param  _user Address of the user claiming rewards
     * @param  _amount Amount of KITE claimed [wad]
     */
    event ClaimRewards(address indexed _user, uint256 _amount);

    /**
     * @notice Emitted when rewards are claimed from EmissionsController
     * @param  _amount Amount of KITE claimed [wad]
     */
    event ClaimRewardsFromEmissionsController(uint256 _amount);

    /**
     * @notice Emitted when collateral is covered and debt is repaid
     * @param  _auctionId Id of the auction
     * @param  _collateralType Bytes32 representation of the collateral type
     * @param  _collateralAmount Amount of collateral purchased [wad]
     * @param  _haiSpent Amount of HAI spent [wad]
     * @param  _haiReceived Amount of HAI received from swap [wad]
     */
    event CoverAndRepayDebt(
        uint256 indexed _auctionId,
        bytes32 indexed _collateralType,
        uint256 _collateralAmount,
        uint256 _haiSpent,
        uint256 _haiReceived
    );

    /**
     * @notice Emitted when a swap strategy is set for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     * @param  _strategy Address of the swap strategy contract
     */
    event SetSwapStrategy(bytes32 indexed _collateralType, address _strategy);

    /**
     * @notice Emitted when a swap strategy is removed for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     */
    event RemoveSwapStrategy(bytes32 indexed _collateralType);

    // --- Errors ---

    /// @notice Throws when trying to set an invalid swap strategy
    error StabilityPool_InvalidSwapStrategy();
    /// @notice Throws when no swap strategy is registered for a collateral type
    error StabilityPool_NoSwapStrategy();
    /// @notice Throws when coverAndRepayDebt is not profitable
    error StabilityPool_NotProfitable();

    // --- Registry ---

    /// @notice Address of the system coin
    function systemCoin() external view returns (ISystemCoin _systemCoin);

    /// @notice Address of the protocol token
    function protocolToken()
        external
        view
        returns (IProtocolToken _protocolToken);

    /// @notice OracleRelayer for getting redemption price and collateral prices
    function oracleRelayer()
        external
        view
        returns (IOracleRelayer _oracleRelayer);

    /// @notice Address of EmissionsController contract
    function emissionsController()
        external
        view
        returns (IEmissionsController _emissionsController);

    // --- Data ---

    /// @notice Cumulative KITE rewards per share (scaled by 1e18)
    uint256 public kiteRewardIntegral;

    /// @notice Last checkpointed integral per user
    mapping(address => uint256) public kiteRewardIntegralFor;

    /// @notice Last known KITE balance (used to detect new deposits)
    uint256 public kiteRewardRemaining;

    /// @notice Maps collateral types to their swap strategy contracts
    mapping(bytes32 => ISwapStrategy) public swapStrategies;

    // --- Methods ---

    /**
     * @notice Claims accrued protocol tokens from EmissionsController and adds it to the stability pool
     * @return _amount Amount of protocol tokens claimed [wad]
     */
    function claimRewardsFromEmissionsController()
        external
        returns (uint256 _amount);

    /**
     * @notice Claims accumulated KITE rewards for the caller
     * @return _amount Amount of KITE claimed [wad]
     */
    function claimRewards() external returns (uint256 _amount);

    /**
     * @notice Purchases collateral from auction and swaps it back to HAI if profitable
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
    ) external returns (int256 _profit);

    /**
     * @notice Sets a swap strategy for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     * @param  _strategy Address of the swap strategy contract
     */
    function setSwapStrategy(
        bytes32 _collateralType,
        ISwapStrategy _strategy
    ) external;

    /**
     * @notice Removes a swap strategy for a collateral type
     * @param  _collateralType Bytes32 representation of the collateral type
     */
    function removeSwapStrategy(bytes32 _collateralType) external;

    // --- View Methods ---

    /**
     * @notice Returns the amount of claimable KITE for a user
     * @param  _user Address of the user
     * @return _amount Amount of claimable KITE [wad]
     */
    function pendingRewards(
        address _user
    ) external view returns (uint256 _amount);
}

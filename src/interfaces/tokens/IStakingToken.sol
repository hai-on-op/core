// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from "@interfaces/tokens/IProtocolToken.sol";

import {IStakingManager} from "@interfaces/tokens/IStakingManager.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import {IAuthorizable} from "@interfaces/utils/IAuthorizable.sol";

/**
 * @title  IStakingToken
 * @notice Interface for the StakingToken contract which represents staked protocol tokens
 * @dev    Implements ERC20 with voting capabilities and pausable functionality
 */
interface IStakingToken is IERC20Metadata, IERC20Permit, IVotes, IAuthorizable {
    // --- Events ---

    /**
     * @notice Emitted when tokens are minted
     * @param dst The address that received the minted tokens
     * @param wad The amount of tokens minted
     */
    event StakingToken_Mint(address indexed dst, uint256 wad);

    /**
     * @notice Emitted when tokens are burned
     * @param src The address whose tokens were burned
     * @param wad The amount of tokens burned
     */
    event StakingToken_Burn(address indexed src, uint256 wad);

    /// @notice Emitted when the contract is paused
    event StakingToken_Pause();

    /// @notice Emitted when the contract is unpaused
    event StakingToken_Unpause();

    // --- Errors ---

    /// @notice Throws when StakingManager is null
    error StakingToken_NullStakingManager();

    /// @notice Throws when ProtocolToken is null
    error StakingToken_NullProtocolToken();

    /// @notice Throws when attempting to mint to zero address
    error StakingToken_MintToZeroAddress();

    /// @notice Throws when attempting to burn more than balance
    error StakingToken_InsufficientBalance();

    // --- Registry ---

    /**
     * @notice Address of the protocol token
     * @return _protocolToken The protocol token contract
     */
    function protocolToken()
        external
        view
        returns (IProtocolToken _protocolToken);

    /**
     * @notice Address of the staking reward manager
     * @return _stakingManager The staking manager contract
     */
    function stakingManager()
        external
        view
        returns (IStakingManager _stakingManager);

    // --- Methods ---

    /**
     * @notice Mints new tokens to the specified address
     * @dev Only callable by authorized addresses
     * @param _dst The address to mint tokens to
     * @param _wad The amount of tokens to mint
     */
    function mint(address _dst, uint256 _wad) external;

    /**
     * @notice Burns tokens from the caller's address
     * @param _wad The amount of tokens to burn
     */
    function burn(uint256 _wad) external;

    /**
     * @notice Burns tokens from the caller's address
     * @param _account Address of the account to mint tokens to
     * @param _wad The amount of tokens to burn
     */
    function burnFrom(address _account, uint256 _wad) external;

    /**
     * @notice Pauses all token transfers
     * @dev Only callable by authorized addresses
     */
    function pause() external;

    /**
     * @notice Unpauses token transfers
     * @dev Only callable by authorized addresses
     */
    function unpause() external;
}

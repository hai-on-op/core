// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  ISystemStakingToken
 * @notice Interface for the SystemStakingToken contract which represents staked system coins
 */
interface ISystemStakingToken is IERC20Metadata, IERC20Permit, IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when tokens are minted
   * @param _dst The address that received the minted tokens
   * @param _wad The amount of tokens minted [wad]
   */
  event SystemStakingTokenMint(address indexed _dst, uint256 _wad);

  /**
   * @notice Emitted when tokens are burned
   * @param _src The address whose tokens were burned
   * @param _wad The amount of tokens burned [wad]
   */
  event SystemStakingTokenBurn(address indexed _src, uint256 _wad);

  // --- Errors ---

  /// @notice Throws when StabilityPool is null
  error SystemStakingToken_NullStabilityPool();

  /// @notice Throws when SystemCoin is null
  error SystemStakingToken_NullSystemCoin();

  // --- Registry ---

  /**
   * @notice Address of the system coin
   * @return _systemCoin The system coin contract
   */
  function systemCoin() external view returns (ISystemCoin _systemCoin);

  /**
   * @notice Address of the stability pool
   * @return _stabilityPool The stability pool contract
   */
  function stabilityPool() external view returns (IStabilityPool _stabilityPool);

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
   * /**
   * @notice Burns tokens from the caller's address
   * @param _account Address of the account to mint tokens to
   * @param _wad The amount of tokens to burn
   */
  function burnFrom(address _account, uint256 _wad) external;
}

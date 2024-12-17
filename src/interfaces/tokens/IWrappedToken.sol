// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  WrappedToken
 * @notice This contract represents the wrapped version of a token to be used in the HAI protocol
 *         It is a one way wrap similar to wrapping crv for cvxCrv
 */
interface IWrappedToken is IERC20Metadata, IERC20Permit, IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a user deposits tokens and mints wrapped tokens
   * @param _account Address of the user depositing the base tokens
   * @param _wad Amount of tokens deposited
   */
  event WrappedTokenDeposit(address indexed _account, uint256 _wad);

  // --- Errors ---

  /// @notice Throws when base token is null
  error WrappedToken_NullBaseToken();

  /// @notice Throws when trying to deposit a null amount
  error WrappedToken_NullAmount();

  /// @notice Throws when trying to deposit and mint wrapped tokens to a null address
  error WrappedToken_NullReceiver();

  /// @notice Throws when base token manager is null
  error WrappedToken_NullBaseTokenManager();

  // -- - Data ---

  struct WrappedTokenParams {
    address baseTokenManager;
  }

  // -- - Registry ---

  /// @notice Address of the base token
  /// @return _baseToken The base token contract
  function BASE_TOKEN() external view returns (IERC20 _baseToken);

  // -- - Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _params WrappedToken parameters struct
   */
  function params() external view returns (WrappedTokenParams memory _params);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _baseTokenManager Address of the base token manager
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (address _baseTokenManager);

  // -- - Data ---

  /**
   * @notice The address where deposited tokens are transferred to that can manage them
   * @return _baseTokenManager Address of the base token manager
   */
  function baseTokenManager() external view returns (address _baseTokenManager);

  // -- - Methods ---

  /**
   * @notice Deposit base tokens and mint wrapped tokens
   * @param _account Account that will receive the wrapped tokens
   * @param _wad Amount of base tokens being deposited [wad]
   */
  function deposit(address _account, uint256 _wad) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IVotingEscrow} from '@interfaces/external/IVotingEscrow.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IWrappedToken} from '@interfaces/tokens/IWrappedToken.sol';

/**
 * @title  WrappedTokenV2
 * @notice This contract represents v2 of the wrapped token, allowing for deposits in both
 *         velo and veVelo NFTs. (It is a one way wrap similar to wrapping crv for cvxCrv
 */
interface IWrappedTokenV2 is IERC20Metadata, IERC20Permit, IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a user deposits tokens and mints wrapped tokens
   * @param _account Address of the user depositing the base tokens
   * @param _wad Amount of tokens deposited
   */
  event WrappedTokenV2Deposit(address indexed _account, uint256 _wad);

  /**
   * @notice Emitted when a user deposits a veNFT and mints wrapped tokens
   * @param _account Address of the user depositing the base tokens
   * @param _tokenId ID of the veNFT being deposited
   * @param _wad Amount of locked velo in veNFT being deposited
   */
  event WrappedTokenV2NFTDeposit(address indexed _account, uint256 _tokenId, uint256 _wad);

  /**
   * @notice Emitted when a user migrates wrapped tokens v1 to v2
   * @param _account Address of the user migrating the wrapped tokens
   * @param _wad Amount of wrapped tokens being migrated
   */
  event WrappedTokenV2MigrateV1toV2(address indexed _account, uint256 _wad);

  // --- Errors ---

  /// @notice Throws when base token is null
  error WrappedTokenV2_NullBaseToken();

  /// @notice Throws when base token NFT is null
  error WrappedTokenV2_NullBaseTokenNFT();

  /// @notice Throws when token id does not exist
  error WrappedTokenV2_TokenIdDoesNotExistOrBalanceIsZero();

  /// @notice Throws when token id is null
  error WrappedTokenV2_NullTokenId();

  /// @notice Throws when trying to deposit a null amount
  error WrappedTokenV2_NullAmount();

  /// @notice Throws when trying to deposit and mint wrapped tokens to a null address
  error WrappedTokenV2_NullReceiver();

  /// @notice Throws when base token manager is null
  error WrappedTokenV2_NullBaseTokenManager();

  /// @notice Throws when wrapped token v1 is null
  error WrappedTokenV2_NullWrappedTokenV1();

  /// @notice Throws when trying to deposit a balance of 0
  error WrappedTokenV2_BalanceIsZero();

  /// @notice Throws when trying to deposit an empty array of token ids
  error WrappedTokenV2_EmptyTokenIds();

  /// @notice Throws when trying to deposit duplicate token ids
  error WrappedTokenV2_DuplicateTokenIds();

  // --- Registry ---

  /// @notice Address of the base token
  /// @return _baseToken The base token contract
  // solhint-disable-next-line func-name-mixedcase
  function BASE_TOKEN() external view returns (IERC20 _baseToken);

  /// @notice Address of the base token NFT
  /// @return _baseTokenNFT The base token NFT contract
  // solhint-disable-next-line func-name-mixedcase
  function BASE_TOKEN_NFT() external view returns (IVotingEscrow _baseTokenNFT);

  /// @notice Address of the wrapped token v1
  /// @return _wrappedTokenV1 The wrapped token v1 contract
  // solhint-disable-next-line func-name-mixedcase
  function WRAPPED_TOKEN_V1() external view returns (IWrappedToken _wrappedTokenV1);

  /// @notice Address of the burn address
  /// @return _burnAddress The burn address
  // solhint-disable-next-line func-name-mixedcase
  function BURN_ADDRESS() external view returns (address _burnAddress);

  // --- Registry ---

  /**
   * @notice The manager contract where deposited tokens are transferred
   */
  function baseTokenManager() external view returns (address _baseTokenManager);

  // -- - Methods ---

  /**
   * @notice Deposit base tokens and mint wrapped tokens
   * @param _account Account that will receive the wrapped tokens
   * @param _wad Amount of base tokens being deposited [wad]
   */
  function deposit(address _account, uint256 _wad) external;

  /**
   * @notice Deposit a veNFT and mint wrapped tokens
   * @param _account Account that will receive the wrapped tokens
   * @param _tokenIds IDs of the veNFTs being deposited
   */
  function depositNFTs(address _account, uint256[] memory _tokenIds) external;

  /**
   * @notice Migrate wrapped tokens v1 to v2
   * @param _account Account that will receive the wrapped tokens
   * @param _wad Amount of wrapped tokens being migrated
   */
  function migrateV1toV2(address _account, uint256 _wad) external;
}

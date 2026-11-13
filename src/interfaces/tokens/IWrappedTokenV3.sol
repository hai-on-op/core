// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

/**
 * @title  WrappedTokenV3
 * @notice This contract represents haiAERO v2, allowing for deposits of AERO on Base, xAERO on Optimism,
 *         sAERO NFTs on Base, and migration of legacy wrapped tokens on Optimism
 * @dev    ERC20 and bridge functions are inherited from HypERC20
 */
interface IWrappedTokenV3 is IERC20Permit, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when a user deposits base tokens and mints wrapped tokens
   * @param _account Address of the user depositing the base tokens
   * @param _recipient Address of the account receiving the wrapped tokens
   * @param _amount Amount of base tokens deposited [wad]
   */
  event WrappedTokenV3Deposit(address indexed _account, address indexed _recipient, uint256 _amount);

  /**
   * @notice Emitted when a user deposits an sAERO NFT and mints wrapped tokens
   * @param _account Address of the user depositing the NFT
   * @param _recipient Address of the account receiving the wrapped tokens
   * @param _tokenId ID of the sAERO NFT deposited
   * @param _principal Amount of underlying AERO in the NFT [wad]
   */
  event WrappedTokenV3NFTDeposit(
    address indexed _account, address indexed _recipient, uint256 indexed _tokenId, uint256 _principal
  );

  /**
   * @notice Emitted when a user migrates legacy wrapped tokens to haiAERO v2
   * @param _account Address of the user migrating the legacy tokens
   * @param _source Address of the legacy token
   * @param _recipient Address of the account receiving the wrapped tokens
   * @param _inputAmount Amount of legacy tokens retired [wad]
   * @param _outputAmount Amount of wrapped tokens minted [wad]
   */
  event WrappedTokenV3Migrate(
    address indexed _account,
    address indexed _source,
    address indexed _recipient,
    uint256 _inputAmount,
    uint256 _outputAmount
  );

  // --- Errors ---

  /// @notice Throws when the deployment configuration is invalid
  error WrappedTokenV3_InvalidConfiguration();

  /// @notice Throws when the current chain differs from the deployment chain
  error WrappedTokenV3_WrongChain();

  /// @notice Throws when an operation is unavailable on the deployment chain
  error WrappedTokenV3_UnsupportedOperation();

  /// @notice Throws when a deposit is empty or a migration would mint zero tokens
  error WrappedTokenV3_InvalidAmount();

  /// @notice Throws when the recipient is null, the wrapper, or the burn address
  error WrappedTokenV3_InvalidRecipient();

  /// @notice Throws when the treasury attempts to deposit backing
  error WrappedTokenV3_TreasuryDeposit();

  /// @notice Throws when a transfer does not deliver the expected tokens or NFT principal to the expected recipient
  error WrappedTokenV3_InexactTransfer();

  /// @notice Throws when an sAERO position has no underlying AERO
  /// @param _tokenId ID of the unsupported sAERO NFT
  error WrappedTokenV3_UnsupportedStake(uint256 _tokenId);

  /// @notice Throws when trying to deposit duplicate token IDs in the same batch
  error WrappedTokenV3_DuplicateTokenIds();

  /// @notice Throws when the sender does not own the sAERO NFT
  error WrappedTokenV3_NotNFTOwner();

  /// @notice Throws when the legacy token is not an accepted migration source
  error WrappedTokenV3_UnsupportedSource();

  /// @notice Throws when the migration output is less than the requested minimum
  error WrappedTokenV3_Slippage();

  /// @notice Throws when a permit signature has expired
  /// @param _deadline Timestamp after which the signature is invalid
  error ERC2612ExpiredSignature(uint256 _deadline);

  /// @notice Throws when a permit signature does not match the token owner
  /// @param _signer Address recovered from the signature
  /// @param _owner Address of the token owner
  error ERC2612InvalidSigner(address _signer, address _owner);

  // --- Structs ---

  struct DeploymentConfig {
    // Address of AERO on Base or xAERO on Optimism
    address baseToken;
    // Address of sAERO on Base, or the null address on Optimism
    address baseTokenNFT;
    // Initial address of the deposit manager receiving deposits
    address treasury;
    // Deployment chain ID: 8453 for Base or 10 for Optimism
    uint256 chainId;
    // Address of the local Hyperlane mailbox
    address mailbox;
    // Address of the Hyperlane post-dispatch hook
    address hook;
    // Address of the Hyperlane message verification module
    address interchainSecurityModule;
    // Address authorized to configure Hyperlane peers, hooks, and message verification
    address bridgeOwner;
  }

  // --- Constants ---

  /// @notice Address where legacy wrapped tokens are permanently retired
  /// @return _burnAddress The burn address
  // solhint-disable-next-line func-name-mixedcase
  function BURN_ADDRESS() external view returns (address _burnAddress);

  /// @notice Address of legacy haiVELO v1 on Optimism
  /// @return _legacyToken The legacy haiVELO v1 address
  // solhint-disable-next-line func-name-mixedcase
  function LEGACY_VELO_V1() external view returns (address _legacyToken);

  /// @notice Address of legacy haiVELO v2 on Optimism
  /// @return _legacyToken The legacy haiVELO v2 address
  // solhint-disable-next-line func-name-mixedcase
  function LEGACY_VELO_V2() external view returns (address _legacyToken);

  /// @notice Address of legacy haiAERO on Optimism
  /// @return _legacyToken The legacy haiAERO address
  // solhint-disable-next-line func-name-mixedcase
  function LEGACY_AERO_OPTIMISM() external view returns (address _legacyToken);

  // --- Registry ---

  /// @notice Address of the base token: AERO on Base or xAERO on Optimism
  /// @return _baseToken The base token contract
  // solhint-disable-next-line func-name-mixedcase
  function BASE_TOKEN() external view returns (IERC20 _baseToken);

  /// @notice Address of sAERO on Base, or the null address on Optimism
  /// @return _baseTokenNFT The base token NFT contract
  // solhint-disable-next-line func-name-mixedcase
  function BASE_TOKEN_NFT() external view returns (IAeroVotingEscrow _baseTokenNFT);

  /// @notice Address of the manager receiving deposits, set through modifyParameters by authorized accounts
  /// @return _treasury The deposit manager address
  function baseTokenManager() external view returns (address _treasury);

  // --- Data ---

  /// @notice Chain ID on which the wrapper was deployed
  /// @return _chainId The deployment chain ID
  function deploymentChainId() external view returns (uint256 _chainId);

  // --- Methods ---

  /**
   * @notice Deposit base tokens into the treasury and mint the same amount of wrapped tokens
   * @param _recipient Address of the account receiving the wrapped tokens
   * @param _amount Amount of base tokens being deposited [wad]
   * @dev   The treasury manages redemption and staking separately, without minting additional wrapped tokens
   */
  function deposit(address _recipient, uint256 _amount) external;

  /**
   * @notice Deposit sAERO NFTs into the treasury and mint their underlying principal on Base
   * @param _recipient Address of the account receiving the wrapped tokens
   * @param _tokenIds IDs of the sAERO NFTs being deposited
   * @dev   The sender must own each NFT. Deposits from the treasury and duplicate IDs within a batch are rejected
   * @dev   Both timed and permanent positions are accepted without changing their staking terms
   */
  function depositNFTs(address _recipient, uint256[] calldata _tokenIds) external;

  /**
   * @notice Retire legacy wrapped tokens and mint haiAERO v2 on Optimism
   * @param _source Address of legacy haiVELO v1, haiVELO v2, or haiAERO on Optimism
   * @param _amount Amount of legacy tokens being migrated [wad]
   * @param _minOut Minimum amount of wrapped tokens to mint [wad]
   * @param _recipient Address of the account receiving the wrapped tokens
   * @return _outputAmount Amount of wrapped tokens minted [wad]
   * @dev   Converts haiVELO at 44/1000 and haiAERO at 1:1. Rounds down and rejects zero output
   */
  function migrate(
    address _source,
    uint256 _amount,
    uint256 _minOut,
    address _recipient
  ) external returns (uint256 _outputAmount);

  /**
   * @notice Calculate the wrapped tokens received from a legacy migration on Optimism
   * @param _source Address of legacy haiVELO v1, haiVELO v2, or haiAERO on Optimism
   * @param _amount Amount of legacy tokens being migrated [wad]
   * @return _outputAmount Amount of wrapped tokens after rounding down [wad]
   */
  function previewMigration(address _source, uint256 _amount) external view returns (uint256 _outputAmount);

  // --- Administration ---

  /**
   * @notice Pause token deposits, NFT deposits, and legacy migration
   * @dev    Only authorized accounts can pause. Token transfers and bridging remain available
   */
  function pause() external;

  /**
   * @notice Unpause token deposits, NFT deposits, and legacy migration
   * @dev    Only authorized accounts can unpause on the deployment chain
   */
  function unpause() external;
}

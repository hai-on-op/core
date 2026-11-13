// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {HypERC20} from '@hyperlane-xyz/core/contracts/token/HypERC20.sol';
import {Math} from '@hyperlane-xyz/core/dependencies/@openzeppelin-contracts-4.9.3/contracts/utils/math/Math.sol';
import {PausableUpgradeable} from
  '@hyperlane-xyz/core/dependencies/@openzeppelin-contracts-upgradeable-4.9.3/contracts/security/PausableUpgradeable.sol';

import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';
import {IWrappedTokenV3} from '@interfaces/tokens/IWrappedTokenV3.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  WrappedTokenV3
 * @notice This contract represents haiAERO v2, allowing for deposits of AERO on Base, xAERO on Optimism,
 *         sAERO NFTs on Base, and migration of legacy wrapped tokens on Optimism
 * @dev    Deposited backing is held by the treasury. Wrapped tokens bridge through Hyperlane by burning and minting
 */
contract WrappedTokenV3 is
  HypERC20,
  PausableUpgradeable,
  ReentrancyGuard,
  EIP712,
  Nonces,
  Authorizable,
  Modifiable,
  IWrappedTokenV3
{
  using SafeERC20 for IERC20;
  using Encoding for bytes;
  using Assertions for address;

  // --- Constants ---

  /// @inheritdoc IWrappedTokenV3
  address public constant BURN_ADDRESS = address(0xdead);

  /// @inheritdoc IWrappedTokenV3
  address public constant LEGACY_VELO_V1 = 0x70f3713512089736661F928B291d1443C8b1BB6A;

  /// @inheritdoc IWrappedTokenV3
  address public constant LEGACY_VELO_V2 = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;

  /// @inheritdoc IWrappedTokenV3
  address public constant LEGACY_AERO_OPTIMISM = 0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152;

  bytes32 private constant _PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  // --- Registry ---

  /// @inheritdoc IWrappedTokenV3
  // solhint-disable-next-line var-name-mixedcase
  IERC20 public immutable override BASE_TOKEN;

  /// @inheritdoc IWrappedTokenV3
  // solhint-disable-next-line var-name-mixedcase
  IAeroVotingEscrow public immutable override BASE_TOKEN_NFT;

  /// @inheritdoc IWrappedTokenV3
  // solhint-disable-next-line defi-wonderland/immutable-name-snakecase
  uint256 public immutable override deploymentChainId;

  // --- Data ---

  /// @inheritdoc IWrappedTokenV3
  address public override baseTokenManager;

  // --- Init ---

  /**
   * @param  _config Configuration of the underlying token, treasury, chain, and Hyperlane route
   * @dev    Deploy directly with zero supply and local issuance paused. Initializers are disabled after construction
   */
  constructor(DeploymentConfig memory _config)
    HypERC20(18, 1, 1, _config.mailbox)
    EIP712('haiAEROV2', '1')
    Authorizable(msg.sender)
  {
    if (
      (_config.chainId != 10 && _config.chainId != 8453) || block.chainid != _config.chainId
        || localDomain != _config.chainId || _config.baseToken.code.length == 0
        || IERC20Metadata(_config.baseToken).decimals() != 18 || _config.treasury == address(0)
        || _config.treasury == address(this) || _config.bridgeOwner == address(0) || _config.bridgeOwner == address(this)
        || _config.bridgeOwner == BURN_ADDRESS
    ) revert WrappedTokenV3_InvalidConfiguration();
    if (_config.chainId == 8453) {
      if (_config.baseTokenNFT.code.length == 0 || IAeroVotingEscrow(_config.baseTokenNFT).TOKEN() != _config.baseToken)
      {
        revert WrappedTokenV3_InvalidConfiguration();
      }
    } else if (
      _config.baseTokenNFT != address(0) || _config.baseToken == LEGACY_VELO_V1 || _config.baseToken == LEGACY_VELO_V2
        || _config.baseToken == LEGACY_AERO_OPTIMISM
    ) {
      revert WrappedTokenV3_InvalidConfiguration();
    }

    BASE_TOKEN = IERC20(_config.baseToken);
    BASE_TOKEN_NFT = IAeroVotingEscrow(_config.baseTokenNFT);
    baseTokenManager = _config.treasury;
    deploymentChainId = _config.chainId;

    initialize(0, 'haiAEROV2', 'haiAERO', _config.hook, _config.interchainSecurityModule, _config.bridgeOwner);
    _disableInitializers();
    _pause();
  }

  // --- Modifiers ---

  /**
   * @notice Checks if the current chain matches the deployment chain
   */
  modifier correctChain() {
    if (block.chainid != deploymentChainId) revert WrappedTokenV3_WrongChain();
    _;
  }

  // --- Methods ---

  /// @inheritdoc IWrappedTokenV3
  function deposit(address _recipient, uint256 _amount) external override nonReentrant whenNotPaused correctChain {
    _checkRecipient(_recipient);
    if (_amount == 0) revert WrappedTokenV3_InvalidAmount();
    address _baseTokenManager = baseTokenManager;
    if (msg.sender == _baseTokenManager) revert WrappedTokenV3_TreasuryDeposit();

    uint256 _before = BASE_TOKEN.balanceOf(_baseTokenManager);
    BASE_TOKEN.safeTransferFrom(msg.sender, _baseTokenManager, _amount);
    if (BASE_TOKEN.balanceOf(_baseTokenManager) != _before + _amount) revert WrappedTokenV3_InexactTransfer();

    _mint(_recipient, _amount);

    emit WrappedTokenV3Deposit(msg.sender, _recipient, _amount);
  }

  /// @inheritdoc IWrappedTokenV3
  function depositNFTs(
    address _recipient,
    uint256[] calldata _tokenIds
  ) external override nonReentrant whenNotPaused correctChain {
    if (deploymentChainId != 8453) revert WrappedTokenV3_UnsupportedOperation();
    _checkRecipient(_recipient);
    address _baseTokenManager = baseTokenManager;
    if (msg.sender == _baseTokenManager) revert WrappedTokenV3_TreasuryDeposit();
    if (_tokenIds.length == 0) revert WrappedTokenV3_InvalidAmount();

    // Revert on duplicates
    for (uint256 _i; _i < _tokenIds.length - 1; ++_i) {
      for (uint256 _j = _i + 1; _j < _tokenIds.length; ++_j) {
        if (_tokenIds[_i] == _tokenIds[_j]) {
          revert WrappedTokenV3_DuplicateTokenIds();
        }
      }
    }

    for (uint256 _i; _i < _tokenIds.length; ++_i) {
      uint256 _id = _tokenIds[_i];
      if (BASE_TOKEN_NFT.ownerOf(_id) != msg.sender) revert WrappedTokenV3_NotNFTOwner();

      uint256 _principal = _readPrincipal(_id);

      BASE_TOKEN_NFT.safeTransferFrom(msg.sender, _baseTokenManager, _id);
      if (BASE_TOKEN_NFT.ownerOf(_id) != _baseTokenManager || _readPrincipal(_id) != _principal) {
        revert WrappedTokenV3_InexactTransfer();
      }

      _mint(_recipient, _principal);

      emit WrappedTokenV3NFTDeposit(msg.sender, _recipient, _id, _principal);
    }
  }

  /// @inheritdoc IWrappedTokenV3
  function previewMigration(
    address _source,
    uint256 _amount
  ) public view override correctChain returns (uint256 _outputAmount) {
    if (deploymentChainId != 10) revert WrappedTokenV3_UnsupportedOperation();
    if (_source == LEGACY_VELO_V1 || _source == LEGACY_VELO_V2) return Math.mulDiv(_amount, 44, 1000);
    if (_source == LEGACY_AERO_OPTIMISM) return _amount;
    revert WrappedTokenV3_UnsupportedSource();
  }

  /// @inheritdoc IWrappedTokenV3
  function migrate(
    address _source,
    uint256 _amount,
    uint256 _minOut,
    address _recipient
  ) external override nonReentrant whenNotPaused correctChain returns (uint256 _outputAmount) {
    _checkRecipient(_recipient);
    _outputAmount = previewMigration(_source, _amount);
    if (_outputAmount == 0) revert WrappedTokenV3_InvalidAmount();
    if (_outputAmount < _minOut) revert WrappedTokenV3_Slippage();

    IERC20 _legacy = IERC20(_source);
    uint256 _before = _legacy.balanceOf(BURN_ADDRESS);
    _legacy.safeTransferFrom(msg.sender, BURN_ADDRESS, _amount);
    if (_legacy.balanceOf(BURN_ADDRESS) != _before + _amount) revert WrappedTokenV3_InexactTransfer();

    _mint(_recipient, _outputAmount);

    emit WrappedTokenV3Migrate(msg.sender, _source, _recipient, _amount, _outputAmount);
  }

  // --- Administration ---

  /// @inheritdoc IWrappedTokenV3
  function pause() external override isAuthorized {
    _pause();
  }

  /// @inheritdoc IWrappedTokenV3
  function unpause() external override isAuthorized correctChain {
    _unpause();
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    if (_param == 'baseTokenManager') baseTokenManager = _data.toAddress();
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    baseTokenManager.assertNonNull();
  }

  // --- Overrides ---

  /// @inheritdoc IERC20Permit
  /// @dev Uses OpenZeppelin's EIP-2612 algorithm with HypERC20's allowance storage
  function permit(
    address _owner,
    address _spender,
    uint256 _value,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) public override {
    if (block.timestamp > _deadline) revert ERC2612ExpiredSignature(_deadline);

    bytes32 _structHash =
      keccak256(abi.encode(_PERMIT_TYPEHASH, _owner, _spender, _value, _useNonce(_owner), _deadline));
    address _signer = ECDSA.recover(_hashTypedDataV4(_structHash), _v, _r, _s);
    if (_signer != _owner) revert ERC2612InvalidSigner(_signer, _owner);

    _approve(_owner, _spender, _value);
  }

  /// @inheritdoc IERC20Permit
  function nonces(address _owner) public view override(Nonces, IERC20Permit) returns (uint256 _nonce) {
    return super.nonces(_owner);
  }

  /// @inheritdoc IERC20Permit
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view override returns (bytes32 _domainSeparator) {
    return _domainSeparatorV4();
  }

  // --- Internal Methods ---

  /**
   * @notice Read the underlying principal of an sAERO position
   * @param  _id ID of the sAERO NFT
   * @return _principal Amount of underlying AERO in the position [wad]
   */
  function _readPrincipal(uint256 _id) internal view returns (uint256 _principal) {
    IAeroVotingEscrow.StakedBalance memory _stake = BASE_TOKEN_NFT.staked(_id);
    if (_stake.amount == 0) revert WrappedTokenV3_UnsupportedStake(_id);
    return _stake.amount;
  }

  /**
   * @notice Check that wrapped tokens can be minted to the recipient
   * @param  _recipient Address of the account receiving the wrapped tokens
   */
  function _checkRecipient(address _recipient) internal view {
    if (_recipient == address(0) || _recipient == address(this) || _recipient == BURN_ADDRESS) {
      revert WrappedTokenV3_InvalidRecipient();
    }
  }
}

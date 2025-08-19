// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IVotingEscrow} from '@interfaces/external/IVotingEscrow.sol';

import {IWrappedToken} from '@interfaces/tokens/IWrappedToken.sol';
import {IWrappedTokenV2} from '@interfaces/tokens/IWrappedTokenV2.sol';

import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  WrappedTokenV2
 * @notice This contract represents v2 of the wrapped token, allowing for deposits in both
 *         velo and veVelo NFTs. (It is a one way wrap similar to wrapping crv for cvxCrv
 */
contract WrappedTokenV2 is ERC20, ERC20Permit, Authorizable, Modifiable, IWrappedTokenV2 {
  using SafeERC20 for IERC20;
  using Encoding for bytes;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IWrappedTokenV2
  // solhint-disable-next-line var-name-mixedcase
  IERC20 public immutable BASE_TOKEN;

  /// @inheritdoc IWrappedTokenV2
  // solhint-disable-next-line var-name-mixedcase
  IVotingEscrow public immutable BASE_TOKEN_NFT;

  /// @inheritdoc IWrappedTokenV2
  // solhint-disable-next-line var-name-mixedcase
  IWrappedToken public immutable WRAPPED_TOKEN_V1;

  /// @inheritdoc IWrappedTokenV2
  // solhint-disable-next-line var-name-mixedcase
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  // --- Registry ---

  /// @inheritdoc IWrappedTokenV2
  // solhint-disable-next-line private-vars-leading-underscore
  address public baseTokenManager;

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   * @param  _baseToken Address of the base token being wrapped
   * @param  _baseTokenNFT Address of the base token NFT being wrapped
   * @param  _baseTokenManager Address of the base token manager
   * @param  _wrappedTokenV1 Address of the wrapped token v1
   */
  constructor(
    string memory _name,
    string memory _symbol,
    address _baseToken,
    address _baseTokenNFT,
    address _baseTokenManager,
    address _wrappedTokenV1
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {
    if (_baseToken == address(0)) revert WrappedTokenV2_NullBaseToken();
    if (_baseTokenNFT == address(0)) {
      revert WrappedTokenV2_NullBaseTokenNFT();
    }
    if (_baseTokenManager == address(0)) {
      revert WrappedTokenV2_NullBaseTokenManager();
    }
    if (_wrappedTokenV1 == address(0)) {
      revert WrappedTokenV2_NullWrappedTokenV1();
    }
    BASE_TOKEN = IERC20(_baseToken);
    BASE_TOKEN_NFT = IVotingEscrow(_baseTokenNFT);
    baseTokenManager = _baseTokenManager;
    WRAPPED_TOKEN_V1 = IWrappedToken(_wrappedTokenV1);
  }

  /// @inheritdoc IWrappedTokenV2
  function deposit(address _account, uint256 _wad) external {
    if (_account == address(0)) revert WrappedTokenV2_NullReceiver();
    if (_wad == 0) revert WrappedTokenV2_NullAmount();

    BASE_TOKEN.safeTransferFrom(msg.sender, baseTokenManager, _wad);

    _mint(_account, _wad);

    emit WrappedTokenV2Deposit(_account, _wad);
  }

  /// @inheritdoc IWrappedTokenV2
  function depositNFTs(address _account, uint256[] memory _tokenIds) external {
    if (_account == address(0)) revert WrappedTokenV2_NullReceiver();
    if (_tokenIds.length == 0) revert WrappedTokenV2_EmptyTokenIds();

    // Revert on duplicates
    for (uint256 i = 0; i < _tokenIds.length - 1; i++) {
      for (uint256 j = i + 1; j < _tokenIds.length; j++) {
        if (_tokenIds[i] == _tokenIds[j]) {
          revert WrappedTokenV2_DuplicateTokenIds();
        }
      }
    }

    uint256 _balance = 0;

    uint256[] memory _tokenIdBalances = new uint256[](_tokenIds.length);

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      uint256 _b = uint256(uint128(BASE_TOKEN_NFT.locked(_tokenIds[i]).amount));
      _tokenIdBalances[i] = _b;
      _balance += _b;
    }

    if (_balance == 0) {
      revert WrappedTokenV2_BalanceIsZero();
    }

    _mint(_account, _balance);

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      BASE_TOKEN_NFT.safeTransferFrom(msg.sender, baseTokenManager, _tokenIds[i]);
      emit WrappedTokenV2NFTDeposit(_account, _tokenIds[i], _tokenIdBalances[i]);
    }
  }

  /// @inheritdoc IWrappedTokenV2
  function migrateV1toV2(address _account, uint256 _wad) external {
    if (_account == address(0)) revert WrappedTokenV2_NullReceiver();
    if (_wad == 0) revert WrappedTokenV2_NullAmount();

    WRAPPED_TOKEN_V1.transferFrom(msg.sender, BURN_ADDRESS, _wad);

    _mint(_account, _wad);

    emit WrappedTokenV2MigrateV1toV2(_account, _wad);
  }

  // --- Overrides ---

  function nonces(address _owner) public view override(ERC20Permit, IERC20Permit) returns (uint256 _nonce) {
    return super.nonces(_owner);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    if (_param == 'baseTokenManager') baseTokenManager = _data.toAddress();
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    baseTokenManager.assertNonNull();
  }
}

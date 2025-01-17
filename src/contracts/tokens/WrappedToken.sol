// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IWrappedToken} from '@interfaces/tokens/IWrappedToken.sol';

import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  WrappedToken
 * @notice This contract represents the wrapped version of a token to be used in the HAI protocol
 *         It is a one way wrap similar to wrapping crv for cvxCrv
 */
contract WrappedToken is ERC20, ERC20Permit, Authorizable, Modifiable, IWrappedToken {
  using SafeERC20 for IERC20;
  using Encoding for bytes;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IWrappedToken
  // solhint-disable-next-line var-name-mixedcase
  IERC20 public immutable BASE_TOKEN;

  // --- Registry ---

  /// @inheritdoc IWrappedToken
  // solhint-disable-next-line private-vars-leading-underscore
  address public baseTokenManager;

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   * @param  _baseToken Address of the base token being wrapped
   * @param  _baseTokenManager Address of the base token manager
   */
  constructor(
    string memory _name,
    string memory _symbol,
    address _baseToken,
    address _baseTokenManager
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {
    if (_baseToken == address(0)) revert WrappedToken_NullBaseToken();
    if (_baseTokenManager == address(0)) {
      revert WrappedToken_NullBaseTokenManager();
    }
    BASE_TOKEN = IERC20(_baseToken);
    baseTokenManager = _baseTokenManager;
  }

  /// @inheritdoc IWrappedToken
  function deposit(address _account, uint256 _wad) external {
    if (_account == address(0)) revert WrappedToken_NullReceiver();
    if (_wad == 0) revert WrappedToken_NullAmount();

    IERC20(BASE_TOKEN).safeTransferFrom(msg.sender, baseTokenManager, _wad);

    _mint(_account, _wad);

    emit WrappedTokenDeposit(_account, _wad);
  }

  // --- Overrides ---

  function nonces(address _owner) public view override(ERC20Permit, IERC20Permit) returns (uint256 _nonce) {
    return super.nonces(_owner);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    if (_param == 'baseTokenManager') {
      baseTokenManager = _address;
    } else {
      revert UnrecognizedParam();
    }
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    baseTokenManager.assertNonNull();
  }
}

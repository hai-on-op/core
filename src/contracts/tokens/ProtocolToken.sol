// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Pausable, Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {Time} from '@openzeppelin/contracts/utils/types/Time.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

/**
 * @title  ProtocolToken
 * @notice This contract represents the protocol ERC20Votes token to be used for governance purposes
 */
contract ProtocolToken is ERC20, ERC20Permit, ERC20Votes, ERC20Pausable, Authorizable, IProtocolToken {
  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   */
  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {
    _pause();
  }

  // --- Methods ---

  /// @inheritdoc IProtocolToken
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  /// @inheritdoc IProtocolToken
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  /// @inheritdoc IProtocolToken
  function unpause() external isAuthorized {
    _unpause();
  }

  // --- Overrides ---

  function _update(address _from, address _to, uint256 _value) internal override(ERC20, ERC20Votes, ERC20Pausable) {
    // Override ERC20Pausable when minting new tokens
    if (_from == address(0)) ERC20Votes._update(_from, _to, _value);
    else ERC20Pausable._update(_from, _to, _value);
  }

  function nonces(address _owner) public view override(ERC20Permit, IERC20Permit, Nonces) returns (uint256 _nonce) {
    return super.nonces(_owner);
  }

  /**
   * Set the clock to block timestamp, as opposed to the default block number.
   */
  function clock() public view override returns (uint48 _timestamp) {
    return Time.timestamp();
  }

  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual override returns (string memory _mode) {
    return 'mode=timestamp';
  }
}

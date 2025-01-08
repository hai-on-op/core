// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IStakingToken} from '@interfaces/tokens/IStakingToken.sol';

import {IStakingManager} from '@interfaces/tokens/IStakingManager.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import {ERC20Pausable, Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import {Time} from '@openzeppelin/contracts/utils/types/Time.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  StakingToken
 * @notice This contract represents the staked protocol ERC20Votes token
 *         ERC20Votes is to potentially support voting with staked tokens in the future
 */
contract StakingToken is
  ERC20,
  ERC20Permit,
  ERC20Votes,
  ERC20Burnable,
  ERC20Pausable,
  Authorizable,
  Modifiable,
  IStakingToken
{
  using Encoding for bytes;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IStakingToken
  IProtocolToken public protocolToken;

  /// @inheritdoc IStakingToken
  IStakingManager public stakingManager;

  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   * @param  _protocolToken Address of the protocol token
   */
  constructor(
    string memory _name,
    string memory _symbol,
    address _protocolToken
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {
    if (_protocolToken == address(0)) {
      revert StakingToken_NullProtocolToken();
    }
    protocolToken = IProtocolToken(_protocolToken);
    _pause();
  }

  // --- Methods ---

  /// @inheritdoc IStakingToken
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
    emit StakingTokenMint(_dst, _wad);
  }

  /// @inheritdoc IStakingToken
  function burn(uint256 _wad) public override(ERC20Burnable, IStakingToken) {
    _burn(msg.sender, _wad);
    emit StakingTokenBurn(msg.sender, _wad);
  }

  /// @inheritdoc IStakingToken
  function burnFrom(address _account, uint256 _wad) public override(ERC20Burnable, IStakingToken) {
    _spendAllowance(_account, msg.sender, _wad);
    _burn(_account, _wad);
  }

  /// @inheritdoc IStakingToken
  function unpause() external isAuthorized {
    _unpause();
    emit StakingTokenUnpause();
  }

  /// @inheritdoc IStakingToken
  function pause() external isAuthorized {
    _pause();
    emit StakingTokenPause();
  }

  // --- Overrides ---

  function _update(address _from, address _to, uint256 _value) internal override(ERC20, ERC20Votes, ERC20Pausable) {
    if (address(stakingManager) == address(0)) {
        revert StakingToken_NullStakingManager();
    }
    stakingManager.checkpoint([_from, _to]);
    super._update(_from, _to, _value);
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

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    // registry
    if (_param == 'stakingManager') {
      stakingManager = IStakingManager(_address);
    } else {
      revert UnrecognizedParam();
    }
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(stakingManager).assertHasCode();
  }
}

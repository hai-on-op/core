// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ISystemStakingToken} from '@interfaces/tokens/ISystemStakingToken.sol';

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

/**
 * @title  SystemStakingToken
 * @notice This contract represents the staked system coin
 */
contract SystemStakingToken is ERC20, ERC20Permit, ERC20Burnable, Authorizable, Modifiable, ISystemStakingToken {
  // --- Registry ---
  /// @inheritdoc ISystemStakingToken
  ISystemCoin public systemCoin;

  /// @inheritdoc ISystemStakingToken
  IStabilityPool public stabilityPool;

  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   * @param  _systemCoin Address of the system coin
   */
  constructor(
    string memory _name,
    string memory _symbol,
    address _systemCoin
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {
    if (_systemCoin == address(0)) {
      revert SystemStakingToken_NullSystemCoin();
    }
    systemCoin = ISystemCoin(_systemCoin);
  }

  // --- Methods ---

  /// @inheritdoc ISystemStakingToken
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
    emit SystemStakingTokenMint(_dst, _wad);
  }

  /// @inheritdoc ISystemStakingToken
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
    emit SystemStakingTokenBurn(msg.sender, _wad);
  }

  /// @inheritdoc ISystemStakingToken
  function burnFrom(address _account, uint256 _wad) external {
    _spendAllowance(_account, msg.sender, _wad);
    _burn(_account, _wad);
    emit SystemStakingTokenBurn(_account, _wad);
  }

  // --- Overrides ---

  function _update(address _from, address _to, uint256 _value) internal override(ERC20, ERC20Votes) {
    if (address(stabilityPool) == address(0)) {
      revert SystemStakingToken_NullStabilityPool();
    }

    if (_from != address(0) && _to != address(0)) {
      // Normal transger, settle rewards and move staked weight
      stabilityPool.onTokenTransfer(_from, _to, _value);
    } else {
      // Mint or burn, only checkpoint
      stabilityPool.checkpoint([_from, _to]);
    }
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
    if (_param == 'stabilityPool') {
      stabilityPool = IStabilityPool(_data.toAddress());
    } else {
      revert UnrecognizedParam();
    }
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(stabilityPool).assertHasCode();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IProtocolToken} from "@interfaces/tokens/IProtocolToken.sol";
import {IStakingToken} from "@interfaces/tokens/IStakingToken.sol";

import {IStakingManager} from "@interfaces/tokens/IStakingManager.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable, Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {Authorizable} from "@contracts/utils/Authorizable.sol";
import {Modifiable} from "@contracts/utils/Modifiable.sol";

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
        if (_protocolToken == address(0))
            revert StakingToken_NullProtocolToken();
        protocolToken = IProtocolToken(_protocolToken);
        _pause();
    }

    // --- Methods ---

    /// @inheritdoc IStakingToken
    function mint(address _dst, uint256 _wad) external isAuthorized {
        if (_dst == address(0)) revert StakingToken_MintToZeroAddress();
        _mint(_dst, _wad);
        emit StakingToken_Mint(_dst, _wad);
    }

    /// @inheritdoc IStakingToken
    function burn(uint256 _wad) external {
        if (_wad > balanceOf(msg.sender))
            revert StakingToken_InsufficientBalance();
        _burn(msg.sender, _wad);
        emit StakingToken_Burn(msg.sender, _wad);
    }

    /// @inheritdoc IStakingToken
    function unpause() external isAuthorized {
        _unpause();
        emit StakingToken_Unpause();
    }

    /// @inheritdoc IStakingToken
    function pause() external isAuthorized {
        _pause();
        emit StakingToken_Pause();
    }

    // --- Overrides ---

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _wad
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(_from, _to, _wad);
        if (address(stakingManager) == address(0))
            revert StakingToken_NullStakingManager();
        stakingManager.checkpoint([_from, _to]);
    }

    function _update(
        address _from,
        address _to,
        uint256 _value
    ) internal override(ERC20, ERC20Votes, ERC20Pausable) {
        super._update(_from, _to, _value);
    }

    function nonces(
        address _owner
    )
        public
        view
        override(ERC20Permit, IERC20Permit, Nonces)
        returns (uint256 _nonce)
    {
        return super.nonces(_owner);
    }

    /**
     * Set the clock to block timestamp, as opposed to the default block number.
     */
    function clock() public view override returns (uint48 _timestamp) {
        return Time.timestamp();
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE()
        public
        view
        virtual
        override
        returns (string memory _mode)
    {
        return "mode=timestamp";
    }

    // --- Administration ---

    /// @inheritdoc Modifiable
    function _modifyParameters(
        bytes32 _param,
        bytes memory _data
    ) internal override {
        address _address = _data.toAddress();
        // registry
        if (_param == "stakingManager") stakingManager = _address;
        else revert UnrecognizedParam();
    }

    /// @inheritdoc Modifiable
    function _validateParameters() internal view override {
        address(stakingManager).assertHasCode();
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable, Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

/**
 * @title HaiAeroMigrator
 * @notice Exchanges bearer legacy claims for prefunded new haiAERO. Never mints output.
 * @dev Surrendered inputs are nonrecoverable. Surplus output can return only to an immutable treasury while
 *      paused, preserving all current liabilities. Every exchange requires funding
 *      ALL current local economic liabilities, not just the caller's quote. Fresh legacy minting or bridge
 *      inflows therefore stop migration automatically until inventory and caps cover the increased claims.
 *      Base bridge custody is excluded because its liability lives in the Optimism synthetic supply.
 */
contract HaiAeroMigrator is Ownable2Step, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
  address public constant LEGACY_VELO_V1 = 0x70f3713512089736661F928B291d1443C8b1BB6A;
  address public constant LEGACY_VELO_V2 = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;
  address public constant LEGACY_AERO_BASE = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address public constant LEGACY_AERO_OPTIMISM = 0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152;
  address public constant LEGACY_BASE_BRIDGE = 0xD605046D24CdaD37Ca2Dff3aa8Ebf254CeEe86d5;

  struct Route {
    uint256 numerator;
    uint256 denominator;
    uint256 cap;
    uint256 migrated;
    address excludedCustody;
  }

  IERC20 public immutable outputToken;
  uint256 public immutable deploymentChainId;
  address public immutable treasury;
  mapping(address _token => Route _route) public routes;
  address[] private _sourceTokens;

  error InvalidConfiguration();
  error WrongChain();
  error UnsupportedSource();
  error InvalidAmount();
  error InvalidRecipient();
  error Slippage();
  error InexactTransfer();
  error InsufficientBacking(uint256 _inventory, uint256 _required);
  error CapsDoNotCoverLiabilities();
  error CapCannotDecrease();
  error InsufficientSurplus();

  event Migrated(
    address indexed account, address indexed token, address indexed recipient, uint256 inputAmount, uint256 outputAmount
  );
  event CapIncreased(address indexed token, uint256 previousCap, uint256 newCap);
  event SurplusWithdrawn(address indexed treasury, uint256 amount);

  /// @param _caps Source order on OP: haiVELO v1, haiVELO v2, legacy bridged haiAERO. Base: legacy haiAERO.
  constructor(
    address _outputToken,
    address _owner,
    uint256 _chainId,
    uint256[] memory _caps,
    address _treasury
  ) Ownable(_owner) {
    if (
      _outputToken.code.length == 0 || IERC20Metadata(_outputToken).decimals() != 18 || block.chainid != _chainId
        || _treasury == address(0) || _treasury == address(this) || _treasury == DEAD
    ) revert InvalidConfiguration();
    outputToken = IERC20(_outputToken);
    deploymentChainId = _chainId;
    treasury = _treasury;
    if (_chainId == 10 && _caps.length == 3) {
      _addRoute(LEGACY_VELO_V1, 44, 1000, _caps[0], address(0));
      _addRoute(LEGACY_VELO_V2, 44, 1000, _caps[1], address(0));
      _addRoute(LEGACY_AERO_OPTIMISM, 1, 1, _caps[2], address(0));
    } else if (_chainId == 8453 && _caps.length == 1) {
      if (LEGACY_BASE_BRIDGE.code.length == 0) revert InvalidConfiguration();
      _addRoute(LEGACY_AERO_BASE, 1, 1, _caps[0], LEGACY_BASE_BRIDGE);
    } else {
      revert InvalidConfiguration();
    }
    _pause();
  }

  function sourceTokens() external view returns (address[] memory) {
    return _sourceTokens;
  }

  /// @notice Unsurrendered source supply; dead v1 has already become v2 and must not be counted twice.
  function outstanding(address _token) public view returns (uint256 _amount) {
    Route memory _route = routes[_token];
    if (_route.denominator == 0) revert UnsupportedSource();
    IERC20 _source = IERC20(_token);
    _amount = _source.totalSupply() - _source.balanceOf(DEAD) - _source.balanceOf(address(this));
    if (_route.excludedCustody != address(0)) _amount -= _source.balanceOf(_route.excludedCustody);
  }

  function previewMigration(address _token, uint256 _amount) public view returns (uint256) {
    Route memory _route = routes[_token];
    if (_route.denominator == 0) revert UnsupportedSource();
    return Math.mulDiv(_amount, _route.numerator, _route.denominator);
  }

  /// @notice Conservative aggregate requirement, rounded UP per source; output quotes round DOWN.
  function readiness()
    public
    view
    returns (uint256 inventory, uint256 requiredOutput, bool capsCoverLiabilities, bool ready)
  {
    inventory = outputToken.balanceOf(address(this));
    capsCoverLiabilities = true;
    for (uint256 i; i < _sourceTokens.length; ++i) {
      address _token = _sourceTokens[i];
      Route memory _route = routes[_token];
      uint256 _outstanding = outstanding(_token);
      requiredOutput += Math.mulDiv(_outstanding, _route.numerator, _route.denominator, Math.Rounding.Ceil);
      if (_outstanding > _route.cap - _route.migrated) capsCoverLiabilities = false;
    }
    ready = !paused() && block.chainid == deploymentChainId && inventory >= requiredOutput && capsCoverLiabilities;
  }

  function migrate(
    address _token,
    uint256 _amount,
    uint256 _minOut,
    address _recipient
  ) external nonReentrant whenNotPaused returns (uint256 _outputAmount) {
    if (block.chainid != deploymentChainId) revert WrongChain();
    if (_recipient == address(0) || _recipient == address(this) || _recipient == DEAD) revert InvalidRecipient();
    if (_amount == 0) revert InvalidAmount();
    _outputAmount = previewMigration(_token, _amount);
    if (_outputAmount == 0) revert InvalidAmount();
    if (_outputAmount < _minOut) revert Slippage();
    _requireCovered();
    Route storage _route = routes[_token];
    if (_amount > _route.cap - _route.migrated) revert CapsDoNotCoverLiabilities();
    _route.migrated += _amount;
    IERC20 _source = IERC20(_token);
    uint256 _sourceBefore = _source.balanceOf(address(this));
    _source.safeTransferFrom(msg.sender, address(this), _amount);
    if (_source.balanceOf(address(this)) != _sourceBefore + _amount) revert InexactTransfer();
    uint256 _recipientBefore = outputToken.balanceOf(_recipient);
    uint256 _inventoryBefore = outputToken.balanceOf(address(this));
    outputToken.safeTransfer(_recipient, _outputAmount);
    if (
      outputToken.balanceOf(_recipient) != _recipientBefore + _outputAmount
        || outputToken.balanceOf(address(this)) != _inventoryBefore - _outputAmount
    ) revert InexactTransfer();
    // Catch callbacks or unusual token implementations that create liabilities during the exchange.
    _requireCovered();
    emit Migrated(msg.sender, _token, _recipient, _amount, _outputAmount);
  }

  function increaseCap(address _token, uint256 _newCap) external onlyOwner whenPaused {
    Route storage _route = routes[_token];
    if (_route.denominator == 0) revert UnsupportedSource();
    if (_newCap <= _route.cap) revert CapCannotDecrease();
    emit CapIncreased(_token, _route.cap, _newCap);
    _route.cap = _newCap;
  }

  function pause() external onlyOwner {
    _pause();
  }

  /// @notice Return unallocated inventory for treasury-managed cross-chain reserve rebalancing.
  /// @dev Never releases surrendered source tokens, and cannot reduce coverage of current local liabilities.
  function withdrawSurplus(uint256 _amount) external onlyOwner whenPaused nonReentrant {
    if (block.chainid != deploymentChainId) revert WrongChain();
    if (_amount == 0) revert InvalidAmount();
    _requireCovered();
    (uint256 _inventory, uint256 _required,,) = readiness();
    if (_amount > _inventory - _required) revert InsufficientSurplus();
    uint256 _recipientBefore = outputToken.balanceOf(treasury);
    outputToken.safeTransfer(treasury, _amount);
    if (
      outputToken.balanceOf(treasury) != _recipientBefore + _amount
        || outputToken.balanceOf(address(this)) != _inventory - _amount
    ) revert InexactTransfer();
    _requireCovered();
    emit SurplusWithdrawn(treasury, _amount);
  }

  function unpause() external onlyOwner {
    if (block.chainid != deploymentChainId) revert WrongChain();
    _requireCovered();
    _unpause();
  }

  function _requireCovered() internal view {
    (uint256 _inventory, uint256 _required, bool _capsCover,) = readiness();
    if (_inventory < _required) revert InsufficientBacking(_inventory, _required);
    if (!_capsCover) revert CapsDoNotCoverLiabilities();
  }

  function _addRoute(address _token, uint256 _num, uint256 _den, uint256 _cap, address _excluded) internal {
    if (_token == address(outputToken) || _token.code.length == 0 || IERC20Metadata(_token).decimals() != 18) {
      revert InvalidConfiguration();
    }
    routes[_token] = Route(_num, _den, _cap, 0, _excluded);
    _sourceTokens.push(_token);
  }
}

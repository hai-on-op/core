// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Ownable, Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {Pausable} from '@openzeppelin/contracts/utils/Pausable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';

/**
 * @title HaiAero
 * @notice One-way principal receipt for permanent sAERO held and managed by the treasury Safe.
 * @dev Matches legacy treasury custody: the Safe can vote, claim, transfer and migrate its backing NFTs.
 *      Issuance requires actual permanent principal received by that immutable treasury, and each tokenId
 *      is recognized once. There is no arbitrary-amount mint entry point. Safe custody remains a trust
 *      assumption: the Safe must never recycle already-issued principal through replacement NFT IDs.
 *      Recorded issuance is not proof that the Safe continues to hold unique backing positions.
 */
contract HaiAero is ERC20, ERC20Permit, Ownable2Step, Pausable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IERC20 public immutable BASE_TOKEN;
  IAeroVotingEscrow public immutable BASE_TOKEN_NFT;
  address public immutable voter;
  address public immutable treasury;
  uint256 public immutable deploymentChainId;

  /// @notice Principal recognized at issuance for each original sAERO tokenId, never reset on a transfer.
  mapping(uint256 _tokenId => uint256 _principal) public principalOf;
  /// @notice Cumulative recognized principal, not a live custody or solvency assertion.
  uint256 public totalIssuedPrincipal;
  uint256[] private _backingTokenIds;

  error InvalidConfiguration();
  error WrongChain();
  error InvalidAmount();
  error InvalidRecipient();
  error UnsupportedStake(uint256 _tokenId);
  error AlreadyDeposited(uint256 _tokenId);
  error InexactTransfer();
  error NotNFTOwner();

  event Deposited(address indexed account, address indexed recipient, uint256 indexed tokenId, uint256 principal);

  constructor(
    address _aero,
    address _sAero,
    address _owner,
    address _treasury,
    uint256 _chainId
  ) ERC20('haiAERO', 'haiAERO') ERC20Permit('haiAERO') Ownable(_owner) {
    if (
      _aero.code.length == 0 || _sAero.code.length == 0 || _treasury.code.length == 0 || _treasury == address(this)
        || IERC20Metadata(_aero).decimals() != 18 || block.chainid != _chainId
    ) revert InvalidConfiguration();
    IAeroVotingEscrow _escrow = IAeroVotingEscrow(_sAero);
    address _voter = _escrow.VOTER();
    if (_escrow.TOKEN() != _aero || _voter.code.length == 0) revert InvalidConfiguration();
    BASE_TOKEN = IERC20(_aero);
    BASE_TOKEN_NFT = _escrow;
    voter = _voter;
    treasury = _treasury;
    deploymentChainId = _chainId;
    _pause();
  }

  modifier correctChain() {
    if (block.chainid != deploymentChainId) revert WrongChain();
    _;
  }

  /// @notice Create a permanent stake, transfer it to the Safe, then issue the exact new principal.
  function deposit(address _recipient, uint256 _amount) external nonReentrant whenNotPaused correctChain {
    _checkRecipient(_recipient);
    if (_amount == 0 || _amount > uint256(uint128(type(int128).max))) revert InvalidAmount();
    uint256 _before = BASE_TOKEN.balanceOf(address(this));
    BASE_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
    if (BASE_TOKEN.balanceOf(address(this)) != _before + _amount) revert InexactTransfer();
    BASE_TOKEN.forceApprove(address(BASE_TOKEN_NFT), _amount);
    uint256 _id = BASE_TOKEN_NFT.createStake(uint128(_amount), 0, true);
    BASE_TOKEN.forceApprove(address(BASE_TOKEN_NFT), 0);
    if (BASE_TOKEN.balanceOf(address(this)) != _before || _readPrincipal(_id, address(this)) != _amount) {
      revert InexactTransfer();
    }
    BASE_TOKEN_NFT.safeTransferFrom(address(this), treasury, _id);
    if (_readPrincipal(_id, treasury) != _amount) revert InexactTransfer();
    _recordDeposit(_id, _amount, _recipient);
  }

  /// @notice Transfer caller-owned permanent sAERO to treasury and issue its principal once.
  /// @dev Treasury can deliberately recognize its own migrated NFTs without a self-transfer or NFT approval.
  ///      Other callers cannot recognize treasury assets or another account's preapproved NFTs.
  function depositNFTs(
    address _recipient,
    uint256[] calldata _tokenIds
  ) external nonReentrant whenNotPaused correctChain {
    _checkRecipient(_recipient);
    if (_tokenIds.length == 0) revert InvalidAmount();
    for (uint256 i; i < _tokenIds.length; ++i) {
      uint256 _id = _tokenIds[i];
      if (principalOf[_id] != 0) revert AlreadyDeposited(_id);
      if (BASE_TOKEN_NFT.ownerOf(_id) != msg.sender) revert NotNFTOwner();
      uint256 _principal = _readPrincipal(_id, msg.sender);
      if (msg.sender != treasury) BASE_TOKEN_NFT.safeTransferFrom(msg.sender, treasury, _id);
      if (_readPrincipal(_id, treasury) != _principal) revert InexactTransfer();
      _recordDeposit(_id, _principal, _recipient);
    }
  }

  /// @notice Original recognized NFT IDs; treasury may subsequently transfer or migrate these positions.
  function backingTokenIds() external view returns (uint256[] memory) {
    return _backingTokenIds;
  }

  /// @notice Current original principal still held permanently by treasury; zero if moved, burned or downgraded.
  function backingOf(uint256 _id) public view returns (uint256) {
    if (principalOf[_id] == 0) return 0;
    try BASE_TOKEN_NFT.ownerOf(_id) returns (address _owner) {
      if (_owner != treasury) return 0;
    } catch {
      return 0;
    }
    IAeroVotingEscrow.StakedBalance memory _stake = BASE_TOKEN_NFT.staked(_id);
    return _stake.isPermanent && _stake.end == 0 ? _stake.amount : 0;
  }

  function backingStatus(uint256 _id)
    external
    view
    returns (uint256 recordedPrincipal, uint256 livePrincipal, bool inTreasury)
  {
    recordedPrincipal = principalOf[_id];
    livePrincipal = backingOf(_id);
    try BASE_TOKEN_NFT.ownerOf(_id) returns (address _owner) {
      inTreasury = _owner == treasury;
    } catch {}
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner correctChain {
    _unpause();
  }

  function _checkRecipient(address _recipient) internal view {
    if (_recipient == address(0) || _recipient == address(this)) revert InvalidRecipient();
  }

  function _readPrincipal(uint256 _id, address _owner) internal view returns (uint256) {
    IAeroVotingEscrow.StakedBalance memory _stake = BASE_TOKEN_NFT.staked(_id);
    if (BASE_TOKEN_NFT.ownerOf(_id) != _owner || !_stake.isPermanent || _stake.end != 0 || _stake.amount == 0) {
      revert UnsupportedStake(_id);
    }
    return _stake.amount;
  }

  function _recordDeposit(uint256 _id, uint256 _amount, address _recipient) internal {
    if (principalOf[_id] != 0) revert AlreadyDeposited(_id);
    principalOf[_id] = _amount;
    _backingTokenIds.push(_id);
    totalIssuedPrincipal += _amount;
    _mint(_recipient, _amount);
    emit Deposited(msg.sender, _recipient, _id, _amount);
  }
}

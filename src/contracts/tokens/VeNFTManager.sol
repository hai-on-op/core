// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {IVeNFTManager} from '@interfaces/tokens/IVeNFTManager.sol';

import {IVoter} from '@interfaces/external/IVoter.sol';
import {IVotingEscrow} from '@interfaces/external/IVotingEscrow.sol';
import {IRootVotingRewardsFactory} from '@interfaces/external/IRootVotingRewardsFactory.sol';
import {IRewardsDistributor} from '@interfaces/external/IRewardsDistributor.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Encoding} from '@libraries/Encoding.sol';

/**
 * @title  VeNFTManager
 * @notice This contract is used to the protocol veNFTs
 */
contract VeNFTManager is Authorizable, IVeNFTManager, IERC721Receiver {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.UintSet;
  using Encoding for bytes;

  // --- Constants / Immutable ---

  /// @inheritdoc IVeNFTManager
  // solhint-disable-next-line var-name-mixedcase
  address public immutable WETH = 0x4200000000000000000000000000000000000006;

  /// @inheritdoc IVeNFTManager
  // solhint-disable-next-line var-name-mixedcase
  IVotingEscrow public immutable VE_NFT;

  // --- Registry ---

  /// @inheritdoc IVeNFTManager
  IVoter public voter;

  /// @inheritdoc IVeNFTManager
  IRootVotingRewardsFactory public rootVotingRewardsFactory;

  /// @inheritdoc IVeNFTManager
  address public rootMessageBridge;

  /// @inheritdoc IVeNFTManager
  IRewardsDistributor public rewardsDistributor;

  // --- Data ---

  /// @inheritdoc IVeNFTManager
  address public secondaryManager;

  /// @inheritdoc IVeNFTManager
  address public tertiaryManager;

  EnumerableSet.UintSet internal managedTokenIds;

  // --- Modifiers ---

  /**
   * @notice Checks if the sender is the secondary manager
   */
  modifier onlySecondary() {
    if (msg.sender != secondaryManager) {
      revert VeNFTManager_NotSecondaryManager();
    }
    _;
  }

  /**
   * @notice Checks if the sender is the tertiary manager
   */
  modifier onlyTertiary() {
    if (msg.sender != tertiaryManager) {
      revert VeNFTManager_NotTertiaryManager();
    }
    _;
  }

  /**
   * @notice Checks if the sender is the secondary or tertiary manager
   */
  modifier onlySecondaryOrTertiary() {
    if (msg.sender != secondaryManager && msg.sender != tertiaryManager) {
      revert VeNFTManager_NotSecondaryOrTertiaryManager();
    }
    _;
  }

  // --- Init ---

  /**
   * @param  _secondaryManager Address of the secondarymanager (Gnosis Safe)
   * @param  _tertiaryManager Address of the tertiary manager (EOA or contract)
   * @param  _veNFT Address of the veNFT contract
   * @param  _voter Address of the voter contract
   * @param  _rootVotingRewardsFactory Address of the root voting rewards factory contract
   * @param  _rootMessageBridge Address of the root message bridge contract
   * @param  _rewardsDistributor Address of the rewards distributor contract
   */
  constructor(
    address _secondaryManager,
    address _tertiaryManager,
    address _veNFT,
    address _voter,
    address _rootVotingRewardsFactory,
    address _rootMessageBridge,
    address _rewardsDistributor
  ) Authorizable(msg.sender) {
    if (_secondaryManager == address(0)) {
      revert VeNFTManager_NullSecondaryManager();
    }
    if (_tertiaryManager == address(0)) {
      revert VeNFTManager_NullTertiaryManager();
    }
    if (_veNFT == address(0)) {
      revert VeNFTManager_NullVeNFT();
    }
    if (_voter == address(0)) {
      revert VeNFTManager_NullVoter();
    }
    if (_rootVotingRewardsFactory == address(0)) {
      revert VeNFTManager_NullRootVotingRewardsFactory();
    }
    if (_rootMessageBridge == address(0)) {
      revert VeNFTManager_NullRootMessageBridge();
    }
    if (_rewardsDistributor == address(0)) {
      revert VeNFTManager_NullRewardsDistributor();
    }

    secondaryManager = _secondaryManager;
    tertiaryManager = _tertiaryManager;
    VE_NFT = IVotingEscrow(_veNFT);
    voter = IVoter(_voter);
    rootVotingRewardsFactory = IRootVotingRewardsFactory(_rootVotingRewardsFactory);
    rootMessageBridge = _rootMessageBridge;
    rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
  }

  // -- - Methods ---

  /// @inheritdoc IVeNFTManager
  function depositVeNFTs(uint256[] memory _tokenIds) external onlySecondary {
    if (_tokenIds.length == 0) revert VeNFTManager_EmptyTokenIds();

    // Revert on duplicates
    for (uint256 i = 0; i < _tokenIds.length - 1; i++) {
      for (uint256 j = i + 1; j < _tokenIds.length; j++) {
        if (_tokenIds[i] == _tokenIds[j]) {
          revert VeNFTManager_DuplicateTokenIds();
        }
      }
    }

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      VE_NFT.safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
      managedTokenIds.add(_tokenIds[i]);
      emit VeNFTManagerVeNFTDeposit(_tokenIds[i]);
    }
  }

  /// @inheritdoc IVeNFTManager
  function transferVeNFTs(address _account, uint256[] memory _tokenIds) external isAuthorized {
    if (_account == address(0)) {
      revert VeNFTManager_NullReceiver();
    }
    if (_tokenIds.length == 0) revert VeNFTManager_EmptyTokenIds();

    // Revert on duplicates
    for (uint256 i = 0; i < _tokenIds.length - 1; i++) {
      for (uint256 j = i + 1; j < _tokenIds.length; j++) {
        if (_tokenIds[i] == _tokenIds[j]) {
          revert VeNFTManager_DuplicateTokenIds();
        }
      }
    }

    for (uint256 i = 0; i < _tokenIds.length; i++) {
      VE_NFT.safeTransferFrom(address(this), _account, _tokenIds[i]);
      managedTokenIds.remove(_tokenIds[i]);
      emit VeNFTManagerVeNFTTransfer(_account, _tokenIds[i]);
    }
  }

  /// @inheritdoc IVeNFTManager
  function vote(
    uint256 _tokenId,
    address[] memory _poolVote,
    uint256[] memory _weights
  ) external onlySecondaryOrTertiary {
    if (_tokenId == 0) revert VeNFTManager_NullTokenId();
    if (_poolVote.length == 0) revert VeNFTManager_EmptyPoolVote();
    if (_weights.length == 0) revert VeNFTManager_EmptyWeights();
    if (_poolVote.length != _weights.length) {
      revert VeNFTManager_UnequalLengths();
    }

    voter.vote(_tokenId, _poolVote, _weights);

    emit VeNFTManagerVote(_tokenId, _poolVote, _weights);
  }

  /// @inheritdoc IVeNFTManager
  function claimBribes(
    address[] memory _bribes,
    address[][] memory _tokens,
    uint256 _tokenId
  ) external onlySecondaryOrTertiary {
    if (_tokenId == 0) revert VeNFTManager_NullTokenId();
    if (_bribes.length == 0) revert VeNFTManager_EmptyBribes();
    if (_tokens.length == 0) revert VeNFTManager_EmptyTokens();
    if (_bribes.length != _tokens.length) {
      revert VeNFTManager_UnequalLengths();
    }

    voter.claimBribes(_bribes, _tokens, _tokenId);

    emit VeNFTManagerBribeClaim(_bribes, _tokens, _tokenId);
  }

  /// @inheritdoc IVeNFTManager
  function claimFees(
    address[] memory _fees,
    address[][] memory _tokens,
    uint256 _tokenId
  ) external onlySecondaryOrTertiary {
    if (_tokenId == 0) revert VeNFTManager_NullTokenId();
    if (_fees.length == 0) revert VeNFTManager_EmptyFees();
    if (_tokens.length == 0) revert VeNFTManager_EmptyTokens();
    if (_fees.length != _tokens.length) {
      revert VeNFTManager_UnequalLengths();
    }

    voter.claimFees(_fees, _tokens, _tokenId);

    emit VeNFTManagerFeeClaim(_fees, _tokens, _tokenId);
  }

  /// @inheritdoc IVeNFTManager
  function claimAndLockRebases(uint256[] memory _tokenIds) external onlySecondaryOrTertiary {
    if (_tokenIds.length == 0) revert VeNFTManager_EmptyTokenIds();
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      rewardsDistributor.claim(_tokenIds[i]);
      emit VeNFTManagerRebaseClaimAndLock(_tokenIds[i]);
    }
  }

  /// @inheritdoc IVeNFTManager
  function setSuperchainRecipient(uint256 _chainId, address _recipient) external onlySecondaryOrTertiary {
    if (_chainId == 0) revert VeNFTManager_NullChainId();
    if (_recipient == address(0)) {
      revert VeNFTManager_NullRecipient();
    }
    rootVotingRewardsFactory.setRecipient(_chainId, _recipient);
    emit VeNFTManagerSuperchainRecipientSet(_chainId, _recipient);
  }

  /// @inheritdoc IVeNFTManager
  function setTertiary(address _account) external onlySecondary {
    if (_account == address(0)) {
      revert VeNFTManager_NullTertiaryManager();
    }
    tertiaryManager = _account;
    emit VeNFTManagerTertiaryManagerSet(_account);
  }

  /// @inheritdoc IVeNFTManager
  function setSecondary(address _account) external isAuthorized {
    if (_account == address(0)) {
      revert VeNFTManager_NullSecondaryManager();
    }
    secondaryManager = _account;
    emit VeNFTManagerSecondaryManagerSet(_account);
  }

  /// @inheritdoc IVeNFTManager
  function approveSuperchainGasAllowance() external onlySecondaryOrTertiary {
    IERC20(WETH).approve(rootMessageBridge, 10_000_000_000_000_000);
    emit VeNFTManagerSuperchainGasAllowanceApproved();
  }

  /// @inheritdoc IVeNFTManager
  function withdrawVotingRewards(address _account, address[] memory _tokens) external onlySecondaryOrTertiary {
    if (_account == address(0)) {
      revert VeNFTManager_NullReceiver();
    }
    if (_tokens.length == 0) revert VeNFTManager_EmptyTokens();
    for (uint256 _i = 0; _i < _tokens.length; _i++) {
      address _token = _tokens[_i];
      uint256 _balance = IERC20(_token).balanceOf(address(this));
      if (_balance == 0) {
        revert VeNFTManager_TokenBalanceIsZero();
      }
      IERC20(_token).transfer(_account, _balance);
      emit VeNFTManagerTokenWithdrawn(_account, _token, _balance);
    }
  }

  /// @inheritdoc IVeNFTManager
  function getManagedTokenIds() external view returns (uint256[] memory _ids) {
    uint256 _len = managedTokenIds.length();
    _ids = new uint256[](_len);
    for (uint256 i = 0; i < _len; i++) {
      _ids[i] = managedTokenIds.at(i);
    }
  }

  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}

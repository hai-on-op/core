// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

import {IVotingEscrow} from '@interfaces/external/IVotingEscrow.sol';
import {IVoter} from '@interfaces/external/IVoter.sol';
import {IRootVotingRewardsFactory} from '@interfaces/external/IRootVotingRewardsFactory.sol';
import {IRewardsDistributor} from '@interfaces/external/IRewardsDistributor.sol';

interface IVeNFTManager is IAuthorizable {
  // --- Events ---

  /// @notice Emitted when veNFTs are transferred out of the veNFTManager
  /// @param _account Address of the account receiving the veNFTs
  /// @param _tokenId ID of the veNFT being transferred
  event VeNFTManagerVeNFTTransfer(address indexed _account, uint256 _tokenId);

  /// @notice Emitted when veNFTs are deposited into the veNFTManager
  /// @param _tokenId ID of the veNFT being transferred
  event VeNFTManagerVeNFTDeposit(uint256 _tokenId);

  /// @notice Emitted when a token is withdrawn from the veNFTManager
  /// @param _account Address of the account receiving the token
  /// @param _token Address of the token being withdrawn
  /// @param _balance Amount of the token being withdrawn
  event VeNFTManagerTokenWithdrawn(address indexed _account, address indexed _token, uint256 _balance);

  /// @notice Emitted when the superchain recipient is set for a given chain
  /// @param _chainId Chain id
  /// @param _recipient Address of the recipient
  event VeNFTManagerSuperchainRecipientSet(uint256 _chainId, address _recipient);

  /// @notice Emitted when the tertiary manager is set
  /// @param _account Address of the tertiary manager
  event VeNFTManagerTertiaryManagerSet(address indexed _account);

  /// @notice Emitted when the secondary manager is set
  /// @param _account Address of the secondary manager
  event VeNFTManagerSecondaryManagerSet(address indexed _account);

  /// @notice Emitted when a veNFT is voted with
  /// @param _tokenId Id of veNFT that you wish to vote with.
  /// @param _poolVote Array of pools that you wish to vote for.
  /// @param _weights Array of weights for the pools.
  event VeNFTManagerVote(uint256 _tokenId, address[] _poolVote, uint256[] _weights);

  /// @notice Emitted when bribes are claimed for a given veNFT
  /// @param _bribes Array of BribeVotingReward contracts to collect from.
  /// @param _tokens Array of tokens that are used as bribes.
  /// @param _tokenId Id of veNFT that you wish to claim bribes for.
  event VeNFTManagerBribeClaim(address[] _bribes, address[][] _tokens, uint256 _tokenId);

  /// @notice Emitted when fees are claimed for a given veNFT
  /// @param _fees Array of FeesVotingReward contracts to collect from.
  /// @param _tokens Array of tokens that are used as fees.
  /// @param _tokenId Id of veNFT that you wish to claim fees for.
  event VeNFTManagerFeeClaim(address[] _fees, address[][] _tokens, uint256 _tokenId);

  /// @notice Emitted when superchain gas allowance is approved
  event VeNFTManagerSuperchainGasAllowanceApproved();

  /// @notice Emitted when rebases are claimed and locked for a given veNFT
  /// @param _tokenId Id of veNFT being claimed and locked.
  event VeNFTManagerRebaseClaimAndLock(uint256 _tokenId);

  // --- Errors ---

  /// @notice Throws when trying to set a null secondary manager
  error VeNFTManager_NullSecondaryManager();

  /// @notice Throws when trying to set a null tertiary manager
  error VeNFTManager_NullTertiaryManager();

  /// @notice Throws when trying to set a null veNFT
  error VeNFTManager_NullVeNFT();

  /// @notice Throws when trying to set a null voter
  error VeNFTManager_NullVoter();

  /// @notice Throws when trying to set a null root voting rewards factory
  error VeNFTManager_NullRootVotingRewardsFactory();

  /// @notice Throws when trying to set a null root message bridge
  error VeNFTManager_NullRootMessageBridge();

  /// @notice Throws when trying to set a null rewards distributor
  error VeNFTManager_NullRewardsDistributor();

  /// @notice Throws when trying to transfer to a null receiver
  error VeNFTManager_NullReceiver();

  /// @notice Throws when trying to transfer an empty array of token ids
  error VeNFTManager_EmptyTokenIds();

  /// @notice Throws when trying to call a function not allowed by the secondary manager
  error VeNFTManager_NotSecondaryManager();

  /// @notice Throws when trying to call a function not allowed by the tertiary manager
  error VeNFTManager_NotTertiaryManager();

  /// @notice Throws when trying to call a function not allowed by the DAO
  error VeNFTManager_NotSecondaryOrTertiaryManager();

  /// @notice Throws when trying to transfer duplicate token ids
  error VeNFTManager_DuplicateTokenIds();

  /// @notice Throws when trying to transfer an empty array of tokens
  error VeNFTManager_EmptyTokens();

  /// @notice Throws when trying to claim bribes with an empty array of bribes
  error VeNFTManager_EmptyBribes();

  /// @notice Throws when trying to claim fees with an empty array of fees
  error VeNFTManager_EmptyFees();

  /// @notice Throws when trying to transfer a token with a balance of 0
  error VeNFTManager_TokenBalanceIsZero();

  /// @notice Throws when trying to vote with an empty array of pools
  error VeNFTManager_EmptyPoolVote();

  /// @notice Throws when trying to vote with an empty array of weights
  error VeNFTManager_EmptyWeights();

  /// @notice Throws when trying to vote with an empty array of pools
  error VeNFTManager_UnequalLengths();

  /// @notice Throws when trying to vote with a null token id
  error VeNFTManager_NullTokenId();

  /// @notice Throws when trying to set a null recipient
  error VeNFTManager_NullRecipient();

  /// @notice Throws when trying to set a null chain id
  error VeNFTManager_NullChainId();

  // --- Registry ---

  /**
   * @notice Address of the voter contract
   * @return _voter Address of the voter contract
   */
  function voter() external view returns (IVoter _voter);

  /**
   * @notice Address of the root voting rewards contract
   * @return _rootVotingRewardsFactory Address of the root voting rewards contract
   */
  function rootVotingRewardsFactory() external view returns (IRootVotingRewardsFactory _rootVotingRewardsFactory);

  /**
   * @notice Address of the root message bridge contract
   * @return _rootMessageBridge Address of the root message bridge contract
   */
  function rootMessageBridge() external view returns (address _rootMessageBridge);

  /**
   * @notice Address of the rewards distributor contract
   * @return _rewardsDistributor Address of the rewards distributor contract
   */
  function rewardsDistributor() external view returns (IRewardsDistributor _rewardsDistributor);

  /**
   * @notice Address of the WETH token
   * @return _weth Address of the WETH token
   */
  function WETH() external view returns (address _weth);

  /**
   * @notice Address of the veNFT token
   * @return _veNFT Address of the veNFT token
   */
  function VE_NFT() external view returns (IVotingEscrow _veNFT);

  /**
   * @notice Address of the secondary manager contract (Gnosis Safe)
   * @return _secondaryManager Address of the secondary manager
   */
  function secondaryManager() external view returns (address _secondaryManager);

  /**
   * @notice Address of the tertiary manager (EOA or contract)
   * @return _tertiaryManager Address of the tertiary manager
   */
  function tertiaryManager() external view returns (address _tertiaryManager);

  // -- - Methods ---

  /**
   * @notice Deposit veNFTs
   * Called by secondary to deposit veNFTs once they reach 500k VELO locked
   * @param _tokenIds Array of token ids being deposited
   */
  function depositVeNFTs(uint256[] memory _tokenIds) external;

  /**
   * @notice Transfer veNFTs
   * Called by DAO to transfer veNFTs out of the veNFTManager
   * @param _account Address of the account receiving the veNFTs
   * @param _tokenIds Array of token ids being transferred
   */
  function transferVeNFTs(address _account, uint256[] memory _tokenIds) external;

  /**
   * @notice Vote with veNFTs
   * Called by secondary or tertiary to vote with veNFTs
   * @param _tokenId Id of veNFT that you wish to vote with.
   * @param _poolVote Array of pools that you wish to vote for.
   * @param _weights Array of weights for the pools.
   */
  function vote(uint256 _tokenId, address[] memory _poolVote, uint256[] memory _weights) external;

  /**
   * @notice Claim bribes for a given veNFT
   * Called by secondary or tertiary to claim bribes
   * Voting rewards (bribes) claimed and go to the following:
   * 1. If voting is for superchain voting rewards, they go to the superchain recipient
   * 2. If voting is for native chain voting rewards, they go to this contract
   *    and must be withdrawn by calling withdrawVotingRewards
   * @param _bribes Array of BribeVotingReward contracts to collect from.
   * @param _tokens Array of tokens that are used as bribes.
   * @param _tokenId Id of veNFT that you wish to claim bribes for.
   */
  function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external;

  /**
   * @notice Claim fees for a given veNFT
   * Called by secondary or tertiary to claim fees
   * Voting rewards (fees) claimed and go to the following:
   * 1. If voting is for superchain voting rewards, they go to the superchain recipient
   * 2. If voting is for native chain voting rewards, they go to this contract
   *    and must be withdrawn by calling withdrawVotingRewards
   * @param _fees Array of FeesVotingReward contracts to collect from.
   * @param _tokens Array of tokens that are used as fees.
   * @param _tokenId Id of veNFT that you wish to claim fees for.
   */
  function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external;

  /**
   * @notice Claim and lock rebases
   * Called by secondary or tertiary to claim and lock rebases
   * @param _tokenIds Array of token ids being claimed and locked
   */
  function claimAndLockRebases(uint256[] memory _tokenIds) external;

  /**
   * @notice Sets the recipient of the rewards for a given user and chain
   * Called by secondary or tertiary to set the superchain recipient
   * for superchain voting rewards
   * @param _chainId Chain id
   * @param _recipient Address of the recipient
   */
  function setSuperchainRecipient(uint256 _chainId, address _recipient) external;

  /**
   * @notice Set tertiary
   * Called by secondary manager to set the tertiary manager
   * @param _account Address of the tertiary manager
   */
  function setTertiary(address _account) external;

  /**
   * @notice Set secondary
   * Called by DAO to set the secondary manager
   * @param _account Address of the secondary manager
   */
  function setSecondary(address _account) external;

  /**
   * @notice Approve superchain gas allowance
   * Called by secondary or tertiary manager to approve the superchain gas allowance
   */
  function approveSuperchainGasAllowance() external;

  /**
   * @notice Withdraw voting rewards
   * Called by secondary or tertiary manager to withdraw OP mainnet voting rewards
   * Withdraw native chain rewards from voting (these are recieved on mainnet OP by calling claimBribes)
   * Native chain rewards are claimed differently than superchain rewards
   * @param _account Address of the account receiving the voting rewards
   * @param _tokens Array of tokens being withdrawn
   */
  function withdrawVotingRewards(address _account, address[] memory _tokens) external;

  /**
   * @notice Get the token ids of the managed veNFTs
   * @return _ids Array of token ids of the managed veNFTs
   */
  function getManagedTokenIds() external view returns (uint256[] memory _ids);
}

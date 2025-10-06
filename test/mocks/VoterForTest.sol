// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IVoter} from '@interfaces/external/IVoter.sol';

contract VoterForTest is IVoter {
  constructor() {}

  /// @inheritdoc IVoter
  function vote(uint256 _tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external {}

  function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint256 _tokenId) external {}

  function claimFees(address[] memory _fees, address[][] memory _tokens, uint256 _tokenId) external {}
}

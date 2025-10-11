pragma solidity ^0.8.20;

import {IRootVotingRewardsFactory} from '@interfaces/external/IRootVotingRewardsFactory.sol';

contract RootVotingRewardsFactoryForTest is IRootVotingRewardsFactory {
  mapping(address => mapping(uint256 => address)) public recipient;

  constructor() {}

  function setRecipient(uint256 _chainId, address _recipient) external {
    recipient[msg.sender][_chainId] = _recipient;
    emit RecipientSet(msg.sender, _chainId, _recipient);
  }
}

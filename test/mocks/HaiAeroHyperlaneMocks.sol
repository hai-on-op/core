// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMessageRecipient} from '@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol';

/// @dev Local message transport only. Does not model validator signatures, relayers or production ISM verification.
contract HaiAeroMailboxMock {
  // solhint-disable-next-line defi-wonderland/immutable-name-snakecase
  uint32 public immutable localDomain;

  uint32 public lastDestination;
  bytes32 public lastRecipient;
  address public lastSender;
  bytes public lastBody;
  uint256 public nonce;

  constructor(uint32 _domain) {
    localDomain = _domain;
  }

  function dispatch(
    uint32 _destination,
    bytes32 _recipient,
    bytes calldata _body,
    bytes calldata,
    address
  ) external payable returns (bytes32 _messageId) {
    lastDestination = _destination;
    lastRecipient = _recipient;
    lastSender = msg.sender;
    lastBody = _body;
    return keccak256(abi.encode(localDomain, ++nonce, _destination, _recipient, _body));
  }

  function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata, address) external pure returns (uint256 _fee) {
    return 0;
  }

  function deliver(address _recipient, uint32 _origin, bytes32 _sender, bytes calldata _body) external {
    IMessageRecipient(_recipient).handle(_origin, _sender, _body);
  }

  function relayLastTo(HaiAeroMailboxMock _destination) external {
    require(_destination.localDomain() == lastDestination, 'Wrong destination');
    _destination.deliver(
      address(uint160(uint256(lastRecipient))), localDomain, bytes32(uint256(uint160(lastSender))), lastBody
    );
  }
}

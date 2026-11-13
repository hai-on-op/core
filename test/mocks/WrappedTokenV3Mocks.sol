// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AeroEscrowMock, AeroMigrationTokenMock} from '@test/mocks/AeroMigrationMocks.sol';

import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

contract WrappedTokenV3EscrowMock is AeroEscrowMock {
  constructor(address _token, address _voter) AeroEscrowMock(_token, _voter) {}

  function setStake(uint256 _id, uint128 _amount, uint48 _end, bool _permanent) external {
    _stakes[_id] = IAeroVotingEscrow.StakedBalance(_amount, _end, _permanent);
  }
}

contract WrappedTokenV3SixDecimalsMock is AeroMigrationTokenMock {
  function decimals() public pure override returns (uint8 _decimals) {
    return 6;
  }
}

contract WrappedTokenV3TreasuryRotationMock {
  // solhint-disable-next-line var-name-mixedcase
  IModifiable internal immutable _WRAPPER;

  // solhint-disable-next-line var-name-mixedcase
  address internal immutable _NEXT_MANAGER;

  constructor(IModifiable _wrapper, address _nextManager) {
    _WRAPPER = _wrapper;
    _NEXT_MANAGER = _nextManager;
  }

  function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4 _selector) {
    _WRAPPER.modifyParameters('baseTokenManager', abi.encode(_NEXT_MANAGER));
    return this.onERC721Received.selector;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';

contract AeroMigrationTokenMock is ERC20 {
  bool public chargeFee;
  address public callbackTarget;
  bytes public callbackData;

  constructor() ERC20('Mock', 'MOCK') {}

  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external {
    _burn(_from, _amount);
  }

  function setFee(bool _fee) external {
    chargeFee = _fee;
  }

  function setCallback(address _target, bytes calldata _data) external {
    callbackTarget = _target;
    callbackData = _data;
  }

  function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
    bool _result = super.transferFrom(_from, _to, _amount);
    _callback();
    return _result;
  }

  function transfer(address _to, uint256 _amount) public override returns (bool) {
    bool _result = super.transfer(_to, _amount);
    _callback();
    return _result;
  }

  function _callback() internal {
    if (callbackTarget != address(0)) {
      (bool _ok, bytes memory _reason) = callbackTarget.call(callbackData);
      if (!_ok) {
        assembly {
          revert(add(_reason, 32), mload(_reason))
        }
      }
    }
  }

  function _update(address _from, address _to, uint256 _amount) internal override {
    if (chargeFee && _from != address(0) && _to != address(0) && _amount > 1) {
      super._update(_from, address(0), 1);
      super._update(_from, _to, _amount - 1);
    } else {
      super._update(_from, _to, _amount);
    }
  }
}

contract AeroEscrowMock is ERC721 {
  IERC20 public immutable TOKEN;
  address public immutable VOTER;
  uint256 public nextId;
  mapping(uint256 => IAeroVotingEscrow.StakedBalance) internal _stakes;

  constructor(address _token, address _voter) ERC721('sAERO', 'sAERO') {
    TOKEN = IERC20(_token);
    VOTER = _voter;
  }

  function staked(uint256 _id) external view returns (IAeroVotingEscrow.StakedBalance memory) {
    return _stakes[_id];
  }

  function createStake(uint128 _amount, uint48 _weeks, bool _permanent) external returns (uint256 _id) {
    require(_permanent && _weeks == 0, 'permanent only');
    TOKEN.transferFrom(msg.sender, address(this), _amount);
    _id = _mintStake(msg.sender, _amount, true);
  }

  function mintStake(address _owner, uint128 _amount, bool _permanent) external returns (uint256) {
    return _mintStake(_owner, _amount, _permanent);
  }

  function damageStake(uint256 _id) external {
    _stakes[_id].amount -= 1;
  }

  // Models a trusted treasury moving existing economic principal into a replacement NFT via an upstream VPM.
  function replaceStake(uint256 _id) external returns (uint256) {
    require(ownerOf(_id) == msg.sender, 'owner only');
    IAeroVotingEscrow.StakedBalance memory _previous = _stakes[_id];
    _burn(_id);
    delete _stakes[_id];
    return _mintStake(msg.sender, _previous.amount, _previous.isPermanent);
  }

  function _mintStake(address _owner, uint128 _amount, bool _permanent) internal returns (uint256 _id) {
    _id = ++nextId;
    _mint(_owner, _id);
    _stakes[_id] =
      IAeroVotingEscrow.StakedBalance(_amount, _permanent ? 0 : uint48(block.timestamp + 1 weeks), _permanent);
  }
}

contract AeroRootVoterMock {}

contract AeroTreasuryMock {
  bool public rejectNFTs;
  address public forwardRecipient;

  function setRejectNFTs(bool _reject) external {
    rejectNFTs = _reject;
  }

  function setForwardRecipient(address _recipient) external {
    forwardRecipient = _recipient;
  }

  function onERC721Received(address, address, uint256 _id, bytes calldata) external returns (bytes4) {
    require(!rejectNFTs, 'reject NFT');
    if (forwardRecipient != address(0)) ERC721(msg.sender).transferFrom(address(this), forwardRecipient, _id);
    return 0x150b7a02;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MockOracleRelayerForTest {
  uint256 public redemptionPrice = 1e27;
  uint256 public marketPrice = 1e27;

  function calcRedemptionPrice() external view returns (uint256 _redemptionPrice) {
    return redemptionPrice;
  }

  function setPrices(uint256 _redemptionPrice, uint256 _marketPrice) external {
    redemptionPrice = _redemptionPrice;
    marketPrice = _marketPrice;
  }
}

contract MockReentrantKiteTokenForTest is ERC20ForTest {
  address public controller;
  bool public reenterOnTransfer;
  bool public reenterCallSucceeded;
  bytes public reenterErrorData;
  bool internal _entered;

  function setController(address _controller) external {
    controller = _controller;
  }

  function setReenterOnTransfer(bool _enabled) external {
    reenterOnTransfer = _enabled;
  }

  function transfer(address _to, uint256 _wad) public virtual override(ERC20, IERC20) returns (bool _success) {
    if (reenterOnTransfer && !_entered && msg.sender == controller) {
      _entered = true;
      (bool _ok, bytes memory _ret) =
        controller.call(abi.encodeWithSelector(IEmissionsController.claimRewardsForStabilityPool.selector));
      reenterCallSucceeded = _ok;
      reenterErrorData = _ret;
      _entered = false;
    }
    return super.transfer(_to, _wad);
  }
}

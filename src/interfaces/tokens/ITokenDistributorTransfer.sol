// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributor} from '@interfaces/tokens/ITokenDistributor.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ITokenDistributorTransfer is ITokenDistributor {
  /// @notice Address of the ERC20 token to be distributed
  function token() external view returns (IERC20 _token);
}

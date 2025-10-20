// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISystemStakingToken} from '@interfaces/tokens/ISystemStakingToken.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit, IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

/**
 * @title  SystemStakingToken
 * @notice This contract represents the staked system coin
 */
contract SystemStakingToken is ERC20, ERC20Permit, ERC20Burnable, Authorizable, Modifiable, ISystemStakingToken {}

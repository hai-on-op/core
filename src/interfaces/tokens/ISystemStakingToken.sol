// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  ISystemStakingToken
 * @notice Interface for the SystemStakingToken contract which represents staked system coins
 */
interface ISystemStakingToken is IERC20Metadata, IERC20Permit, IAuthorizable {}

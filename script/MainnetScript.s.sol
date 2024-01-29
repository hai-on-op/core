// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {Script, console} from 'forge-std/Script.sol';
import {Params, ParamChecker, WETH, OP, WSTETH} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import '@script/Registry.s.sol';

/**
 * @title  MainnetScript
 * @notice This contract is used to deploy the system on Mainnet
 * @dev    This contract imports deployed addresses from `MainnetDeployment.s.sol`
 */
contract MainnetScript is MainnetDeployment, Common, Script {
  function setUp() public virtual {}

  /**
   * @notice This script is left as an example on how to use MainnetScript contract
   * @dev    This script is executed with `yarn script:mainnet` command
   */
  function run() public {
    _getEnvironmentParams();
    vm.startBroadcast();

    // Script goes here

    vm.stopBroadcast();
  }
}

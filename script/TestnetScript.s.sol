// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import {Script, console} from 'forge-std/Script.sol';
import {Params, ParamChecker, WETH, OP} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {TestnetDeployment} from '@script/TestnetDeployment.s.sol';
import '@script/Registry.s.sol';

/**
 * @title  TestnetScript
 * @notice This contract is used to deploy the system on Testnet
 * @dev    This contract imports deployed addresses from `TestnetDeployment.s.sol`
 */
contract TestnetScript is TestnetDeployment, Common, Script {
  function setUp() public virtual {}

  /**
   * @notice This script is left as an example on how to use TestnetScript contract
   * @dev    This script is executed with `yarn script:testnet` command
   */
  function run() public {
    _getEnvironmentParams();
    vm.startBroadcast();

    // Script goes here

    vm.stopBroadcast();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Script, console2} from 'forge-std/Script.sol';
import {HaiAero} from '@contracts/tokens/HaiAero.sol';
import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';

/**
 * @notice Deploys paused Base custody only. No treasury migration, funding, or activation.
 * @dev `forge script` simulates unless the operator separately supplies --broadcast and a signer.
 *      No private keys are read by this script. Verify new deployment receipts/runtime before activation.
 */
contract DeployHaiAero is Script {
  address internal constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;
  address internal constant SAERO = 0xBF7977E1521e9a3032bf7243Ee4712f311f13915;
  address internal constant VOTER = 0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6;

  function run() external returns (HaiAero _wrapper) {
    require(block.chainid == 8453, 'Base only');
    require(AERO.codehash == 0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9, 'AERO runtime changed');
    require(
      SAERO.codehash == 0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e, 'sAERO runtime changed'
    );
    require(
      VOTER.codehash == 0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b, 'Voter runtime changed'
    );
    require(
      IAeroVotingEscrow(SAERO).TOKEN() == AERO && IAeroVotingEscrow(SAERO).VOTER() == VOTER, 'dependency mismatch'
    );
    address _owner = vm.envAddress('AERO_OWNER');
    address _treasury = vm.envAddress('AERO_TREASURY');
    require(_owner != address(0) && _treasury.code.length != 0, 'missing owner or treasury Safe');
    vm.startBroadcast();
    _wrapper = new HaiAero(AERO, SAERO, _owner, _treasury, block.chainid);
    vm.stopBroadcast();
    require(_wrapper.paused(), 'must deploy paused');
    console2.log('Paused haiAERO Safe-custody issuer:', address(_wrapper));
  }
}

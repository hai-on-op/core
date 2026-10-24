// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Script, console2} from 'forge-std/Script.sol';
import {HaiAeroMigrator} from '@contracts/tokens/HaiAeroMigrator.sol';
import {HaiAero} from '@contracts/tokens/HaiAero.sol';

/// @notice Deploy paused bearer-claim migrator against an independently verified new output token.
contract DeployHaiAeroMigrator is Script {
  function run() external returns (HaiAeroMigrator _migrator) {
    require(block.chainid == 10 || block.chainid == 8453, 'unsupported chain');
    address _output = vm.envAddress('AERO_OUTPUT_TOKEN');
    bytes32 _runtime = vm.envBytes32('AERO_OUTPUT_RUNTIME_HASH');
    require(
      _output.code.length != 0 && _runtime != bytes32(0) && _output.codehash == _runtime, 'output runtime mismatch'
    );
    address _owner = vm.envAddress('AERO_OWNER');
    address _treasury = vm.envAddress('AERO_TREASURY');
    uint256[] memory _caps = vm.envUint('AERO_SOURCE_CAPS', ',');
    if (block.chainid == 8453) {
      require(address(HaiAero(_output).BASE_TOKEN()) == 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee, 'wrong new AERO');
      require(address(HaiAero(_output).BASE_TOKEN_NFT()) == 0xBF7977E1521e9a3032bf7243Ee4712f311f13915, 'wrong sAERO');
    } else {
      // A synthetic's proxy bytecode alone cannot prove the underlying route or implementation identity.
      address _implementation = vm.envAddress('AERO_OUTPUT_IMPLEMENTATION');
      bytes32 _implementationHash = vm.envBytes32('AERO_OUTPUT_IMPLEMENTATION_HASH');
      bytes32 _slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
      require(address(uint160(uint256(vm.load(_output, _slot)))) == _implementation, 'bridge implementation mismatch');
      require(
        _implementationHash != bytes32(0) && _implementation.codehash == _implementationHash,
        'implementation runtime mismatch'
      );
      require(vm.envOr('AERO_BRIDGE_ROUTE_REVIEWED', false), 'verify new route and old/new separation');
    }
    vm.startBroadcast();
    _migrator = new HaiAeroMigrator(_output, _owner, block.chainid, _caps, _treasury);
    vm.stopBroadcast();
    require(_migrator.paused(), 'must deploy paused');
    console2.log('Paused migrator:', address(_migrator));
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {HaiAero} from '@contracts/tokens/HaiAero.sol';
import {IAeroVotingEscrow} from '@interfaces/external/IAeroMigration.sol';

/// @dev Opt in using AERO_FORK_RPC. All changes are local fork state, never live transactions.
contract Fork_HaiAero is Test {
  address internal constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;
  address internal constant SAERO = 0xBF7977E1521e9a3032bf7243Ee4712f311f13915;
  address internal constant VOTER = 0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6;
  uint256 internal constant VERIFIED_BLOCK = 53_038_227;

  function test_CanonicalRuntimeAndConstructorBindings() public {
    string memory _rpc = vm.envOr('AERO_FORK_RPC', string(''));
    if (bytes(_rpc).length == 0) {
      vm.skip(true);
      return;
    }
    vm.createSelectFork(_rpc, VERIFIED_BLOCK);
    assertEq(AERO.codehash, 0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9);
    assertEq(SAERO.codehash, 0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e);
    assertEq(VOTER.codehash, 0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b);
    IAeroVotingEscrow _escrow = IAeroVotingEscrow(SAERO);
    assertEq(_escrow.TOKEN(), AERO);
    assertEq(_escrow.VOTER(), VOTER);
    HaiAero _wrapper = new HaiAero(AERO, SAERO, address(this), 0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3, 8453);
    assertTrue(_wrapper.paused());
    assertEq(address(_wrapper.BASE_TOKEN()), AERO);
    assertEq(address(_wrapper.BASE_TOKEN_NFT()), SAERO);
    assertEq(address(_wrapper.voter()), VOTER);
    // Full canonical state-changing scenarios run in script/aero/fork-smoke.mjs under Prague.
    // Upstream 0.8.36 bytecode uses opcodes unavailable in this repository's 0.8.20 compiler EVM target.
  }
}

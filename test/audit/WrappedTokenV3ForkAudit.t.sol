// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Test} from 'forge-std/Test.sol';
import {WrappedTokenV3, IWrappedTokenV3} from '@contracts/tokens/WrappedTokenV3.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IAeroVotingEscrow} from '@interfaces/external/IAeroVotingEscrow.sol';

interface ILegacyWrappedTokenV2Audit {
  function migrateV1toV2(address recipient, uint256 amount) external;
}

interface IAuditRuntimeVm {
  function setEvmVersion(string calldata version) external;
}

/// @dev Opt-in fork checks; set RUN_PR161_FORK_AUDIT=true and match Audit_WrappedTokenV3_Fork.
///      Balances are seeded with deal(), so these prove compatibility rather than reserve sufficiency.
///      Run with Foundry v1.9.0: deployed Aero uses newer opcodes than V3's Shanghai compiler target.
contract Audit_WrappedTokenV3_Fork is Test {
  address internal constant TREASURY = 0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3;
  address internal constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;
  address internal constant SAERO = 0xBF7977E1521e9a3032bf7243Ee4712f311f13915;
  address internal constant XAERO = 0xbdEaeA5205d16f34Cb40038052d91235D87B4C54;
  address internal constant OP_MAILBOX = 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D;
  address internal constant BASE_MAILBOX = 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D;
  address internal alice = address(0xa11ce);

  function setUp() public {
    vm.skip(!vm.envOr('RUN_PR161_FORK_AUDIT', false));
  }

  function _wrapper(bool onBase) internal returns (WrappedTokenV3 wrapper) {
    IAuditRuntimeVm(address(vm)).setEvmVersion('prague');
    wrapper = new WrappedTokenV3(
      IWrappedTokenV3.DeploymentConfig({
        baseToken: onBase ? AERO : XAERO,
        baseTokenNFT: onBase ? SAERO : address(0),
        treasury: TREASURY,
        chainId: onBase ? 8453 : 10,
        mailbox: onBase ? BASE_MAILBOX : OP_MAILBOX,
        hook: address(0),
        interchainSecurityModule: address(0),
        bridgeOwner: address(this)
      })
    );
    wrapper.unpause();
  }

  function test_ForkBaseTokenAndFreshNFTDepositToActualSafe() public {
    vm.createSelectFork('https://mainnet.base.org', 57_576_111);
    WrappedTokenV3 wrapper = _wrapper(true);
    deal(AERO, alice, 20 ether);
    uint256 beforeBalance = IERC20(AERO).balanceOf(TREASURY);
    vm.startPrank(alice);
    IERC20(AERO).approve(address(wrapper), 10 ether);
    wrapper.deposit(alice, 10 ether);
    IERC20(AERO).approve(SAERO, 10 ether);
    uint256 id = IAeroVotingEscrow(SAERO).createStake(10 ether, 0, true);
    IAeroVotingEscrow(SAERO).approve(address(wrapper), id);
    uint256[] memory ids = new uint256[](1);
    ids[0] = id;
    wrapper.depositNFTs(alice, ids);
    vm.stopPrank();
    assertEq(wrapper.balanceOf(alice), 20 ether);
    assertEq(IERC20(AERO).balanceOf(TREASURY), beforeBalance + 10 ether);
    assertEq(IAeroVotingEscrow(SAERO).ownerOf(id), TREASURY);
    assertEq(IAeroVotingEscrow(SAERO).staked(id).amount, 10 ether);
  }

  function test_ForkOptimismXAeroAndAllLegacySources() public {
    vm.createSelectFork('https://mainnet.optimism.io', 159_553_319);
    WrappedTokenV3 wrapper = _wrapper(false);
    deal(XAERO, alice, 10 ether);
    uint256 beforeBalance = IERC20(XAERO).balanceOf(TREASURY);
    vm.startPrank(alice);
    IERC20(XAERO).approve(address(wrapper), 10 ether);
    wrapper.deposit(alice, 10 ether);
    vm.stopPrank();
    assertEq(IERC20(XAERO).balanceOf(TREASURY), beforeBalance + 10 ether);
    address[3] memory sources = [wrapper.LEGACY_VELO_V1(), wrapper.LEGACY_VELO_V2(), wrapper.LEGACY_AERO_OPTIMISM()];
    for (uint256 i; i < sources.length; ++i) {
      deal(sources[i], alice, 1000 ether);
      uint256 retired = IERC20(sources[i]).balanceOf(address(0xdead));
      vm.startPrank(alice);
      IERC20(sources[i]).approve(address(wrapper), 1000 ether);
      assertEq(wrapper.migrate(sources[i], 1000 ether, 0, alice), i < 2 ? 44 ether : 1000 ether);
      vm.stopPrank();
      assertEq(IERC20(sources[i]).balanceOf(address(0xdead)), retired + 1000 ether);
      assertEq(IERC20(sources[i]).balanceOf(alice), 0);
    }
    assertEq(wrapper.balanceOf(alice), 1098 ether);
  }

  function test_ForkRetiredV1CannotMigrateThroughV2Again() public {
    vm.createSelectFork('https://mainnet.optimism.io', 159_553_319);
    WrappedTokenV3 wrapper = _wrapper(false);
    address v1 = wrapper.LEGACY_VELO_V1();
    address v2 = wrapper.LEGACY_VELO_V2();
    deal(v1, alice, 1000 ether);
    vm.startPrank(alice);
    IERC20(v1).approve(address(wrapper), 1000 ether);
    IERC20(v1).approve(v2, 1000 ether);
    wrapper.migrate(v1, 1000 ether, 44 ether, alice);
    vm.expectRevert();
    ILegacyWrappedTokenV2Audit(v2).migrateV1toV2(alice, 1000 ether);
    vm.stopPrank();
    assertEq(wrapper.balanceOf(alice), 44 ether);
  }
}

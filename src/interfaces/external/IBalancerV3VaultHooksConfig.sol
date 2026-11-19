// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IBalancerV3VaultHooksConfig {
  function getHooksConfig(address _pool)
    external
    view
    returns (
      bool _enableHookAdjustedAmounts,
      bool _shouldCallBeforeInitialize,
      bool _shouldCallAfterInitialize,
      bool _shouldCallComputeDynamicSwapFee,
      bool _shouldCallBeforeSwap,
      bool _shouldCallAfterSwap,
      bool _shouldCallBeforeAddLiquidity,
      bool _shouldCallAfterAddLiquidity,
      bool _shouldCallBeforeRemoveLiquidity,
      bool _shouldCallAfterRemoveLiquidity,
      address _hooksContract
    );
}

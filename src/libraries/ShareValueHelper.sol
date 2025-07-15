// SPDX-License-Identifier: AGLP-3.0
pragma solidity ^0.8.19;

import {IYearnVaultV2} from '@interfaces/external/IYearnVaultV2.sol';

/**
 * @title Share Value Helper
 * @dev This works on all Yearn vaults 0.4.0+
 * @dev Achieves a higher precision conversion than pricePerShare; particularly for tokens with < 18 decimals.
 */
library ShareValueHelper {
  /**
   * @notice Helper function to convert underlying amount to vault shares with exact precision.
   * @param _vault The address of the vault token.
   * @param _amount The amount of underlying to convert to shares.
   * @return The shares of vault token.
   */
  function amountToShares(address _vault, uint256 _amount) internal view returns (uint256) {
    uint256 totalSupply = IYearnVaultV2(_vault).totalSupply();
    if (totalSupply > 0) {
      return (_amount * totalSupply) / calculateFreeFunds(_vault);
    }
    return _amount;
  }

  /**
   * @notice Helper function to convert shares to underlying amount with exact precision.
   * @param _vault The address of the vault token.
   * @param _shares The amount of shares to convert to underlying.
   * @return The amount of underlying token.
   */
  function sharesToAmount(address _vault, uint256 _shares) internal view returns (uint256) {
    uint256 totalSupply = IYearnVaultV2(_vault).totalSupply();
    if (totalSupply == 0) return _shares;

    uint256 freeFunds = calculateFreeFunds(_vault);
    return ((_shares * freeFunds) / totalSupply);
  }

  function calculateFreeFunds(address _vault) internal view returns (uint256) {
    uint256 totalAssets = IYearnVaultV2(_vault).totalAssets();
    uint256 lockedFundsRatio =
      (block.timestamp - IYearnVaultV2(_vault).lastReport()) * IYearnVaultV2(_vault).lockedProfitDegradation();

    if (lockedFundsRatio < 10 ** 18) {
      uint256 lockedProfit = IYearnVaultV2(_vault).lockedProfit();
      lockedProfit -= ((lockedFundsRatio * lockedProfit) / 10 ** 18);
      return totalAssets - lockedProfit;
    } else {
      return totalAssets;
    }
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

import {IYearnVault} from '@interfaces/external/IYearnVault.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IPessimisticVeloLpOracle} from '@interfaces/external/IPessimisticVeloLpOracle.sol';

interface IYearnVeloVaultRelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new YearnVeloVaultRelayer contract is deployed
   * @param  _yearnVeloVaultRelayer Address of the deployed DenominatedOracle contract
   * @param  _yearnVault The address of the yearn vault contract
   * @param  _veloPool The address of the velo pool underlying the yearn vault
   * @param  _veloLpOracle The address of the pessimistic velo lp oracle
   */
  event NewYearnVeloVaultRelayer(
    address indexed _yearnVeloVaultRelayer, address _yearnVault, address _veloPool, address _veloLpOracle
  );

  // --- Methods ---

  /**
   * @notice Deploys a new YearnVeloVaultRelayer contract
   * @param  _yearnVault The address of the yearn vault contract
   * @param  _veloPool The address of the velo pool underlying the yearn vault
   * @param  _veloLpOracle The address of the pessimistic velo lp oracle
   * @return _yearnVeloVaultRelayer Address of the deployed YearnVeloVaultRelayer contract
   */
  function deployYearnVeloVaultRelayer(
    IYearnVault _yearnVault,
    IVeloPool _veloPool,
    IPessimisticVeloLpOracle _veloLpOracle
  ) external returns (IBaseOracle _yearnVeloVaultRelayer);

  // --- Views ---

  /**
   * @notice Getter for the list of YearnVeloVaultRelayer contracts
   * @return _yearnVeloVaultRelayersList List of YearnVeloVaultRelayer contracts
   */
  function yearnVeloVaultRelayersList() external view returns (address[] memory _yearnVeloVaultRelayersList);
}

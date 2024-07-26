// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

import {IBeefyVaultV7} from '@interfaces/external/IBeefyVaultV7.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';

interface IBeefyVeloVaultRelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new BeefyVeloVaultRelayer contract is deployed
   * @param  _beefyVeloVaultRelayer Address of the deployed DenominatedOracle contract
   * @param  _token0priceSource Address of the price source for the first token in the velo pool
   * @param  _token1priceSource Address of the price source for the second token in the velo pool
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   */
  event NewBeefyVeloVaultRelayer(
    address indexed _beefyVeloVaultRelayer,
    address _token0priceSource,
    address _token1priceSource,
    address _beefyVault,
    address _veloPool
  );

  // --- Methods ---

  /**
   * @notice Deploys a new BeefyVeloVaultRelayer contract
   * @param  _token0priceSource Address of the price source for the first token in the velo pool
   * @param  _token1priceSource Address of the price source for the second token in the velo pool
   * @param  _beefyVault The address of the beefy vault contract
   * @param  _veloPool The address of the velo pool underlying the beefy vault
   * @return _beefyVeloVaultRelayer Address of the deployed BeefyVeloVaultRelayer contract
   */
  function deployBeefyVeloVaultRelayer(
    IBaseOracle _token0priceSource,
    IBaseOracle _token1priceSource,
    IBeefyVaultV7 _beefyVault,
    IVeloPool _veloPool
  ) external returns (IBaseOracle _beefyVeloVaultRelayer);

  // --- Views ---

  /**
   * @notice Getter for the list of BeefyVeloVaultRelayer contracts
   * @return _beefyVeloVaultRelayersList List of BeefyVeloVaultRelayer contracts
   */
  function beefyVeloVaultRelayersList() external view returns (address[] memory _beefyVeloVaultRelayersList);
}

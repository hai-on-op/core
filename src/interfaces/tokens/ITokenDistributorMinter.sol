// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITokenDistributor} from '@interfaces/tokens/ITokenDistributor.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

interface ITokenDistributorMinter is ITokenDistributor {
  /// @notice Address of the ERC20 token to be distributed
  function token() external view returns (IProtocolToken _token);

  /**
   * @notice Claims tokens from the distributor and delegates them using a signature
   * @param  _proof Array of bytes32 merkle proof hashes
   * @param  _amount Amount of tokens to claim
   * @param  _delegatee Address to delegate the token votes to
   * @param  _expiry Expiration timestamp of the signature
   * @param  _v Recovery byte of the signature
   * @param  _r ECDSA signature r value
   * @param  _s ECDSA signature s value
   */
  function claimAndDelegate(
    bytes32[] calldata _proof,
    uint256 _amount,
    address _delegatee,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external;
}

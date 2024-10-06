// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/*
  Coded for Let's get HAI and the Money God with 🥕 by
                 .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/
*/

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ISlipstreamCLFactory} from '@interfaces/external/ISlipstreamCLFactory.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

/**
 * @title  SlipstreamCLRelayer
 * @notice This contracts inherits from UniV3Relayer and consults a SlipstreamCLPool TWAP
 */
contract SlipstreamCLRelayer is IBaseOracle, UniV3Relayer {
  /**
   * @param  _baseToken Address of the base token used to consult the quote
   * @param  _quoteToken Address of the token used as a quote reference
   * @param  _feeTier Fee tier of the pool used to consult the quote
   * @param  _quotePeriod Length in seconds of the TWAP used to consult the pool
   */
  constructor(
    address _uniV3Factory,
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) UniV3Relayer(_uniV3Factory, _baseToken, _quoteToken, _feeTier, _quotePeriod) {}

  function _getPool(
    address _uniV3Factory,
    address _tokenA,
    address _tokenB,
    uint24 _feeTier
  ) internal view override returns (address _pool) {
    return ISlipstreamCLFactory(_uniV3Factory).getPool(_tokenA, _tokenB, int24(_feeTier));
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {PessimisticVeloSingleOracle} from '@contracts/oracles/PessimisticVeloSingleOracle.sol';
import {IVeloPool} from '@interfaces/external/IVeloPool.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

contract ChainlinkOracleForTest is IChainlinkOracle {
  uint8 internal immutable _decimals;
  int256 internal _answer;
  uint256 internal _updatedAt;

  constructor(uint8 __decimals, int256 __answer, uint256 __updatedAt) {
    _decimals = __decimals;
    _answer = __answer;
    _updatedAt = __updatedAt;
  }

  function decimals() external view returns (uint8 __decimals) {
    return _decimals;
  }

  function description() external pure returns (string memory _description) {
    return 'ChainlinkOracleForTest';
  }

  function getAnswer(uint256) external view returns (int256 _latestAnswer) {
    return _answer;
  }

  function getRoundData(uint256)
    external
    view
    returns (uint256 _roundId, int256 __answer, uint256 _startedAt, uint256 __updatedAt, uint256 _answeredInRound)
  {
    return (1, _answer, _updatedAt, _updatedAt, 1);
  }

  function getTimestamp(uint256) external view returns (uint256 _timestamp) {
    return _updatedAt;
  }

  function latestAnswer() external view returns (int256 _latestAnswer) {
    return _answer;
  }

  function latestRound() external pure returns (uint256 _latestRound) {
    return 1;
  }

  function latestRoundData()
    external
    view
    returns (uint256 _roundId, int256 __answer, uint256 _startedAt, uint256 __updatedAt, uint256 _answeredInRound)
  {
    return (1, _answer, _updatedAt, _updatedAt, 1);
  }

  function latestTimestamp() external view returns (uint256 _latestTimestamp) {
    return _updatedAt;
  }
}

contract VeloPoolForTest is IVeloPool {
  error QuoteShouldNotBeCalled();

  string public name = 'VeloPoolForTest';
  string public symbol = 'VPT';
  uint8 public decimals = 18;
  uint256 public totalSupply = 1e18;
  uint256 public reserve0;
  uint256 public reserve1;
  bool public stable;
  address public token0;
  address public token1;
  uint256 internal _decimals0;
  uint256 internal _decimals1;
  Observation[] internal _observations;

  constructor(address _token0, address _token1, bool _stable, uint256 __decimals0, uint256 __decimals1) {
    token0 = _token0;
    token1 = _token1;
    stable = _stable;
    _decimals0 = __decimals0;
    _decimals1 = __decimals1;
  }

  function setConstantObservations(uint256 _reserve0, uint256 _reserve1, uint256 _observationCount) external {
    delete _observations;
    reserve0 = _reserve0;
    reserve1 = _reserve1;

    for (uint256 i = 0; i < _observationCount;) {
      uint256 timestamp = i + 1;
      _observations.push(
        Observation({
          timestamp: timestamp,
          reserve0Cumulative: _reserve0 * timestamp,
          reserve1Cumulative: _reserve1 * timestamp
        })
      );

      unchecked {
        i++;
      }
    }
  }

  function balanceOf(address) external pure returns (uint256 _balance) {
    return 0;
  }

  function transfer(address, uint256) external pure returns (bool _success) {
    return true;
  }

  function allowance(address, address) external pure returns (uint256 _allowance) {
    return 0;
  }

  function approve(address, uint256) external pure returns (bool _success) {
    return true;
  }

  function transferFrom(address, address, uint256) external pure returns (bool _success) {
    return true;
  }

  function quote(address, uint256, uint256) external pure returns (uint256) {
    revert QuoteShouldNotBeCalled();
  }

  function observationLength() external view returns (uint256 _observationLength) {
    return _observations.length;
  }

  function observations(uint256 index) external view returns (Observation memory _observation) {
    return _observations[index];
  }

  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
    return (reserve0, reserve1, block.timestamp);
  }

  function metadata()
    external
    view
    returns (uint256 dec0, uint256 dec1, uint256 r0, uint256 r1, bool st, address t0, address t1)
  {
    return (_decimals0, _decimals1, reserve0, reserve1, stable, token0, token1);
  }
}

abstract contract PessimisticVeloSingleOracleTest is HaiTest {
  address internal constant SEQUENCER_UPTIME_FEED = 0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389;
  address internal token0 = label('token0');
  address internal token1 = label('token1');
  uint256 internal constant POINTS = 4;

  ChainlinkOracleForTest internal token0Feed;
  VeloPoolForTest internal pool;
  PessimisticVeloSingleOracle internal oracle;

  function _deployOracle(bool _stable, uint256 _reserve0, uint256 _reserve1) internal {
    _deployOracle(_stable, 1e18, 1e18, _reserve0, _reserve1);
  }

  function _deployOracle(
    bool _stable,
    uint256 _decimals0,
    uint256 _decimals1,
    uint256 _reserve0,
    uint256 _reserve1
  ) internal {
    token0Feed = new ChainlinkOracleForTest(8, 200_000_000, block.timestamp);
    pool = new VeloPoolForTest(token0, token1, _stable, _decimals0, _decimals1);
    pool.setConstantObservations(_reserve0, _reserve1, POINTS + 1);
    oracle =
      new PessimisticVeloSingleOracle(address(pool), address(token0Feed), address(0), 3600, 3600, POINTS, address(this));
  }

  function _mockSequencerUp() internal {
    vm.mockCall(
      SEQUENCER_UPTIME_FEED,
      abi.encodeCall(IChainlinkOracle.latestRoundData, ()),
      abi.encode(uint256(1), int256(0), block.timestamp - 2 hours, block.timestamp - 2 hours, uint256(1))
    );
  }

  function _stableDerivative(uint256 x0, uint256 y) internal pure returns (uint256 derivative) {
    derivative = 3 * ((x0 * ((y * y) / 1e18)) / 1e18) + ((((x0 * x0) / 1e18) * x0) / 1e18);
  }
}

contract Unit_PessimisticVeloSingleOracle_GetTwapPrice is PessimisticVeloSingleOracleTest {
  function test_Volatile_ReturnsNoSlippageMarginalPrice() public {
    _deployOracle(false, 100e18, 200e18);

    assertEq(oracle.getTwapPrice(token0, 1e18), 2e18);
    assertEq(oracle.getTwapPrice(token0, 100e18), 200e18);
    assertEq(oracle.getTwapPrice(token1, 1e18), 0.5e18);
    assertEq(oracle.getTwapPrice(token1, 100e18), 50e18);
  }

  function test_Stable_ReturnsNoSlippageMarginalPrice() public {
    _deployOracle(true, 100e18, 200e18);

    uint256 expectedToken0ToToken1 = (1e18 * _stableDerivative(200e18, 100e18)) / _stableDerivative(100e18, 200e18);
    uint256 expectedToken1ToToken0 = (1e18 * _stableDerivative(100e18, 200e18)) / _stableDerivative(200e18, 100e18);

    assertEq(oracle.getTwapPrice(token0, 1e18), expectedToken0ToToken1);
    assertEq(oracle.getTwapPrice(token1, 1e18), expectedToken1ToToken0);
    assertApproxEqAbs(oracle.getTwapPrice(token0, 100e18), expectedToken0ToToken1 * 100, 100);
    assertApproxEqAbs(oracle.getTwapPrice(token1, 100e18), expectedToken1ToToken0 * 100, 100);
  }

  function test_Stable_HandlesDifferentTokenDecimals() public {
    _deployOracle(true, 1e6, 1e18, 1000e6, 2000e18);

    uint256 expectedToken0ToToken1 = (1e18 * _stableDerivative(2000e18, 1000e18)) / _stableDerivative(1000e18, 2000e18);

    assertEq(oracle.getTwapPrice(token0, 1e6), expectedToken0ToToken1);
    assertApproxEqAbs(oracle.getTwapPrice(token0, 100e6), expectedToken0ToToken1 * 100, 100);
  }

  function test_GetTokenPrices_UsesNoSlippageTwapPrice() public {
    _deployOracle(false, 100e18, 200e18);
    _mockSequencerUp();

    (uint256 price0, uint256 price1) = oracle.getTokenPrices();

    assertEq(price0, 200_000_000);
    assertEq(price1, 100_000_000);
  }
}

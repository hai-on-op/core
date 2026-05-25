// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Math as OZMath} from '@openzeppelin/contracts/utils/math/Math.sol';

import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {
  IBalancerV3RouterStableMath,
  IBalancerV3VaultStableMath,
  IBalancerV3StablePoolLike
} from '@interfaces/external/IBalancerV3StableMath.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

/**
 * @title BalancerV3StablePoolMathSwapStep
 * @notice Swaps through a Balancer V3 stable pool using view-safe pool math for preview
 */
contract BalancerV3StablePoolMathSwapStep is IStrategyStep {
  using SafeERC20 for IERC20;

  // --- Errors ---

  error BalancerV3StablePoolMathSwapStep_UnsupportedHooks();
  error BalancerV3StablePoolMathSwapStep_InvalidOracle();
  error BalancerV3StablePoolMathSwapStep_InvalidOraclePrice();
  error BalancerV3StablePoolMathSwapStep_InvalidOracleTolerance();
  error BalancerV3StablePoolMathSwapStep_OracleFloorNotMet();

  // --- Data ---

  struct Data {
    address router;
    address pool;
    address tokenIn;
    address tokenOut;
    uint256 deadlineBuffer;
    bytes userData;
    bool useOracleFloor;
    address tokenInOracle;
    address tokenOutOracle;
    uint16 oracleToleranceBps;
  }

  // --- Constants ---

  bytes32 internal constant _STEP_TYPE = bytes32('BALANCER_V3_SWAP');
  uint256 internal constant _ONE = 1e18;
  uint256 internal constant _BPS = 10_000;
  uint8 internal constant _SWAP_KIND_EXACT_IN = 0;
  bytes4 internal constant _SELECTOR_GET_HOOKS_CONFIG = 0xce8630d4;

  // --- Methods ---

  /// @inheritdoc IStrategyStep
  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  /// @inheritdoc IStrategyStep
  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    Data memory _decoded = abi.decode(_data, (Data));
    return _decoded.tokenIn;
  }

  /// @inheritdoc IStrategyStep
  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    Data memory _decoded = abi.decode(_data, (Data));
    _outputTokens = new address[](1);
    _outputTokens[0] = _decoded.tokenOut;
  }

  /// @inheritdoc IStrategyStep
  function preview(bytes calldata _data, uint256 _amountIn) external view returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    IBalancerV3RouterStableMath _router = IBalancerV3RouterStableMath(_decoded.router);
    IBalancerV3VaultStableMath _vault = IBalancerV3VaultStableMath(_router.getVault());
    _ensureSwapHooksDisabled(address(_vault), _decoded.pool);

    // slither-disable-next-line unused-return
    (, uint256 _indexIn) = _vault.getPoolTokenCountAndIndexOfToken(_decoded.pool, IERC20(_decoded.tokenIn));
    // slither-disable-next-line unused-return
    (, uint256 _indexOut) = _vault.getPoolTokenCountAndIndexOfToken(_decoded.pool, IERC20(_decoded.tokenOut));

    (uint256[] memory _decimalScalingFactors, uint256[] memory _tokenRates) = _vault.getPoolTokenRates(_decoded.pool);
    uint256[] memory _balancesScaled18 = _vault.getCurrentLiveBalances(_decoded.pool);
    uint256 _swapFeePercentage = _vault.getStaticSwapFeePercentage(_decoded.pool);

    uint256 _amountGivenScaled18 =
      _toScaled18ApplyRateRoundDown(_amountIn, _decimalScalingFactors[_indexIn], _tokenRates[_indexIn]);
    uint256 _totalSwapFeeAmountScaled18 = _mulUp(_amountGivenScaled18, _swapFeePercentage);
    _amountGivenScaled18 -= _totalSwapFeeAmountScaled18;

    uint256 _amountOutScaled18 = IBalancerV3StablePoolLike(_decoded.pool).onSwap(
      IBalancerV3StablePoolLike.PoolSwapParams({
        kind: _SWAP_KIND_EXACT_IN,
        amountGivenScaled18: _amountGivenScaled18,
        balancesScaled18: _balancesScaled18,
        indexIn: _indexIn,
        indexOut: _indexOut,
        router: _decoded.router,
        userData: _decoded.userData
      })
    );

    _amountsOut[0] = _toRawUndoRateRoundDown(
      _amountOutScaled18, _decimalScalingFactors[_indexOut], _computeRateRoundUp(_tokenRates[_indexOut])
    );
    if (_amountsOut[0] < _oracleMinOut(_decoded, _amountIn)) {
      revert BalancerV3StablePoolMathSwapStep_OracleFloorNotMet();
    }
  }

  /// @inheritdoc IStrategyStep
  function execute(
    bytes calldata _data,
    uint256 _amountIn,
    uint256[] calldata _minOuts
  ) external returns (uint256[] memory _amountsOut) {
    Data memory _decoded = abi.decode(_data, (Data));
    _amountsOut = new uint256[](1);
    if (_amountIn == 0) return _amountsOut;

    // Balancer V3 uses a push model: transfer tokens to the Vault before swapping.
    address _vault = IBalancerV3RouterStableMath(_decoded.router).getVault();
    IERC20(_decoded.tokenIn).safeTransfer(_vault, _amountIn);

    uint256 _minOut = _minOuts.length > 0 ? _minOuts[0] : 0;
    uint256 _oracleFloor = _oracleMinOut(_decoded, _amountIn);
    if (_oracleFloor > _minOut) _minOut = _oracleFloor;

    _amountsOut[0] = IBalancerV3RouterStableMath(_decoded.router).swapSingleTokenExactIn(
      _decoded.pool,
      IERC20(_decoded.tokenIn),
      IERC20(_decoded.tokenOut),
      _amountIn,
      _minOut,
      block.timestamp + 1,
      _decoded.userData
    );
  }

  // --- Internal Methods ---

  function _oracleMinOut(Data memory _decoded, uint256 _amountIn) internal view returns (uint256 _minOut) {
    if (!_decoded.useOracleFloor) return 0;

    if (_decoded.tokenInOracle == address(0) || _decoded.tokenOutOracle == address(0)) {
      revert BalancerV3StablePoolMathSwapStep_InvalidOracle();
    }
    if (_decoded.oracleToleranceBps > _BPS) revert BalancerV3StablePoolMathSwapStep_InvalidOracleTolerance();

    (uint256 _tokenInPrice, bool _validTokenInPrice) = IBaseOracle(_decoded.tokenInOracle).getResultWithValidity();
    (uint256 _tokenOutPrice, bool _validTokenOutPrice) = IBaseOracle(_decoded.tokenOutOracle).getResultWithValidity();
    if (!_validTokenInPrice || !_validTokenOutPrice || _tokenInPrice == 0 || _tokenOutPrice == 0) {
      revert BalancerV3StablePoolMathSwapStep_InvalidOraclePrice();
    }

    uint256 _tokenInUnit = 10 ** IERC20Metadata(_decoded.tokenIn).decimals();
    uint256 _tokenOutUnit = 10 ** IERC20Metadata(_decoded.tokenOut).decimals();
    uint256 _valueWad = OZMath.mulDiv(_amountIn, _tokenInPrice, _tokenInUnit);
    uint256 _fairOut = OZMath.mulDiv(_valueWad, _tokenOutUnit, _tokenOutPrice);
    _minOut = OZMath.mulDiv(_fairOut, _BPS - _decoded.oracleToleranceBps, _BPS);
  }

  /**
   * @notice Reverts when the pool uses swap hooks that can alter quote behavior
   * @dev Dynamic swap fee and swap hooks are not modeled by this step's preview math
   */
  function _ensureSwapHooksDisabled(address _vault, address _pool) internal view {
    (bool _ok, bytes memory _ret) = _vault.staticcall(abi.encodeWithSelector(_SELECTOR_GET_HOOKS_CONFIG, _pool));
    if (!_ok || _ret.length < 352) revert BalancerV3StablePoolMathSwapStep_UnsupportedHooks();

    (,,, bool _shouldCallComputeDynamicSwapFee, bool _shouldCallBeforeSwap, bool _shouldCallAfterSwap,,,,,) =
      abi.decode(_ret, (bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, address));

    if (_shouldCallComputeDynamicSwapFee || _shouldCallBeforeSwap || _shouldCallAfterSwap) {
      revert BalancerV3StablePoolMathSwapStep_UnsupportedHooks();
    }
  }

  /// @notice Multiplies two wad values rounding down
  function _mulDown(uint256 _a, uint256 _b) internal pure returns (uint256 _result) {
    _result = (_a * _b) / _ONE;
  }

  /// @notice Multiplies two wad values rounding up
  function _mulUp(uint256 _a, uint256 _b) internal pure returns (uint256 _result) {
    uint256 _product = _a * _b;
    if (_product == 0) return 0;
    _result = ((_product - 1) / _ONE) + 1;
  }

  /// @notice Divides two wad values rounding down
  function _divDown(uint256 _a, uint256 _b) internal pure returns (uint256 _result) {
    _result = (_a * _ONE) / _b;
  }

  /// @notice Converts raw token input to 18-decimals and applies token rate rounding down
  function _toScaled18ApplyRateRoundDown(
    uint256 _amount,
    uint256 _scalingFactor,
    uint256 _tokenRate
  ) internal pure returns (uint256 _result) {
    _result = _mulDown(_amount * _scalingFactor, _tokenRate);
  }

  /// @notice Converts a scaled 18-decimal amount back to raw token units rounding down
  function _toRawUndoRateRoundDown(
    uint256 _amount,
    uint256 _scalingFactor,
    uint256 _tokenRate
  ) internal pure returns (uint256 _result) {
    _result = _divDown(_amount, _scalingFactor * _tokenRate);
  }

  /// @notice Rounds a token rate up to avoid overestimating output on conversion
  function _computeRateRoundUp(uint256 _rate) internal pure returns (uint256 _roundedRate) {
    _roundedRate = (_rate / _ONE) * _ONE;
    return _roundedRate == _rate ? _rate : _rate + 1;
  }
}

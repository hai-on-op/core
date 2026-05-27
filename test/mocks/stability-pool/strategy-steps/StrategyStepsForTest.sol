// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {IVelodromeRouterV2, IVeloCLRouter} from '@interfaces/external/IStrategyStepExternal.sol';

contract MockBalancerRouterForTest {
  address public immutable mockVault;
  uint256 public outMultiplier = 1e18; // passthrough in WAD

  constructor(address _vault) {
    mockVault = _vault;
  }

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  function getVault() external view returns (address _vault) {
    return mockVault;
  }

  function swapSingleTokenExactIn(
    address,
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _exactAmountIn,
    uint256 _minAmountOut,
    uint256,
    bytes calldata
  ) external returns (uint256 _amountOut) {
    require(IERC20(_tokenIn).balanceOf(mockVault) >= _exactAmountIn, 'tokens-not-at-vault');
    _amountOut = (_exactAmountIn * outMultiplier) / 1e18;
    require(_amountOut >= _minAmountOut, 'min-out');
    ERC20ForTest(address(_tokenOut)).mint(msg.sender, _amountOut);
  }
}

contract MockBalancerPoolForTest {
  struct PoolSwapParams {
    uint8 kind;
    uint256 amountGivenScaled18;
    uint256[] balancesScaled18;
    uint256 indexIn;
    uint256 indexOut;
    address router;
    bytes userData;
  }

  uint256 public outMultiplier = 1e18; // passthrough in WAD

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  function onSwap(PoolSwapParams memory _request) external view returns (uint256 _amountOutScaled18) {
    _amountOutScaled18 = (_request.amountGivenScaled18 * outMultiplier) / 1e18;
  }
}

contract MockBalancerVaultForTest {
  IERC20 internal immutable _token0;
  IERC20 internal immutable _token1;

  uint256 internal _swapFeePercentage;
  uint256 internal _scaling0;
  uint256 internal _scaling1;
  uint256 internal _rate0;
  uint256 internal _rate1;
  uint256 internal _balance0;
  uint256 internal _balance1;
  bool internal _swapHooksEnabled;

  constructor(IERC20 token0_, IERC20 token1_) {
    _token0 = token0_;
    _token1 = token1_;
    _scaling0 = 1;
    _scaling1 = 1;
    _rate0 = 1e18;
    _rate1 = 1e18;
    _balance0 = 100e18;
    _balance1 = 100e18;
  }

  function setSwapFeePercentage(uint256 _swapFeePercentage_) external {
    _swapFeePercentage = _swapFeePercentage_;
  }

  function setPoolTokenRates(uint256 _scaling0_, uint256 _scaling1_, uint256 _rate0_, uint256 _rate1_) external {
    _scaling0 = _scaling0_;
    _scaling1 = _scaling1_;
    _rate0 = _rate0_;
    _rate1 = _rate1_;
  }

  function setCurrentLiveBalances(uint256 _balance0_, uint256 _balance1_) external {
    _balance0 = _balance0_;
    _balance1 = _balance1_;
  }

  function setSwapHooksEnabled(bool _swapHooksEnabled_) external {
    _swapHooksEnabled = _swapHooksEnabled_;
  }

  function getPoolTokenCountAndIndexOfToken(
    address,
    IERC20 _token
  ) external view returns (uint256 _tokenCount, uint256 _index) {
    _tokenCount = 2;
    if (address(_token) == address(_token0)) return (_tokenCount, 0);
    if (address(_token) == address(_token1)) return (_tokenCount, 1);
    revert('invalid-token');
  }

  function getPoolTokenRates(address)
    external
    view
    returns (uint256[] memory _decimalScalingFactors, uint256[] memory _tokenRates)
  {
    _decimalScalingFactors = new uint256[](2);
    _decimalScalingFactors[0] = _scaling0;
    _decimalScalingFactors[1] = _scaling1;

    _tokenRates = new uint256[](2);
    _tokenRates[0] = _rate0;
    _tokenRates[1] = _rate1;
  }

  function getCurrentLiveBalances(address) external view returns (uint256[] memory _balancesLiveScaled18) {
    _balancesLiveScaled18 = new uint256[](2);
    _balancesLiveScaled18[0] = _balance0;
    _balancesLiveScaled18[1] = _balance1;
  }

  function getStaticSwapFeePercentage(address) external view returns (uint256 _fee) {
    return _swapFeePercentage;
  }

  function getHooksConfig(address)
    external
    view
    returns (bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, address)
  {
    return (
      false,
      false,
      false,
      _swapHooksEnabled,
      _swapHooksEnabled,
      _swapHooksEnabled,
      false,
      false,
      false,
      false,
      address(0)
    );
  }
}

contract MockBalancerVaultNoHooksSelectorForTest {}

contract MockBalancerVaultShortHooksReturnForTest {
  function getHooksConfig(address) external pure returns (bool _onlyOneValue) {
    return false;
  }
}

contract MockBalancerV3Vault {}

contract MockBalancerV3Router {
  uint256 public outMultiplier = 3e18; // 3x in WAD
  uint256 public lastDeadline;
  address public immutable mockVault;

  constructor(address _vault) {
    mockVault = _vault;
  }

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  function getVault() external view returns (address) {
    return mockVault;
  }

  function swapSingleTokenExactIn(
    address,
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _exactAmountIn,
    uint256 _minAmountOut,
    uint256 _deadline,
    bytes calldata
  ) external returns (uint256 _amountOut) {
    // Push model: tokens should already be at the vault
    lastDeadline = _deadline;
    require(IERC20(_tokenIn).balanceOf(mockVault) >= _exactAmountIn, 'tokens-not-at-vault');
    _amountOut = (_exactAmountIn * outMultiplier) / 1e18;
    require(_amountOut >= _minAmountOut, 'min-out');
    ERC20ForTest(address(_tokenOut)).mint(msg.sender, _amountOut);
  }
}

contract MockBalancerV3StablePool {
  struct PoolSwapParams {
    uint8 kind;
    uint256 amountGivenScaled18;
    uint256[] balancesScaled18;
    uint256 indexIn;
    uint256 indexOut;
    address router;
    bytes userData;
  }

  uint256 public outMultiplier = 3e18; // 3x in WAD

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  function onSwap(PoolSwapParams memory _request) external view returns (uint256 _amountOutScaled18) {
    _amountOutScaled18 = (_request.amountGivenScaled18 * outMultiplier) / 1e18;
  }
}

contract MockBalancerV3StableVault {
  IERC20 internal immutable _token0;
  IERC20 internal immutable _token1;

  uint256 internal _swapFeePercentage;
  uint256 internal _scaling0;
  uint256 internal _scaling1;
  uint256 internal _rate0;
  uint256 internal _rate1;
  uint256 internal _balance0;
  uint256 internal _balance1;
  bool internal _swapHooksEnabled;

  constructor(IERC20 token0_, IERC20 token1_) {
    _token0 = token0_;
    _token1 = token1_;
    _scaling0 = 1;
    _scaling1 = 1;
    _rate0 = 1e18;
    _rate1 = 1e18;
    _balance0 = 100e18;
    _balance1 = 100e18;
  }

  function setSwapFeePercentage(uint256 swapFeePercentage_) external {
    _swapFeePercentage = swapFeePercentage_;
  }

  function setPoolTokenRates(uint256 scaling0_, uint256 scaling1_, uint256 rate0_, uint256 rate1_) external {
    _scaling0 = scaling0_;
    _scaling1 = scaling1_;
    _rate0 = rate0_;
    _rate1 = rate1_;
  }

  function setCurrentLiveBalances(uint256 balance0_, uint256 balance1_) external {
    _balance0 = balance0_;
    _balance1 = balance1_;
  }

  function setSwapHooksEnabled(bool swapHooksEnabled_) external {
    _swapHooksEnabled = swapHooksEnabled_;
  }

  function getPoolTokenCountAndIndexOfToken(
    address,
    IERC20 token
  ) external view returns (uint256 tokenCount, uint256 index) {
    tokenCount = 2;
    if (address(token) == address(_token0)) return (tokenCount, 0);
    if (address(token) == address(_token1)) return (tokenCount, 1);
    revert('invalid-token');
  }

  function getPoolTokenRates(address)
    external
    view
    returns (uint256[] memory decimalScalingFactors, uint256[] memory tokenRates)
  {
    decimalScalingFactors = new uint256[](2);
    decimalScalingFactors[0] = _scaling0;
    decimalScalingFactors[1] = _scaling1;

    tokenRates = new uint256[](2);
    tokenRates[0] = _rate0;
    tokenRates[1] = _rate1;
  }

  function getCurrentLiveBalances(address) external view returns (uint256[] memory balancesLiveScaled18) {
    balancesLiveScaled18 = new uint256[](2);
    balancesLiveScaled18[0] = _balance0;
    balancesLiveScaled18[1] = _balance1;
  }

  function getStaticSwapFeePercentage(address) external view returns (uint256 swapFeePercentage) {
    swapFeePercentage = _swapFeePercentage;
  }

  function getHooksConfig(address)
    external
    view
    returns (bool, bool, bool, bool, bool, bool, bool, bool, bool, bool, address)
  {
    return (
      false,
      false,
      false,
      _swapHooksEnabled,
      _swapHooksEnabled,
      _swapHooksEnabled,
      false,
      false,
      false,
      false,
      address(0)
    );
  }
}

contract MockCurvePoolForTest {
  ERC20ForTest public tokenIn;
  ERC20ForTest public tokenOut;
  uint256 public outMultiplier = 2e18; // 2x in WAD

  constructor(ERC20ForTest _tokenIn, ERC20ForTest _tokenOut) {
    tokenIn = _tokenIn;
    tokenOut = _tokenOut;
  }

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  // solhint-disable-next-line func-name-mixedcase
  function get_dy(int128, int128, uint256 _dx) external view returns (uint256 _dy) {
    _dy = (_dx * outMultiplier) / 1e18;
  }

  function exchange(int128, int128, uint256 _dx, uint256 _minDy) external returns (uint256 _dy) {
    tokenIn.transferFrom(msg.sender, address(this), _dx);
    _dy = (_dx * outMultiplier) / 1e18;
    require(_dy >= _minDy, 'min-out');
    tokenOut.mint(msg.sender, _dy);
  }
}

contract MockERC4626Vault is ERC20ForTest {
  ERC20ForTest public assetToken;
  uint256 public assetsPerShare = 2e18; // 2x in WAD

  constructor(address _assetToken) {
    assetToken = ERC20ForTest(_assetToken);
  }

  function asset() external view returns (address _asset) {
    return address(assetToken);
  }

  function convertToAssets(uint256 _shares) external view returns (uint256 _assets) {
    _assets = (_shares * assetsPerShare) / 1e18;
  }

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets) {
    _assets = (_shares * assetsPerShare) / 1e18;
  }

  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets) {
    require(_owner == msg.sender, 'invalid-owner');

    _burn(_owner, _shares);
    _assets = (_shares * assetsPerShare) / 1e18;
    assetToken.mint(_receiver, _assets);
  }
}

contract MockBeefyVaultForTest {
  ERC20ForTest public lpToken;
  uint256 public pricePerFullShare = 2e18;

  constructor(ERC20ForTest _lpToken) {
    lpToken = _lpToken;
  }

  function getPricePerFullShare() external view returns (uint256 _pricePerFullShare) {
    return pricePerFullShare;
  }

  function withdraw(uint256 _shares) external {
    lpToken.mint(msg.sender, _shares);
  }
}

contract MockYearnVaultForTest {
  ERC20ForTest public lpToken;
  uint256 public pricePerShareValue = 2e18;

  constructor(ERC20ForTest _lpToken) {
    lpToken = _lpToken;
  }

  function pricePerShare() external view returns (uint256 _pricePerShare) {
    return pricePerShareValue;
  }

  function withdraw(uint256 _shares) external returns (uint256 _withdrawn) {
    _withdrawn = _shares;
    lpToken.mint(msg.sender, _withdrawn);
  }
}

contract MockVeloRouterForTest is IVelodromeRouterV2 {
  uint256 public swapOutMultiplier = 2e18; // 2x in WAD
  uint256 public removeAperLp = 10e18;
  uint256 public removeBperLp = 5e18;
  uint256 public lastRemoveLiquidityDeadline;
  uint256 public lastSwapDeadline;

  function setSwapOutMultiplier(uint256 _multiplier) external {
    swapOutMultiplier = _multiplier;
  }

  function setRemovePerLp(uint256 _aPerLp, uint256 _bPerLp) external {
    removeAperLp = _aPerLp;
    removeBperLp = _bPerLp;
  }

  function getAmountsOut(uint256 _amountIn, Route[] calldata) external view returns (uint256[] memory _amounts) {
    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = (_amountIn * swapOutMultiplier) / 1e18;
  }

  function swapExactTokensForTokens(
    uint256 _amountIn,
    uint256,
    Route[] calldata _routes,
    address _to,
    uint256 _deadline
  ) external returns (uint256[] memory _amounts) {
    lastSwapDeadline = _deadline;
    ERC20ForTest(_routes[0].from).transferFrom(msg.sender, address(this), _amountIn);
    uint256 _amountOut = (_amountIn * swapOutMultiplier) / 1e18;
    ERC20ForTest(_routes[0].to).mint(_to, _amountOut);

    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = _amountOut;
  }

  function removeLiquidity(
    address _tokenA,
    address _tokenB,
    bool,
    uint256 _liquidity,
    uint256,
    uint256,
    address _to,
    uint256 _deadline
  ) external returns (uint256 _amountA, uint256 _amountB) {
    lastRemoveLiquidityDeadline = _deadline;
    _amountA = (_liquidity * removeAperLp) / 1e18;
    _amountB = (_liquidity * removeBperLp) / 1e18;
    ERC20ForTest(_tokenA).mint(_to, _amountA);
    ERC20ForTest(_tokenB).mint(_to, _amountB);
  }
}

contract MockVeloRouterWithQuoteExecutionMismatchForTest is IVelodromeRouterV2 {
  uint256 public previewSwapOutMultiplier = 2e18; // 2x in WAD
  uint256 public executeSwapOutMultiplier = 1.5e18; // 1.5x in WAD
  uint256 public removeAperLp = 5e18;
  uint256 public removeBperLp = 2.5e18;

  function setPreviewSwapOutMultiplier(uint256 _multiplier) external {
    previewSwapOutMultiplier = _multiplier;
  }

  function setExecuteSwapOutMultiplier(uint256 _multiplier) external {
    executeSwapOutMultiplier = _multiplier;
  }

  function setRemovePerLp(uint256 _aPerLp, uint256 _bPerLp) external {
    removeAperLp = _aPerLp;
    removeBperLp = _bPerLp;
  }

  function getAmountsOut(uint256 _amountIn, Route[] calldata) external view returns (uint256[] memory _amounts) {
    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = (_amountIn * previewSwapOutMultiplier) / 1e18;
  }

  function swapExactTokensForTokens(
    uint256 _amountIn,
    uint256 _amountOutMin,
    Route[] calldata _routes,
    address _to,
    uint256
  ) external returns (uint256[] memory _amounts) {
    ERC20ForTest(_routes[0].from).transferFrom(msg.sender, address(this), _amountIn);
    uint256 _amountOut = (_amountIn * executeSwapOutMultiplier) / 1e18;
    require(_amountOut >= _amountOutMin, 'min-out');
    ERC20ForTest(_routes[0].to).mint(_to, _amountOut);

    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = _amountOut;
  }

  function removeLiquidity(
    address _tokenA,
    address _tokenB,
    bool,
    uint256 _liquidity,
    uint256,
    uint256,
    address _to,
    uint256
  ) external returns (uint256 _amountA, uint256 _amountB) {
    _amountA = (_liquidity * removeAperLp) / 1e18;
    _amountB = (_liquidity * removeBperLp) / 1e18;
    ERC20ForTest(_tokenA).mint(_to, _amountA);
    ERC20ForTest(_tokenB).mint(_to, _amountB);
  }
}

contract MockVeloPairForTest is ERC20ForTest {
  address public token0;
  address public token1;
  uint256 public reserve0;
  uint256 public reserve1;

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  function setState(uint256 _reserve0, uint256 _reserve1, uint256 _supply) external {
    reserve0 = _reserve0;
    reserve1 = _reserve1;
    _mint(address(this), _supply);
  }

  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _timestampLast) {
    return (reserve0, reserve1, block.timestamp);
  }
}

contract MockERC4626VaultForTest is ERC20ForTest {
  ERC20ForTest public assetToken;

  constructor(address _assetToken) {
    assetToken = ERC20ForTest(_assetToken);
  }

  function previewRedeem(uint256 _shares) external pure returns (uint256 _assets) {
    _assets = _shares;
  }

  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets) {
    require(_owner == msg.sender, 'invalid-owner');
    _burn(_owner, _shares);
    _assets = _shares;
    assetToken.mint(_receiver, _assets);
  }
}

contract MockERC4626VaultForMinOut is ERC20ForTest {
  ERC20ForTest public assetToken;
  uint256 public assetsPerShare = 2e18;

  constructor(address _assetToken) {
    assetToken = ERC20ForTest(_assetToken);
  }

  function previewRedeem(uint256 _shares) external view returns (uint256 _assets) {
    _assets = (_shares * assetsPerShare) / 1e18;
  }

  function redeem(uint256 _shares, address _receiver, address _owner) external returns (uint256 _assets) {
    require(_owner == msg.sender, 'invalid-owner');
    _burn(_owner, _shares);
    _assets = (_shares * assetsPerShare) / 1e18;
    assetToken.mint(_receiver, _assets);
  }
}

contract MockBeefyVaultForMinOut {
  ERC20ForTest public lpToken;
  uint256 public pricePerFullShare = 1e18;

  constructor(ERC20ForTest _lpToken) {
    lpToken = _lpToken;
  }

  function getPricePerFullShare() external view returns (uint256 _pricePerFullShare) {
    return pricePerFullShare;
  }

  function withdraw(uint256 _shares) external {
    lpToken.mint(msg.sender, _shares);
  }
}

contract MockYearnVaultForMinOut {
  ERC20ForTest public lpToken;
  uint256 public _pricePerShare = 1e18;

  constructor(ERC20ForTest _lpToken) {
    lpToken = _lpToken;
  }

  function pricePerShare() external view returns (uint256 _pricePerShareOut) {
    return _pricePerShare;
  }

  function withdraw(uint256 _shares) external returns (uint256 _withdrawn) {
    _withdrawn = _shares;
    lpToken.mint(msg.sender, _withdrawn);
  }
}

contract MockVeloRouterForMinOut is IVelodromeRouterV2 {
  uint256 public amountAperLp = 1e18;
  uint256 public amountBperLp;

  function setRemovePerLp(uint256 _amountAperLp, uint256 _amountBperLp) external {
    amountAperLp = _amountAperLp;
    amountBperLp = _amountBperLp;
  }

  function getAmountsOut(uint256 _amountIn, Route[] calldata) external pure returns (uint256[] memory _amounts) {
    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = _amountIn;
  }

  function swapExactTokensForTokens(
    uint256 _amountIn,
    uint256,
    Route[] calldata _routes,
    address _to,
    uint256
  ) external returns (uint256[] memory _amounts) {
    ERC20ForTest(_routes[0].from).transferFrom(msg.sender, address(this), _amountIn);
    ERC20ForTest(_routes[0].to).mint(_to, _amountIn);

    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = _amountIn;
  }

  function removeLiquidity(
    address _tokenA,
    address _tokenB,
    bool,
    uint256 _liquidity,
    uint256,
    uint256,
    address _to,
    uint256
  ) external returns (uint256 _amountA, uint256 _amountB) {
    _amountA = (_liquidity * amountAperLp) / 1e18;
    _amountB = (_liquidity * amountBperLp) / 1e18;
    ERC20ForTest(_tokenA).mint(_to, _amountA);
    ERC20ForTest(_tokenB).mint(_to, _amountB);
  }
}

contract MockVeloRouter {
  uint256 public swapOutMultiplier = 2e18; // 2x in WAD
  uint256 public removeAperLp = 5e18;
  uint256 public removeBperLp = 10e18;
  uint256 public lastRemoveLiquidityDeadline;

  function setSwapOutMultiplier(uint256 _multiplier) external {
    swapOutMultiplier = _multiplier;
  }

  function setRemovePerLp(uint256 _aPerLp, uint256 _bPerLp) external {
    removeAperLp = _aPerLp;
    removeBperLp = _bPerLp;
  }

  struct Route {
    address from;
    address to;
    bool stable;
    address factory;
  }

  function getAmountsOut(uint256 _amountIn, Route[] calldata) external view returns (uint256[] memory _amounts) {
    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = (_amountIn * swapOutMultiplier) / 1e18;
  }

  function swapExactTokensForTokens(
    uint256 _amountIn,
    uint256 _amountOutMin,
    Route[] calldata _routes,
    address _to,
    uint256
  ) external returns (uint256[] memory _amounts) {
    ERC20ForTest(_routes[0].from).transferFrom(msg.sender, address(this), _amountIn);
    uint256 _amountOut = (_amountIn * swapOutMultiplier) / 1e18;
    require(_amountOut >= _amountOutMin, 'min-out');
    ERC20ForTest(_routes[0].to).mint(_to, _amountOut);

    _amounts = new uint256[](2);
    _amounts[0] = _amountIn;
    _amounts[1] = _amountOut;
  }

  function removeLiquidity(
    address _tokenA,
    address _tokenB,
    bool,
    uint256 _liquidity,
    uint256 _amountAMin,
    uint256 _amountBMin,
    address _to,
    uint256 _deadline
  ) external returns (uint256 _amountA, uint256 _amountB) {
    lastRemoveLiquidityDeadline = _deadline;
    _amountA = (_liquidity * removeAperLp) / 1e18;
    _amountB = (_liquidity * removeBperLp) / 1e18;
    require(_amountA >= _amountAMin && _amountB >= _amountBMin, 'min-out');
    ERC20ForTest(_tokenA).mint(_to, _amountA);
    ERC20ForTest(_tokenB).mint(_to, _amountB);
  }
}

contract MockVeloPair is ERC20ForTest {
  address public token0;
  address public token1;
  uint256 public reserve0;
  uint256 public reserve1;

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  function setState(uint256 _reserve0, uint256 _reserve1, uint256 _supply) external {
    reserve0 = _reserve0;
    reserve1 = _reserve1;
    _mint(address(this), _supply);
  }

  function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _timestampLast) {
    return (reserve0, reserve1, block.timestamp);
  }
}

contract MockVeloCLRouterForTest {
  ERC20ForTest public tokenIn;
  ERC20ForTest public tokenOut;
  uint256 public outMultiplier = 2e18; // 2x in WAD
  uint256 public amountToSpend;
  bool public useAmountToSpend;

  address public lastRecipient;
  uint256 public lastAmountIn;
  uint256 public lastMinOut;
  int24 public lastTickSpacing;
  uint160 public lastSqrtPriceLimit;

  constructor(ERC20ForTest _tokenIn, ERC20ForTest _tokenOut) {
    tokenIn = _tokenIn;
    tokenOut = _tokenOut;
  }

  function setOutMultiplier(uint256 _outMultiplier) external {
    outMultiplier = _outMultiplier;
  }

  function setAmountToSpend(uint256 _amountToSpend) external {
    amountToSpend = _amountToSpend;
    useAmountToSpend = true;
  }

  function exactInputSingle(IVeloCLRouter.ExactInputSingleParams calldata _params)
    external
    returns (uint256 _amountOut)
  {
    lastRecipient = _params.recipient;
    lastAmountIn = _params.amountIn;
    lastMinOut = _params.amountOutMinimum;
    lastTickSpacing = _params.tickSpacing;
    lastSqrtPriceLimit = _params.sqrtPriceLimitX96;

    uint256 _amountSpent = useAmountToSpend ? amountToSpend : _params.amountIn;
    tokenIn.transferFrom(msg.sender, address(this), _amountSpent);
    _amountOut = (_params.amountIn * outMultiplier) / 1e18;
    require(_amountOut >= _params.amountOutMinimum, 'min-out');
    tokenOut.mint(_params.recipient, _amountOut);
  }
}

contract MockVeloCLPoolForTest {
  address public token0;
  address public token1;
  uint24 public feePips;
  int24 public spacing;
  uint160 public currentSqrtPriceX96;
  int24 public currentTick;
  uint128 public currentLiquidity;

  mapping(int16 => uint256) public bitmapByWord;
  mapping(int24 => int128) public liquidityNetByTick;

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
    feePips = 3000;
    spacing = 60;
    currentSqrtPriceX96 = 79_228_162_514_264_337_593_543_950_336; // 2**96
    currentTick = 0;
    currentLiquidity = 1e18;
  }

  function setFee(uint24 _feePips) external {
    feePips = _feePips;
  }

  function setTickSpacing(int24 _spacing) external {
    spacing = _spacing;
  }

  function setSlot0(uint160 _sqrtPriceX96, int24 _tick) external {
    currentSqrtPriceX96 = _sqrtPriceX96;
    currentTick = _tick;
  }

  function setLiquidity(uint128 _liquidity) external {
    currentLiquidity = _liquidity;
  }

  function setBitmap(int16 _word, uint256 _bitmap) external {
    bitmapByWord[_word] = _bitmap;
  }

  function setLiquidityNetAtTick(int24 _tick, int128 _liquidityNet) external {
    liquidityNetByTick[_tick] = _liquidityNet;
  }

  function fee() external view returns (uint24 _feePips) {
    return feePips;
  }

  function tickSpacing() external view returns (int24 _tickSpacing) {
    return spacing;
  }

  function slot0()
    external
    view
    returns (
      uint160 _sqrtPriceX96,
      int24 _tick,
      uint16 _observationIndex,
      uint16 _observationCardinality,
      uint16 _observationCardinalityNext,
      bool _unlocked
    )
  {
    return (currentSqrtPriceX96, currentTick, 0, 0, 0, true);
  }

  function liquidity() external view returns (uint128 _liquidity) {
    return currentLiquidity;
  }

  function ticks(int24 _tick)
    external
    view
    returns (
      uint128 _liquidityGross,
      int128 _liquidityNet,
      int128 _stakedLiquidityNet,
      uint256 _feeGrowthOutside0X128,
      uint256 _feeGrowthOutside1X128,
      uint256 _rewardGrowthOutsideX128,
      int56 _tickCumulativeOutside,
      uint160 _secondsPerLiquidityOutsideX128,
      uint32 _secondsOutside,
      bool _initialized
    )
  {
    int128 _net = liquidityNetByTick[_tick];
    return (0, _net, 0, 0, 0, 0, 0, 0, 0, _net != 0);
  }

  function tickBitmap(int16 _wordPosition) external view returns (uint256 _bitmap) {
    return bitmapByWord[_wordPosition];
  }
}

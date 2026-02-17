// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {VeloSwapStep} from '@contracts/strategySteps/VeloSwapStep.sol';
import {VeloLPRemovalStep} from '@contracts/strategySteps/VeloLPRemovalStep.sol';

contract MockVeloRouter {
  uint256 public swapOutMultiplier = 2e18; // 2x in WAD
  uint256 public removeAperLp = 5e18;
  uint256 public removeBperLp = 10e18;

  function setSwapOutMultiplier(uint256 _multiplier) external {
    swapOutMultiplier = _multiplier;
  }

  function setRemovePerLp(uint256 _aPerLp, uint256 _bPerLp) external {
    removeAperLp = _aPerLp;
    removeBperLp = _bPerLp;
  }

  function getAmountOut(uint256 _amountIn, address, address) external view returns (uint256 _amountOut, bool _stable) {
    _amountOut = (_amountIn * swapOutMultiplier) / 1e18;
    _stable = false;
  }

  function swapExactTokensForTokensSimple(
    uint256 _amountIn,
    uint256 _amountOutMin,
    address _tokenFrom,
    address _tokenTo,
    bool,
    address _to,
    uint256
  ) external returns (uint256[] memory _amounts) {
    ERC20ForTest(_tokenFrom).transferFrom(msg.sender, address(this), _amountIn);
    uint256 _amountOut = (_amountIn * swapOutMultiplier) / 1e18;
    require(_amountOut >= _amountOutMin, 'min-out');
    ERC20ForTest(_tokenTo).mint(_to, _amountOut);

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
    uint256
  ) external returns (uint256 _amountA, uint256 _amountB) {
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

abstract contract Base is HaiTest {
  MockVeloRouter router;
  ERC20ForTest tokenA;
  ERC20ForTest tokenB;

  function setUp() public virtual {
    router = new MockVeloRouter();
    tokenA = new ERC20ForTest();
    tokenB = new ERC20ForTest();
  }
}

contract Unit_VeloSwapStep is Base {
  VeloSwapStep step;

  function setUp() public override {
    super.setUp();
    step = new VeloSwapStep();
  }

  function test_Preview() public {
    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(router),
      tokenIn: address(tokenA),
      tokenOut: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 10e18);
    assertEq(_preview.length, 1);
    assertEq(_preview[0], 20e18);
  }

  function test_Execute() public {
    tokenA.mint(address(step), 10e18);

    VeloSwapStep.Data memory _data = VeloSwapStep.Data({
      router: address(router),
      tokenIn: address(tokenA),
      tokenOut: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](1);
    _minOuts[0] = 20e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 10e18, _minOuts);

    assertEq(_out.length, 1);
    assertEq(_out[0], 20e18);
    assertEq(tokenB.balanceOf(address(step)), 20e18);
  }
}

contract Unit_VeloLPRemovalStep is Base {
  VeloLPRemovalStep step;
  MockVeloPair lpToken;

  function setUp() public override {
    super.setUp();
    step = new VeloLPRemovalStep();
    lpToken = new MockVeloPair(address(tokenA), address(tokenB));

    lpToken.setState(5000e18, 10_000e18, 900e18);
    lpToken.mint(address(step), 100e18);
  }

  function test_Preview_MultiOutput() public {
    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _preview = step.preview(abi.encode(_data), 100e18);
    assertEq(_preview.length, 2);
    assertEq(_preview[0], 500e18);
    assertEq(_preview[1], 1000e18);
  }

  function test_Execute_MultiOutput() public {
    VeloLPRemovalStep.Data memory _data = VeloLPRemovalStep.Data({
      router: address(router),
      lpToken: address(lpToken),
      tokenA: address(tokenA),
      tokenB: address(tokenB),
      stable: false,
      deadlineBuffer: 1 hours
    });

    uint256[] memory _minOuts = new uint256[](2);
    _minOuts[0] = 500e18;
    _minOuts[1] = 1000e18;
    uint256[] memory _out = step.execute(abi.encode(_data), 100e18, _minOuts);

    assertEq(_out.length, 2);
    assertEq(_out[0], 500e18);
    assertEq(_out[1], 1000e18);
    assertEq(tokenA.balanceOf(address(step)), 500e18);
    assertEq(tokenB.balanceOf(address(step)), 1000e18);
  }
}

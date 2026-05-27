// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Math} from '@libraries/Math.sol';

contract MathForTest {
  function add(uint256 _x, int256 _y) external pure returns (uint256 _add) {
    return Math.add(_x, _y);
  }

  function sub(uint256 _x, int256 _y) external pure returns (uint256 _sub) {
    return Math.sub(_x, _y);
  }

  function absolute(int256 _x) external pure returns (uint256 _z) {
    return Math.absolute(_x);
  }
}

contract Unit_Math is HaiTest {
  MathForTest internal math;

  uint256 internal constant INT256_MIN_ABS = uint256(1) << 255;

  function setUp() public {
    math = new MathForTest();
  }

  function test_Add_Int256Min() public view {
    assertEq(math.add(INT256_MIN_ABS, type(int256).min), 0);
  }

  function test_Revert_Add_Int256Min_WhenResultWouldUnderflow() public {
    vm.expectRevert();
    math.add(INT256_MIN_ABS - 1, type(int256).min);
  }

  function test_Sub_Int256Min() public view {
    assertEq(math.sub(0, type(int256).min), INT256_MIN_ABS);
  }

  function test_Revert_Sub_Int256Min_WhenResultWouldOverflow() public {
    vm.expectRevert();
    math.sub(type(uint256).max - INT256_MIN_ABS + 1, type(int256).min);
  }

  function test_Absolute_Int256Min() public view {
    assertEq(math.absolute(type(int256).min), INT256_MIN_ABS);
  }
}

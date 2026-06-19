// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Encoding} from '@libraries/Encoding.sol';

contract EncodingForTest {
  using Encoding for bytes;

  function toUint256(bytes memory _data) external pure returns (uint256 _uint256) {
    return _data.toUint256();
  }

  function toInt256(bytes memory _data) external pure returns (int256 _int256) {
    return _data.toInt256();
  }

  function toAddress(bytes memory _data) external pure returns (address _address) {
    return _data.toAddress();
  }

  function toBool(bytes memory _data) external pure returns (bool _bool) {
    return _data.toBool();
  }
}

contract Unit_Encoding is HaiTest {
  EncodingForTest internal encoding;

  function setUp() public {
    encoding = new EncodingForTest();
  }

  function test_ToUint256() public view {
    assertEq(encoding.toUint256(abi.encode(uint256(123))), 123);
  }

  function test_ToInt256() public view {
    assertEq(encoding.toInt256(abi.encode(int256(-123))), -123);
  }

  function test_ToAddress() public view {
    address _account = address(0x1234);
    assertEq(encoding.toAddress(abi.encode(_account)), _account);
  }

  function test_ToBool() public view {
    assertTrue(encoding.toBool(abi.encode(true)));
    assertFalse(encoding.toBool(abi.encode(false)));
  }

  function test_Revert_ToUint256_InvalidDataLength() public {
    vm.expectRevert(Encoding.Encoding_InvalidDataLength.selector);
    encoding.toUint256(hex'01');
  }

  function test_Revert_ToInt256_InvalidDataLength() public {
    vm.expectRevert(Encoding.Encoding_InvalidDataLength.selector);
    encoding.toInt256(hex'01');
  }

  function test_Revert_ToAddress_InvalidDataLength() public {
    vm.expectRevert(Encoding.Encoding_InvalidDataLength.selector);
    encoding.toAddress(hex'01');
  }

  function test_Revert_ToBool_InvalidDataLength() public {
    vm.expectRevert(Encoding.Encoding_InvalidDataLength.selector);
    encoding.toBool(hex'01');
  }
}

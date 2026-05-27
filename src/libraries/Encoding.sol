// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title Encoding
 * @notice This library contains functions for decoding data into common types
 */
library Encoding {
  // --- Errors ---

  error Encoding_InvalidDataLength();

  // --- Methods ---

  /// @dev Decodes a bytes array into a uint256
  function toUint256(bytes memory _data) internal pure returns (uint256 _uint256) {
    _validateDataLength(_data);
    assembly {
      _uint256 := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into an int256
  function toInt256(bytes memory _data) internal pure returns (int256 _int256) {
    _validateDataLength(_data);
    assembly {
      _int256 := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into an address
  function toAddress(bytes memory _data) internal pure returns (address _address) {
    _validateDataLength(_data);
    assembly {
      _address := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into a bool
  function toBool(bytes memory _data) internal pure returns (bool _bool) {
    _validateDataLength(_data);
    assembly {
      _bool := mload(add(_data, 0x20))
    }
  }

  /// @dev Validates that the bytes array contains at least one full word
  function _validateDataLength(bytes memory _data) internal pure {
    if (_data.length < 32) revert Encoding_InvalidDataLength();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IVeNFTManager is IAuthorizable, IModifiable {
  // --- Errors ---

  /// @notice Throws when trying to set a null secondary manager
  error VeNFTManager_NullSecondary();

  /// @notice Throws when trying to set a null voter
  error VeNFTManager_NullVoter();

  /// @notice Throws when trying to set a null root voting rewards factory
  error VeNFTManager_NullRootVotingRewardsFactory();

  // --- Data ---

  /**
   * @notice Address of the secondary manager contract
   * @return _secondaryManager Address of the secondary manager
   */
  function secondaryManager() external view returns (address _secondaryManager);
}

// --- Administration ---

/// @inheritdoc Modifiable
function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
  if (_param == 'secondaryManager') {
    _params.secondaryManager = _data.toAddress();
  } else {
    revert UnrecognizedParam();
  }
}

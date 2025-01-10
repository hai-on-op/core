// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from "@interfaces/utils/IAuthorizable.sol";

interface IRewardDistributor is IAuthorizable {
    // --- Events ---

    // --- Errors ---

    // --- Data ---

    /**
     * @notice Counter of the current epoch
     * @return _epochCounter Counter of the current epoch
     */
    function epochCounter() external view returns (uint256 _epochCounter);

    /**
     * @notice Duration of each epoch
     * @return _epochDuration Duration of each epoch
     */
    function epochDuration() external view returns (uint256 _epochDuration);

    /**
     * @notice Timestamp of the last time the merkle roots were updated
     * @return _lastUpdatedTime Timestamp of the last time the merkle roots were updated
     */
    function lastUpdatedTime() external view returns (uint256 _lastUpdatedTime);

    /**
     * @notice Address of the account that can set the merkle root
     * @return _rootSetter Address of the account that can set the merkle root
     */
    function rootSetter() external view returns (address _rootSetter);

    /**
     * @notice Mapping of the merkle root for each token
     * @param _token Address of the token
     * @return _root Merkle root for the token
     */
    function merkleRoots(address _token) external view returns (bytes32 _root);
}

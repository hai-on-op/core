// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IMerkleDistributor} from "@interfaces/tokens/IMerkleDistributor.sol";

import {IAuthorizable} from "@interfaces/utils/IAuthorizable.sol";

interface IMerkleDistributorFactory is IAuthorizable {
    // --- Events ---

    /**
     * @notice Emitted when a new MerkleDistributor contract is deployed
     * @param _merkleDistributor Address of the deployed MerkleDistributor contract
     * @param  _token Address of the ERC20 token to be distributed
     * @param _root The merkle root of the token distribution
     * @param _totalClaimable Total amount of tokens to be distributed
     * @param _claimPeriodStart Timestamp when the claim period starts
     * @param _claimPeriodEnd Timestamp when the claim period ends
     */
    event DeployMerkleDistributor(
        address indexed _merkleDistributor,
        address _token,
        bytes32 _root,
        uint256 _totalClaimable,
        uint256 _claimPeriodStart,
        uint256 _claimPeriodEnd
    );

    // --- Methods ---

    /**
     * @notice Deploys a MerkleDistributorChild contract
     * @param  _token Address of the ERC20 token to be distributed
     * @param  _root Bytes32 representation of the merkle root
     * @param  _totalClaimable Total amount of tokens to be distributed
     * @param  _claimPeriodStart Timestamp when the claim period starts
     * @param  _claimPeriodEnd Timestamp when the claim period ends* @param  _merkleDistributorParams MerkleDistributor valid parameters struct
     * @return _merkleDistributor Address of the deployed MerkleDistributorChild contract
     */
    function deployMerkleDistributor(
        address _token,
        bytes32 _root,
        uint256 _totalClaimable,
        uint256 _claimPeriodStart,
        uint256 _claimPeriodEnd
    ) external returns (IMerkleDistributor _merkleDistributor);
}

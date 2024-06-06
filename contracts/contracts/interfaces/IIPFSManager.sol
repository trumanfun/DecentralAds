// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IIPFSManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Interface for managing IPFS-related operations and creating metadata.
 */
interface IIPFSManager {
    /**
     * @dev Creates metadata for a contract or token and returns a unique identifier (request ID).
     * @param isContract Flag indicating whether the metadata is for a contract or a token.
     * @param args An array of string arguments for creating the metadata.
     * @return requestId The unique identifier (request ID) associated with the IPFS metadata creation request.
     */
    function createMetadata(
        bool isContract,
        string[] memory args
    ) external returns (bytes32);
}
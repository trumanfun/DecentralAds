// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAdsManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Interface for managing advertisements, metadata, lotteries, and pricing.
 */
interface IAdsManager {
    /**
     * @dev Creates metadata for a contract or token, associating it with the provided factory and token IDs.
     * @param contractOrToken Flag indicating whether the metadata is for a contract or a token.
     * @param factoryId The ID of the AdsFactory contract associated with the metadata.
     * @param tokenId The ID of the token associated with the metadata (if applicable).
     * @param args An array of string arguments for creating the metadata.
     */
    function createMetadata(
        bool contractOrToken,
        uint256 factoryId,
        uint256 tokenId,
        string[] memory args
    ) external;

    /**
     * @dev Sets the IPFS CID for a given request ID.
     * @param requestId The unique identifier for the request.
     * @param ipfsUri The IPFS URI to be associated with the request.
     */
    function setIpfsCID(bytes32 requestId, string memory ipfsUri) external;

    /**
     * @dev Initiates a lottery for a specific factory and token ID.
     * @param factoryId The ID of the AdsFactory contract associated with the lottery.
     * @param tokenId The ID of the token associated with the lottery.
     */
    function startLottery(uint256 factoryId, uint256 tokenId) external;

    /**
     * @dev Sets the winner of a lottery for a given request ID and random value.
     * @param requestId The unique identifier for the lottery request.
     * @param randomValue The random value used to determine the winner.
     */
    function setLotteryWinner(uint256 requestId, uint256 randomValue) external;

    /**
     * @dev Calculates the native token price for a given amount in USD.
     * @param usdAmount The amount in USD for which to calculate the native token price.
     * @return The calculated native token price as an integer.
     */
    function getTokenNativePrice(uint256 usdAmount) external returns (int);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceFeedManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Interface for retrieving native token prices based on a provided USD amount.
 */
interface IPriceFeedManager {
    /**
     * @dev Retrieves the equivalent native token price for a given USD amount.
     * @param usdAmount The amount in USD for which to determine the equivalent native token price.
     * @return coinPrice The equivalent native token price.
     */
    function getTokenNativePrice(
        int usdAmount
    ) external view returns (int coinPrice);
}
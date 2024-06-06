// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILotteryManager
 * @author Andrea Tedesco (@andreatedesco).
 * @dev Interface for managing lottery-related operations.
 */
interface ILotteryManager {
    /**
     * @dev Initiates the start of a lottery and returns the lottery's unique identifier (lottery ID).
     * @return lotteryId The unique identifier (lottery ID) associated with the started lottery.
     */
    function startLottery() external returns (uint256);
}
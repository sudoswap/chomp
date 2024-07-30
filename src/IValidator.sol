// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IValidator {
    // Validates that e.g. there are 6 mons per team w/ 4 moves each
    function validateGameStart(Battle calldata b, address gameStartCaller) external returns (bool);

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validateMove(bytes32 battleKey, uint256 moveIndex, address player, bytes calldata extraData)
        external
        view
        returns (bool);

    // Computes which player (p1 or p2) should move first
    function computePriorityPlayerIndex(bytes32 battleKey, uint256 rng) external view returns (uint256);

    // Validates that the game is over, returns address(0) if no winner, otherwise returns the winner
    function validateGameOver(bytes32 battleKey, uint256 priorityPlayerIndex) external view returns (address);

    // Validates that there is a valid timeout, returns address(0) if no winner, otherwise returns the winner
    function validateTimeout(bytes32 battleKey, uint256 presumedAFKPlayerIndex) external view returns (address);
}

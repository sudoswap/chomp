// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IHook {
    // Validates that e.g. there are 6 mons per team w/ 4 moves each
    function validateGameStart(Battle calldata b, address gameStartCaller) external returns (bool);

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validateMove(Battle calldata b, BattleState calldata state, uint256 moveIdx, address player)
        external
        pure
        returns (bool);

    // Computes which player (p1 or p2) should move first
    function computePriorityPlayer(Battle calldata b, BattleState calldata state, uint256 rng) external pure returns (uint256);

    // Validates that the game is over, returns 0 for false, 1 for p1 wins, and 2 for p2 wins
    function validateGameOver(Battle calldata b, BattleState calldata state) external pure returns (uint256);

    // Clear out temporary battle effects
    function modifyMonStateAfterSwitch(MonState calldata mon) external pure returns (MonState memory updatedMon);
}

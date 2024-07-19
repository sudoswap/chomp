// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IHook {
    // Validates that e.g. there are 6 mons per team w/ 4 moves each
    function validateGameStart(Battle calldata b) external;

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validateMove(Battle calldata b, BattleState calldata state, uint256 moveIdx, address player)
        external
        pure
        returns (bool);

    function modifyInitialState(BattleState calldata state) external pure returns (BattleState memory updatedState);

    // Clear out temporary battle effects
    function modifyMonStateAfterSwitch(MonState calldata mon) external pure returns (MonState memory updatedMon);
}

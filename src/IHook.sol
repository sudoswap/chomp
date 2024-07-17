// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IHook {
    function validateGameStart(Battle calldata b) external;
    function modifyInitialState(BattleState calldata state) external pure returns (BattleState memory updatedState);
}

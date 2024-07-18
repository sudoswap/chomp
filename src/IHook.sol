// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IHook {
    function validateGameStart(Battle calldata b) external;
    function validateMove(Battle calldata b, BattleState calldata state, uint256 moveIdx, address player)
        external
        pure
        returns (bool);
    function modifyInitialState(BattleState calldata state) external pure returns (BattleState memory updatedState);
}

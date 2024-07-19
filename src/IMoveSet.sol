// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IMoveSet {
    function move(Battle calldata battle, BattleState calldata state, bytes calldata extraData)
        external
        pure
        returns (BattleState memory updatedState);
    function priority(Battle calldata battle, BattleState calldata state)
        external
        pure
        returns (uint256);
    function stamina(Battle calldata battle, BattleState calldata state)
        external
        pure
        returns (uint256);
    function moveType(Battle calldata battle, BattleState calldata state)
        external
        pure
        returns (uint256);
}

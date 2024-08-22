// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

interface IMonRegistry {
    function createMon(
        uint256 monId,
        MonStats memory mon,
        IMoveSet[] memory allowedMoves,
        IAbility[] memory allowedAbilities
    ) external;

    function modifyMon(
        uint256 monId,
        MonStats memory mon,
        IMoveSet[] memory movesToAdd,
        IMoveSet[] memory movesToRemove,
        IAbility[] memory abilitiesToAdd,
        IAbility[] memory abilitiesToRemove
    ) external;

    function getMonData(uint256 monId)
        external
        returns (MonStats memory mon, address[] memory moves, address[] memory abilities);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../moves/IMoveSet.sol";
import "../abilities/IAbility.sol";

interface ITeamRegistry {
    function createTeam(uint256[] memory monIndices, IMoveSet[][] memory moves, IAbility[] memory abilities) external;
    function updateTeam(
        uint256 teamIndex,
        uint256[] memory teamIndicesToOverride,
        uint256[] memory newMonIndices,
        IMoveSet[][] memory newMoves,
        IAbility[] memory newAbilities
    ) external;
    function getTeam(address player, uint256 teamIndex) external returns (Mon[] memory);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Structs.sol";

import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";

contract TestTeamRegistry is ITeamRegistry {

    mapping(address => Mon[]) public teams;

    function setTeam(address player, Mon[] memory team) public {
        teams[player] = team;
    }

    function getTeam(address player, uint256) external view returns (Mon[] memory) {
        return teams[player];
    }

    function updateTeam(
        uint256 teamIndex,
        uint256[] memory teamIndicesToOverride,
        uint256[] memory newMonIndices,
        IMoveSet[][] memory newMoves,
        IAbility[] memory newAbilities
    ) external {
        // No Op
    }

    function createTeam(uint256[] memory monIndices, IMoveSet[][] memory moves, IAbility[] memory abilities) external {
        // No Op
    }
}
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

    function getTeamCount(address player) external view returns (uint256) {
        return teams[player].length;
    }
}

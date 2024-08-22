// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

interface ITeamRegistry {
    function createTeam(uint256[] memory monIndices, IMoveSet[][] memory moves) external;
    function updateTeam(uint256[] memory teamIndices, uint256[] memory newMonIndices, IMoveSet[][] memory newMoves)
        external;
    function getTeam(address player, uint256 teamIndex) external returns (Mon[] memory);
}

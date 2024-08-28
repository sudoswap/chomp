// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

import "../abilities/IAbility.sol";
import "../moves/IMoveSet.sol";

interface ITeamRegistry {
    function getTeam(address player, uint256 teamIndex) external returns (Mon[] memory);
    function getTeamCount(address player) external returns (uint256);
}

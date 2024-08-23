// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

import "./IMonRegistry.sol";
import "./ITeamRegistry.sol";

contract DefaultTeamRegistry is ITeamRegistry {
    struct Args {
        IMonRegistry REGISTRY;
        uint256 MONS_PER_TEAM;
        uint256 MOVES_PER_MON;
    }

    error InvalidTeamSize();
    error InvalidNumMovesPerMon();
    error InvalidMove();
    error InvalidAbility();

    IMonRegistry immutable REGISTRY;
    uint256 immutable MONS_PER_TEAM;
    uint256 immutable MOVES_PER_MON;

    mapping(address => mapping(uint256 => Mon[])) public teams;
    mapping(address => uint256) public numTeams;

    constructor(Args memory args) {
        REGISTRY = args.REGISTRY;
        MONS_PER_TEAM = args.MONS_PER_TEAM;
        MOVES_PER_MON = args.MOVES_PER_MON;
    }

    function createTeam(uint256[] memory monIndices, IMoveSet[][] memory moves, IAbility[] memory abilities) external {
        if (monIndices.length != MONS_PER_TEAM) {
            revert InvalidTeamSize();
        }
        for (uint256 i; i < MONS_PER_TEAM; i++) {
            uint256 numMoves = moves[i].length;
            if (numMoves != MOVES_PER_MON) {
                revert InvalidNumMovesPerMon();
            }
            for (uint256 j; j < numMoves; j++) {
                if (!REGISTRY.isValidMove(monIndices[i], moves[i][j])) {
                    revert InvalidMove();
                }
            }
            if (!REGISTRY.isValidAbility(monIndices[i], abilities[i])) {
                revert InvalidAbility();
            }
        }

        // Initialize team
        uint256 teamId = numTeams[msg.sender];
        for (uint256 i; i < MONS_PER_TEAM; i++) {
            teams[msg.sender][teamId].push(
                Mon({stats: REGISTRY.getMonStats(monIndices[i]), moves: moves[i], ability: abilities[i]})
            );
        }

        // Update the team index
        numTeams[msg.sender] += 1;
    }

    function updateTeam(
        uint256 teamIndex,
        uint256[] memory teamMonIndicesToOverride,
        uint256[] memory newMonIndices,
        IMoveSet[][] memory newMoves,
        IAbility[] memory newAbilities
    ) external {
        uint256 numMonsToOverride = teamMonIndicesToOverride.length;

        // Verify that the new moves and abilities are valid
        for (uint256 i; i < numMonsToOverride; i++) {
            uint256 monIndex = newMonIndices[i];
            uint256 numMoves = newMoves[i].length;
            if (numMoves != MOVES_PER_MON) {
                revert InvalidNumMovesPerMon();
            }
            for (uint256 j; j < numMoves; j++) {
                if (!REGISTRY.isValidMove(monIndex, newMoves[i][j])) {
                    revert InvalidMove();
                }
            }
            if (!REGISTRY.isValidAbility(monIndex, newAbilities[i])) {
                revert InvalidAbility();
            }
        }

        // Update the team
        for (uint256 i; i < numMonsToOverride; i++) {
            uint256 monIndexToOverride = teamMonIndicesToOverride[i];
            teams[msg.sender][teamIndex][monIndexToOverride] =
                Mon({stats: REGISTRY.getMonStats(newMonIndices[i]), moves: newMoves[i], ability: newAbilities[i]});
        }
    }

    function getTeam(address player, uint256 teamIndex) external view returns (Mon[] memory) {
        return teams[player][teamIndex];
    }
}

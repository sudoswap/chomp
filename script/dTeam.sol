// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/Enums.sol";
import "../src/Structs.sol";

import {IAbility} from "../src/abilities/IAbility.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {DefaultTeamRegistry} from "../src/teams/DefaultTeamRegistry.sol";

contract dTeam is Script {
    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        DefaultTeamRegistry registry = DefaultTeamRegistry(vm.envAddress("DEFAULT_TEAM_REGISTRY"));

        // Set indices
        uint256[] memory monIndices = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            monIndices[i] = i;
        }

        // Set moves
        IMoveSet[][] memory moves = new IMoveSet[][](6);

        // Moves for mon0 (liftogg)
        // Moves: Blow/Philosophize/Allergies/Ineffable Blast
        moves[0] = new IMoveSet[](4);
        moves[0][0] = (IMoveSet(vm.envAddress("BLOW")));
        moves[0][1] = (IMoveSet(vm.envAddress("PHILOSOPHIZE")));
        moves[0][2] = (IMoveSet(vm.envAddress("ALLERGIES")));
        moves[0][3] = (IMoveSet(vm.envAddress("INEFFABLE_BLAST")));

        // Moves for mon1 (ghouliath)
        // Moves: Blow/Philosophize/Spook/Chill Out
        moves[1] = new IMoveSet[](4);
        moves[1][0] = (IMoveSet(vm.envAddress("BLOW")));
        moves[1][1] = (IMoveSet(vm.envAddress("PHILOSOPHIZE")));
        moves[1][2] = (IMoveSet(vm.envAddress("SPOOK")));
        moves[1][3] = (IMoveSet(vm.envAddress("CHILL_OUT")));

        // Moves for mon2 (gorillax)
        // Moves: SLEEP/Chill Out/Throw Rock/Allergies
        moves[2] = new IMoveSet[](4);
        moves[2][0] = (IMoveSet(vm.envAddress("SLEEP")));
        moves[2][1] = (IMoveSet(vm.envAddress("CHILL_OUT")));
        moves[2][2] = (IMoveSet(vm.envAddress("THROW_ROCK")));
        moves[2][3] = (IMoveSet(vm.envAddress("ALLERGIES")));

        // Moves for mon3 (inuitia)
        // Moves: Spook/Spark/Throw Rock/Ineffable Blast
        moves[3] = new IMoveSet[](4);
        moves[3][0] = (IMoveSet(vm.envAddress("SPOOK")));
        moves[3][1] = (IMoveSet(vm.envAddress("SPARK")));
        moves[3][2] = (IMoveSet(vm.envAddress("THROW_ROCK")));
        moves[3][3] = (IMoveSet(vm.envAddress("INEFFABLE_BLAST")));

        // Moves for mon4 (pengym)
        // Moves: Blow/Chill Out/Allergies/Ineffable Blast
        moves[4] = new IMoveSet[](4);
        moves[4][0] = (IMoveSet(vm.envAddress("BLOW")));
        moves[4][1] = (IMoveSet(vm.envAddress("CHILL_OUT")));
        moves[4][2] = (IMoveSet(vm.envAddress("ALLERGIES")));
        moves[4][3] = (IMoveSet(vm.envAddress("INEFFABLE_BLAST")));

        // Moves for mon5 (malalien)
        // Moves: Spark/Philosophize/Spook/Chill Out
        moves[5] = new IMoveSet[](4);
        moves[5][0] = (IMoveSet(vm.envAddress("SPARK")));
        moves[5][1] = (IMoveSet(vm.envAddress("PHILOSOPHIZE")));
        moves[5][2] = (IMoveSet(vm.envAddress("SPOOK")));
        moves[5][3] = (IMoveSet(vm.envAddress("CHILL_OUT")));

        // Abilities are all address(0) for now
        IAbility[] memory abilities = new IAbility[](6);
        for (uint256 i = 0; i < 6; i++) {
            abilities[i] = IAbility(address(0));
        }

        registry.createTeam(monIndices, moves, abilities);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/Enums.sol";
import "../src/Structs.sol";

import {IAbility} from "../src/abilities/IAbility.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {LazyTeamRegistry} from "../src/teams/LazyTeamRegistry.sol";
import {Engine} from "../src/Engine.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";

contract dTeam is Script {

    uint32 constant STAMINA = 5;

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        createMons();
        createTeam();
        vm.stopBroadcast();
    }

    function createMons() public {
        DefaultMonRegistry defaultMonRegistry = DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY"));

        // Initial mon creation values
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(0));

        IMoveSet[] memory moves = new IMoveSet[](9);
        moves[0] = IMoveSet(vm.envAddress("BLOW")); // Blow
        moves[1] = IMoveSet(vm.envAddress("PHILOSOPHIZE")); // Philosophize
        moves[2] = IMoveSet(vm.envAddress("SPOOK")); // Spook
        moves[3] = IMoveSet(vm.envAddress("SLEEP")); // Sleep
        moves[4] = IMoveSet(vm.envAddress("CHILL_OUT")); // Chill Out
        moves[5] = IMoveSet(vm.envAddress("SPARK")); // Spark
        moves[6] = IMoveSet(vm.envAddress("THROW_ROCK")); // Throw Rock
        moves[7] = IMoveSet(vm.envAddress("ALLERGIES")); // Allergies
        moves[8] = IMoveSet(vm.envAddress("INEFFABLE_BLAST")); // Ineffable Blast

        bytes32[] memory nameKey = new bytes32[](1);
        nameKey[0] = bytes32("name");

        /**
         * HP: 200-500 (low to max, avg around 250-350)
         *         Stamina: 5 (always)
         *         Everything else: 50-250, 200 is "high", 150 is "avg" 
         *         Total of 1000-1200
         */

        // Liftogg is bulky and fast, but not a strong attacker
        // BST sum: 350+150+150+150+150+150 = 1100
        MonStats memory sofabbiStats = MonStats({
            hp: 350,
            stamina: STAMINA,
            speed: 150,
            attack: 150,
            defense: 150,
            specialAttack: 150,
            specialDefense: 150,
            type1: Type.Air,
            type2: Type.None
        });
        string[] memory sofabbiName = new string[](1);
        sofabbiName[0] = "Sofabbi";

        defaultMonRegistry.createMon(sofabbiStats, moves, abilities, nameKey, sofabbiName);
    }

    function createTeam() public {
        LazyTeamRegistry registry = new LazyTeamRegistry(
            LazyTeamRegistry.Args({
                REGISTRY: DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY")), 
                MONS_PER_TEAM: 6,
                MOVES_PER_MON: 4
            })
        );

        // Set indices
        uint256[] memory monIndices = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            monIndices[i] = i;
        }

        // Overwrite mon0 to be sofabbi
        monIndices[0] = 6;

        // Set moves
        IMoveSet[][] memory moves = new IMoveSet[][](6);

        // Moves for mon0 (sofabbi)
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

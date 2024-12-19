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
        // BST sum: 400+200+175+120+150+80 = 1125
        MonStats memory sofabbiStats = MonStats({
            hp: 350,
            stamina: STAMINA,
            speed: 140,
            attack: 150,
            defense: 150,
            specialAttack: 150,
            specialDefense: 150,
            type1: Type.Nature,
            type2: Type.None
        });
        string[] memory sofabbiName = new string[](1);
        sofabbiName[0] = "Sofabbi";

        // Ghoulias is slow but hits hard, not high hp tho
        // BST sum: 250+80+250+120+180+140 = 1020
        MonStats memory ghouliathStats = MonStats({
            hp: 270,
            stamina: STAMINA,
            speed: 80,
            attack: 230,
            defense: 120,
            specialAttack: 180,
            specialDefense: 140,
            type1: Type.Yang,
            type2: Type.None
        });
        string[] memory ghouliathName = new string[](1);
        ghouliathName[0] = "Ghouliath";

        // Gorillax is relatively bulky but slow
        // BST sum: 350+100+200+100+100+200 = 1050
        MonStats memory gorillaxStats = MonStats({
            hp: 350,
            stamina: STAMINA,
            speed: 100,
            attack: 190,
            defense: 200,
            specialAttack: 100,
            specialDefense: 110,
            type1: Type.Earth,
            type2: Type.None
        });
        string[] memory gorillaxName = new string[](1);
        gorillaxName[0] = "Gorillax";

        // Jennie is all around average
        // BST sum: 285+150+170+130+180+120 = 1035
        MonStats memory inutiaStats = MonStats({
            hp: 285,
            stamina: STAMINA,
            speed: 150,
            attack: 170,
            defense: 130,
            specialAttack: 180,
            specialDefense: 120,
            type1: Type.Wild,
            type2: Type.None
        });
        string[] memory inutiaName = new string[](1);
        inutiaName[0] = "Inutia";

        // Pengu is bulk and special defender
        // BST sum: 350+80+120+120+180+250 = 1100
        MonStats memory pengymStats = MonStats({
            hp: 350,
            stamina: STAMINA,
            speed: 80,
            attack: 120,
            defense: 120,
            specialAttack: 180,
            specialDefense: 250,
            type1: Type.Ice,
            type2: Type.None
        });
        string[] memory pengymName = new string[](1);
        pengymName[0] = "Pengym";

        // Milady is high special attack / speed, glass cannon
        // BST sum: 250+180+220+50+250+50 = 1000
        MonStats memory malalienStats = MonStats({
            hp: 270,
            stamina: STAMINA,
            speed: 170,
            attack: 220,
            defense: 80,
            specialAttack: 200,
            specialDefense: 80,
            type1: Type.Mythic,
            type2: Type.None
        });
        string[] memory malalienName = new string[](1);
        malalienName[0] = "Malalien";

        // Create mons
        defaultMonRegistry.createMon(sofabbiStats, moves, abilities, nameKey, sofabbiName);
        defaultMonRegistry.createMon(ghouliathStats, moves, abilities, nameKey, ghouliathName);
        defaultMonRegistry.createMon(gorillaxStats, moves, abilities, nameKey, gorillaxName);
        defaultMonRegistry.createMon(inutiaStats, moves, abilities, nameKey, inutiaName);
        defaultMonRegistry.createMon(pengymStats, moves, abilities, nameKey, pengymName);
        defaultMonRegistry.createMon(malalienStats, moves, abilities, nameKey, malalienName);
    }

    function createTeam() public {
        LazyTeamRegistry registry = LazyTeamRegistry(vm.envAddress("TEAM_REGISTRY"));

        // Set indices
        uint256[] memory monIndices = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            monIndices[i] = i;
        }

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

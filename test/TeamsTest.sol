// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {DefaultTeamRegistry} from "../src/teams/DefaultTeamRegistry.sol";

import {EffectAbility} from "./mocks/EffectAbility.sol";
import {EffectAttack} from "./mocks/EffectAttack.sol";

import {IAbility} from "../src/abilities/IAbility.sol";
import {IEffect} from "../src/effects/IEffect.sol";

import {IEngine} from "../src/IEngine.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

contract TeamsTest is Test {
    address constant ALICE = address(1);
    address constant BOB = address(2);

    DefaultMonRegistry monRegistry;
    DefaultTeamRegistry teamRegistry;

    function setUp() public {
        monRegistry = new DefaultMonRegistry();
        teamRegistry = new DefaultTeamRegistry(
            DefaultTeamRegistry.Args({REGISTRY: monRegistry, MONS_PER_TEAM: 1, MOVES_PER_MON: 1})
        );

        // Make Alice the mon registry owner
        monRegistry.transferOwnership(ALICE);
    }

    function test_monRegistryFlow() public {
        IAbility ability = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = ability;

        IMoveSet move = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = move;

        MonStats memory stats = MonStats({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defense: 1,
            specialAttack: 1,
            specialDefense: 1,
            type1: Type.Fire,
            type2: Type.None
        });

        bytes32[] memory nameKey = new bytes32[](1);
        nameKey[0] = bytes32("name");
        string[] memory nameValue = new string[](1);
        nameValue[0] = "sus";

        // Create a mon in the mon registry
        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities, nameKey, nameValue);

        // Assert that the metadata exists
        string memory monName = monRegistry.getMonMetadata(0, bytes32("name"));
        assertEq(monName, "sus");

        // Assert that Bob cannot create a mon
        vm.startPrank(BOB);
        vm.expectRevert();
        monRegistry.createMon(stats, moves, abilities, nameKey, nameValue);

        MonStats memory newStats = MonStats({
            hp: 2,
            stamina: 2,
            speed: 2,
            attack: 2,
            defense: 2,
            specialAttack: 2,
            specialDefense: 2,
            type1: Type.Fire,
            type2: Type.None
        });

        IMoveSet newMove = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 2, PRIORITY: 2})
        );
        IMoveSet[] memory newMoves = new IMoveSet[](1);
        newMoves[0] = newMove;

        IAbility newAbility = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory newAbilities = new IAbility[](1);
        newAbilities[0] = newAbility;

        // Assert that Alice can edit a mon
        vm.startPrank(ALICE);
        monRegistry.modifyMon(0, newStats, newMoves, moves, newAbilities, abilities);

        // Assert that the old move is no longer valid from the mon registry
        // and that the new move is
        assertEq(monRegistry.isValidMove(0, move), false);
        assertEq(monRegistry.isValidMove(0, newMove), true);

        // Assert that the old ability is no longer valid from the mon registry
        // and that the new ability is
        assertEq(monRegistry.isValidAbility(0, ability), false);
        assertEq(monRegistry.isValidAbility(0, newAbility), true);

        // Assert that Bob cannot edit a mon
        vm.startPrank(BOB);
        vm.expectRevert();
        monRegistry.modifyMon(0, newStats, newMoves, moves, newAbilities, abilities);

        // Assert that only Alice can set additional metadata
        vm.startPrank(ALICE);
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = "test";
        string[] memory values = new string[](1);
        values[0] = "test";
        monRegistry.modifyMonMetadata(0, keys, values);

        // Assert that Bob cannot set additional metadata
        vm.startPrank(BOB);
        vm.expectRevert();
        monRegistry.modifyMonMetadata(0, keys, values);
    }

    function test_teamRegistryFlow() public {
        IAbility ability = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = ability;

        IMoveSet move1 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );

        IMoveSet move2 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );

        IMoveSet[] memory moves = new IMoveSet[](2);
        moves[0] = move1;
        moves[1] = move2;

        MonStats memory stats = MonStats({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defense: 1,
            specialAttack: 1,
            specialDefense: 1,
            type1: Type.Fire,
            type2: Type.None
        });

        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);

        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities, keys, values);

        uint256[] memory monIndices = new uint256[](1);
        monIndices[0] = 0;
        IMoveSet[][] memory movesToUse = new IMoveSet[][](1);
        movesToUse[0] = new IMoveSet[](1);
        movesToUse[0][0] = move1;
        IAbility[] memory abilitiesToUse = new IAbility[](1);
        abilitiesToUse[0] = ability;
        teamRegistry.createTeam(monIndices, movesToUse, abilitiesToUse);

        // Assert the team for Alice exists
        assertEq(teamRegistry.getTeamCount(ALICE), 1);
        Mon[] memory aliceTeam0 = teamRegistry.getTeam(ALICE, 0);
        assertEq(aliceTeam0.length, 1);
        assertEq(uint256(aliceTeam0[0].stats.type1), uint256(Type.Fire));
        uint256[] memory teamIndices = teamRegistry.getMonRegistryIndicesForTeam(ALICE, 0);
        assertEq(teamIndices.length, 1);
        assertEq(teamIndices[0], 0);
    }

    function test_realTeamFlow() public {

        // Make the same mon 6 times
        IAbility ability = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = ability;
        IMoveSet move1 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet move2 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](2);
        moves[0] = move1;
        moves[1] = move2;
        MonStats memory stats = MonStats({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defense: 1,
            specialAttack: 1,
            specialDefense: 1,
            type1: Type.Fire,
            type2: Type.None
        });
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);

        // Ids 0 to 5 are all the mon
        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities, keys, values);
        monRegistry.createMon(stats, moves, abilities, keys, values);
        monRegistry.createMon(stats, moves, abilities, keys, values);
        monRegistry.createMon(stats, moves, abilities, keys, values);
        monRegistry.createMon(stats, moves, abilities, keys, values);
        monRegistry.createMon(stats, moves, abilities, keys, values);

        // Create new team registry with team size of 6 and move size of 0
        DefaultTeamRegistry teamRegistry2 = new DefaultTeamRegistry(
            DefaultTeamRegistry.Args({REGISTRY: monRegistry, MONS_PER_TEAM: 6, MOVES_PER_MON: 0})
        );

        // Register the team for Alice
        vm.startPrank(ALICE);
        uint256[] memory monIndices = new uint256[](6);
        monIndices[0] = 0;
        monIndices[1] = 1;
        monIndices[2] = 2;  
        monIndices[3] = 3;
        monIndices[4] = 4;
        monIndices[5] = 5;
        IAbility[] memory abilitiesToUse = new IAbility[](6);
        abilitiesToUse[0] = ability;
        abilitiesToUse[1] = ability;
        abilitiesToUse[2] = ability;
        abilitiesToUse[3] = ability;
        abilitiesToUse[4] = ability;
        abilitiesToUse[5] = ability;
        teamRegistry2.createTeam(monIndices, new IMoveSet[][](6), abilitiesToUse);

        // Assert the team for Alice exists
        assertEq(teamRegistry2.getTeamCount(ALICE), 1);
        Mon[] memory aliceTeam0 = teamRegistry2.getTeam(ALICE, 0);
        assertEq(aliceTeam0.length, 6);

        // Check the team indices are as expected
        uint256[] memory teamIndices = teamRegistry2.getMonRegistryIndicesForTeam(ALICE, 0);
        assertEq(teamIndices.length, 6);
        assertEq(teamIndices[0], 0);
        assertEq(teamIndices[1], 1);
        assertEq(teamIndices[2], 2);
        assertEq(teamIndices[3], 3);
        assertEq(teamIndices[4], 4);
        assertEq(teamIndices[5], 5);
    }

    function test_duplicateTeamFails() public {

        // Make the same mon 6 times
        IAbility ability = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = ability;
        IMoveSet move1 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet move2 = new EffectAttack(
            IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](2);
        moves[0] = move1;
        moves[1] = move2;
        MonStats memory stats = MonStats({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defense: 1,
            specialAttack: 1,
            specialDefense: 1,
            type1: Type.Fire,
            type2: Type.None
        });
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);

        // Ids 0 to 5 are all the mon
        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities, keys, values);

        uint256[] memory monIndices = new uint256[](2);
        monIndices[0] = 0;
        monIndices[1] = 0;
        IAbility[] memory abilitiesToUse = new IAbility[](2);
        abilitiesToUse[0] = ability;
        abilitiesToUse[1] = ability;

        DefaultTeamRegistry teamRegistry2 = new DefaultTeamRegistry(
            DefaultTeamRegistry.Args({REGISTRY: monRegistry, MONS_PER_TEAM: 2, MOVES_PER_MON: 0})
        );

        vm.expectRevert(DefaultTeamRegistry.DuplicateMonId.selector);
        teamRegistry2.createTeam(monIndices, new IMoveSet[][](2), abilitiesToUse);
    }
}

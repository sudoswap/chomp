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
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None
        });

        // Create a mon in the mon registry
        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities);

        // Assert that Bob cannot create a mon
        vm.startPrank(BOB);
        vm.expectRevert();
        monRegistry.createMon(stats, moves, abilities);

        MonStats memory newStats = MonStats({
            hp: 2,
            stamina: 2,
            speed: 2,
            attack: 2,
            defence: 2,
            specialAttack: 2,
            specialDefence: 2,
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
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None
        });

        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities);

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
    }
}

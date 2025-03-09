// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Structs.sol";
import {Test} from "forge-std/Test.sol";

import {Engine} from "../../src/Engine.sol";

import {MonStateIndexName, Type} from "../../src/Enums.sol";
import {FastCommitManager} from "../../src/FastCommitManager.sol";

import {FastValidator} from "../../src/FastValidator.sol";
import {IEngine} from "../../src/IEngine.sol";
import {IFastCommitManager} from "../../src/IFastCommitManager.sol";
import {IRuleset} from "../../src/IRuleset.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";
import {CarrotHarvest} from "../../src/mons/sofabbi/CarrotHarvest.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";
import {CustomAttack} from "../mocks/CustomAttack.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

contract SofabbiTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    CarrotHarvest carrotHarvest;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 0, TIMEOUT_DURATION: 10})
        );
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));

        // Initialize the CarrotHarvest ability
        carrotHarvest = new CarrotHarvest(IEngine(address(engine)));
    }

    function test_carrotHarvestAppliesOnSwitchIn() public {
        // Create move arrays
        IMoveSet[] memory moves = new IMoveSet[](0);

        // Create a mon with CarrotHarvest ability
        Mon memory sofabbiMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Nature,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(carrotHarvest))
        });

        // Create a second mon without the ability
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Create teams with two mons each
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = sofabbiMon;
        aliceTeam[1] = regularMon;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = regularMon;
        bobTeam[1] = regularMon;

        // Register teams
        defaultRegistry.setTeam(BattleHelper.ALICE, aliceTeam);
        defaultRegistry.setTeam(BattleHelper.BOB, bobTeam);

        // Start a battle
        StartBattleArgs memory args = StartBattleArgs({
            p0: BattleHelper.ALICE,
            p1: BattleHelper.BOB,
            validator: validator,
            rngOracle: mockOracle,
            ruleset: IRuleset(address(0)),
            teamRegistry: defaultRegistry,
            p0TeamHash: keccak256(
                abi.encodePacked(
                    bytes32(""), uint256(0), defaultRegistry.getMonRegistryIndicesForTeam(BattleHelper.ALICE, 0)
                )
            )
        });

        vm.prank(BattleHelper.ALICE);
        bytes32 battleKey = engine.proposeBattle(args);

        bytes32 battleIntegrityHash = keccak256(
            abi.encodePacked(args.validator, args.rngOracle, args.ruleset, args.teamRegistry, args.p0TeamHash)
        );

        vm.prank(BattleHelper.BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);

        vm.prank(BattleHelper.ALICE);
        engine.startBattle(battleKey, "", 0);

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Verify that the CarrotHarvest effect was applied to Alice's mon
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);

        // Now have Alice switch to her second mon
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(1), "");

        // Now have Alice switch back to her first mon
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(0), "");

        // Verify that the CarrotHarvest effect is still only applied once
        // (should still have only one targeted effect)
        assertEq(state.monStates[0][0].targetedEffects.length, 1);

        // Verify the global KV store has the effect registered
        bytes32 monId = keccak256(abi.encode(0, 0, "Carrot Harvest"));
        bytes32 value = engine.getGlobalKV(battleKey, monId);
        assertEq(uint256(value), 1);
    }

    function test_carrotHarvestTriggersAtEndOfRoundWhenRNGReturnsTrue() public {

        // Create move arrays
        IMoveSet[] memory moves = new IMoveSet[](0);

        // Create a mon with CarrotHarvest ability
        Mon memory sofabbiMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Nature,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(carrotHarvest))
        });
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Set up teams
        Mon[] memory team = new Mon[](2);
        team[0] = sofabbiMon;
        team[1] = regularMon;

        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        // Start battle
        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: mockOracle,
            ruleset: IRuleset(address(0)),
            teamRegistry: defaultRegistry,
            p0TeamHash: keccak256(
                abi.encodePacked(
                    bytes32(""), uint256(0), defaultRegistry.getMonRegistryIndicesForTeam(ALICE, 0)
                )
            )
        });

        vm.prank(ALICE);
        bytes32 battleKey = engine.proposeBattle(args);

        bytes32 battleIntegrityHash = keccak256(
            abi.encodePacked(args.validator, args.rngOracle, args.ruleset, args.teamRegistry, args.p0TeamHash)
        );

        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);

        vm.prank(ALICE);
        engine.startBattle(battleKey, "", 0);

        // Set oracle to return 1 (ie both mons gain staminaDelta)
        mockOracle.setRNG(1);

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Verify that staminaDelta is 1 for both mons
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].staminaDelta, 1);
        assertEq(state.monStates[1][0].staminaDelta, 1);

        // Set oracle to return 0 (ie no mons gain staminaDelta)
        mockOracle.setRNG(0);

        // Alice and Bob both do nothing
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify that staminaDelta is still 1 for both mons
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].staminaDelta, 1);
        assertEq(state.monStates[1][0].staminaDelta, 1);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Structs.sol";
import {Test} from "forge-std/Test.sol";

import {Engine} from "../../src/Engine.sol";
import {MonStateIndexName, MoveClass, Type} from "../../src/Enums.sol";
import {FastCommitManager} from "../../src/FastCommitManager.sol";

import {FastValidator} from "../../src/FastValidator.sol";
import {IEngine} from "../../src/IEngine.sol";
import {IFastCommitManager} from "../../src/IFastCommitManager.sol";
import {IRuleset} from "../../src/IRuleset.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

import {StatBoost} from "../../src/effects/StatBoost.sol";
import {PostWorkout} from "../../src/mons/pengym/PostWorkout.sol";
import {AnguishStatus} from "../../src/effects/status/AnguishStatus.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";
import {CustomAttack} from "../mocks/CustomAttack.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {StandardAttack} from "../../src/moves/StandardAttack.sol";
import {StandardAttackFactory} from "../../src/moves/StandardAttackFactory.sol";
import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";

contract PengymTest is Test, BattleHelper {

    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    StatBoost statBoost;
    StandardAttackFactory attackFactory;
    PostWorkout postWorkout;
    AnguishStatus anguishStatus;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: 10})
        );
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));
        statBoost = new StatBoost(IEngine(address(engine)));
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
        postWorkout = new PostWorkout(IEngine(address(engine)));
        anguishStatus = new AnguishStatus(IEngine(address(engine)));
    }
    function test_postWorkoutClearsAnguishStatusAndGainsStamina() public {
        // Create an attack that inflicts AnguishStatus with 100% chance
        StandardAttack anguishAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0, // No damage
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 0,
                MOVE_TYPE: Type.Water,
                EFFECT_ACCURACY: 100, // 100% chance to inflict status
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "Anguish Inflict",
                EFFECT: IEffect(address(anguishStatus))
            })
        );

        // Create a standard attack for the second mon
        StandardAttack standardAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 5,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 0,
                MOVE_TYPE: Type.Nature,
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "Standard Attack",
                EFFECT: IEffect(address(0))
            })
        );

        // Create Alice's team: one mon with PostWorkout ability and one regular mon
        IMoveSet[] memory aliceMon1Moves = new IMoveSet[](1);
        aliceMon1Moves[0] = standardAttack;

        IMoveSet[] memory aliceMon2Moves = new IMoveSet[](1);
        aliceMon2Moves[0] = standardAttack;

        Mon memory postWorkoutMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: aliceMon1Moves,
            ability: IAbility(address(postWorkout))
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
                type1: Type.Metal,
                type2: Type.None
            }),
            moves: aliceMon2Moves,
            ability: IAbility(address(0))
        });

        // Create Bob's team: one mon with AnguishStatus attack and one regular mon
        IMoveSet[] memory bobMon1Moves = new IMoveSet[](1);
        bobMon1Moves[0] = anguishAttack;

        IMoveSet[] memory bobMon2Moves = new IMoveSet[](1);
        bobMon2Moves[0] = standardAttack;

        Mon memory bobAnguishMon = Mon({
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
            moves: bobMon1Moves,
            ability: IAbility(address(0))
        });

        // Set up teams
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = postWorkoutMon; // First mon has PostWorkout ability
        aliceTeam[1] = regularMon;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = bobAnguishMon; // First mon has AnguishStatus attack
        bobTeam[1] = regularMon;

        defaultRegistry.setTeam(ALICE, aliceTeam);
        defaultRegistry.setTeam(BOB, bobTeam);

        // Start a battle
        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: mockOracle,
            ruleset: IRuleset(address(0)),
            teamRegistry: defaultRegistry,
            p0TeamHash: keccak256(
                abi.encodePacked(bytes32(""), uint256(0), defaultRegistry.getMonRegistryIndicesForTeam(ALICE, 0))
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

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Check that Alice's mon has the PostWorkout effect
        (IEffect[] memory aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        bool hasPostWorkoutEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(postWorkout))) {
                hasPostWorkoutEffect = true;
                break;
            }
        }
        assertTrue(hasPostWorkoutEffect, "Alice's mon should have PostWorkout effect");

        // Bob uses AnguishStatus attack on Alice's mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", ""
        );

        // Set the rng to be 1 (so no early anguish exit)
        mockOracle.setRNG(1);

        // Check that Alice's mon has the AnguishStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        bool hasAnguishEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(anguishStatus))) {
                hasAnguishEffect = true;
                break;
            }
        }
        assertTrue(hasAnguishEffect, "Alice's mon should have AnguishStatus effect");

        // Get current stamina before switching
        int32 staminaBefore = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);

        // Alice switches to her second mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(1), ""
        );

        // Alice switches back to her first mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(0), ""
        );

        // Check that Alice's mon no longer has the AnguishStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        hasAnguishEffect = false;
        
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(anguishStatus))) {
                hasAnguishEffect = true;
                break;
            }
        }
        assertFalse(hasAnguishEffect, "Alice's mon should not have AnguishStatus effect after switching");

        // Check that Alice's mon gained 1 stamina
        int32 staminaAfter = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);
        assertEq(staminaAfter, staminaBefore + 1, "Alice's mon should gain 1 stamina after switching with status");
    }
}
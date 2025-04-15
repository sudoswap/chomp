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

import {PostWorkout} from "../../src/mons/pengym/PostWorkout.sol";
import {PanicStatus} from "../../src/effects/status/PanicStatus.sol";
import {FrostbiteStatus} from "../../src/effects/status/FrostbiteStatus.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {StandardAttack} from "../../src/moves/StandardAttack.sol";
import {StandardAttackFactory} from "../../src/moves/StandardAttackFactory.sol";
import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";
import {StatBoosts} from "../../src/effects/StatBoosts.sol";

contract PengymTest is Test, BattleHelper {

    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    StandardAttackFactory attackFactory;
    PostWorkout postWorkout;
    PanicStatus panicStatus;
    FrostbiteStatus frostbiteStatus;
    StatBoosts statBoost;

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
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
        postWorkout = new PostWorkout(IEngine(address(engine)));
        panicStatus = new PanicStatus(IEngine(address(engine)));
        statBoost = new StatBoosts(IEngine(address(engine)));
        frostbiteStatus = new FrostbiteStatus(IEngine(address(engine)), statBoost);
    }

    function test_postWorkoutClearsPanicStatusAndGainsStamina() public {
        // Create an attack that inflicts PanicStatus with 100% chance
        StandardAttack panicAttack = attackFactory.createAttack(
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
                NAME: "Panic Inflict",
                EFFECT: IEffect(address(panicStatus))
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

        // Create Bob's team: one mon with PanicStatus attack and one regular mon
        IMoveSet[] memory bobMon1Moves = new IMoveSet[](1);
        bobMon1Moves[0] = panicAttack;

        IMoveSet[] memory bobMon2Moves = new IMoveSet[](1);
        bobMon2Moves[0] = standardAttack;

        Mon memory bobPanicMon = Mon({
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
        bobTeam[0] = bobPanicMon; // First mon has PanicStatus attack
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

        // Bob uses PanicStatus attack on Alice's mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", ""
        );

        // Set the rng to be 1 (so no early panic exit)
        mockOracle.setRNG(1);

        // Check that Alice's mon has the PanicStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        bool hasPanicEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(panicStatus))) {
                hasPanicEffect = true;
                break;
            }
        }
        assertTrue(hasPanicEffect, "Alice's mon should have PanicStatus effect");

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

        // Check that Alice's mon no longer has the PanicStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        hasPanicEffect = false;

        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(panicStatus))) {
                hasPanicEffect = true;
                break;
            }
        }
        assertFalse(hasPanicEffect, "Alice's mon should not have PanicStatus effect after switching");

        // Check that Alice's mon gained 1 stamina
        int32 staminaAfter = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);
        assertEq(staminaAfter, staminaBefore + 1, "Alice's mon should gain 1 stamina after switching with status");
    }

    function test_postWorkoutClearsFrostbiteStatusAndGainsStamina() public {
        // Create an attack that inflicts FrostbiteStatus with 100% chance
        StandardAttack frostbiteAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0, // No damage
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 0,
                MOVE_TYPE: Type.Ice,
                EFFECT_ACCURACY: 100, // 100% chance to inflict status
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "Frostbite Inflict",
                EFFECT: IEffect(address(frostbiteStatus))
            })
        );

        // Create a standard attack for the second mon
        StandardAttack standardAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 5,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 0,
                MOVE_TYPE: Type.Fire,
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
                specialAttack: 10, // Higher special attack to test Frostbite effect
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
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: aliceMon2Moves,
            ability: IAbility(address(0))
        });

        // Create Bob's team: one mon with FrostbiteStatus attack and one regular mon
        IMoveSet[] memory bobMon1Moves = new IMoveSet[](1);
        bobMon1Moves[0] = frostbiteAttack;

        IMoveSet[] memory bobMon2Moves = new IMoveSet[](1);
        bobMon2Moves[0] = standardAttack;

        Mon memory bobFrostbiteMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Ice,
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
        bobTeam[0] = bobFrostbiteMon; // First mon has FrostbiteStatus attack
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

        // Get initial special attack value
        int32 specialAttackBefore = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);

        // Bob uses FrostbiteStatus attack on Alice's mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", ""
        );

        // Check that Alice's mon has the FrostbiteStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        bool hasFrostbiteEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(frostbiteStatus))) {
                hasFrostbiteEffect = true;
                break;
            }
        }
        assertTrue(hasFrostbiteEffect, "Alice's mon should have FrostbiteStatus effect");

        // Check that special attack was reduced
        int32 specialAttackAfterFrostbite = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);
        assertTrue(specialAttackAfterFrostbite < specialAttackBefore, "Special attack should be reduced by Frostbite");

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

        // Check that Alice's mon no longer has the FrostbiteStatus effect
        (aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        hasFrostbiteEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(frostbiteStatus))) {
                hasFrostbiteEffect = true;
                break;
            }
        }
        assertFalse(hasFrostbiteEffect, "Alice's mon should not have FrostbiteStatus effect after switching");

        // Check that Alice's mon gained 1 stamina
        int32 staminaAfter = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);
        assertEq(staminaAfter, staminaBefore + 1, "Alice's mon should gain 1 stamina after switching with status");

        // Check that special attack was restored
        int32 specialAttackAfterCure = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);
        assertTrue(specialAttackAfterCure > specialAttackAfterFrostbite, "Special attack should be restored after Frostbite is cured");
    }
}
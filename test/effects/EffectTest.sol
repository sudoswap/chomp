// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../../lib/forge-std/src/Test.sol";

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {DefaultRuleset} from "../../src/DefaultRuleset.sol";

import {Engine} from "../../src/Engine.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {CommitManager} from "../../src/deprecated/CommitManager.sol";
import {DefaultValidator} from "../../src/deprecated/DefaultValidator.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";
import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

// Import effects

import {PanicStatus} from "../../src/effects/status/PanicStatus.sol";
import {FrostbiteStatus} from "../../src/effects/status/FrostbiteStatus.sol";
import {SleepStatus} from "../../src/effects/status/SleepStatus.sol";
import {BurnStatus} from "../../src/effects/status/BurnStatus.sol";
import {StatBoosts} from "../../src/effects/StatBoosts.sol";

// Import standard attack factory and template

import {StandardAttack} from "../../src/moves/StandardAttack.sol";
import {StandardAttackFactory} from "../../src/moves/StandardAttackFactory.sol";
import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";

contract EffectTest is Test {
    CommitManager commitManager;
    Engine engine;
    DefaultValidator oneMonOneMoveValidator;
    ITypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;

    StatBoosts statBoosts;
    StandardAttackFactory standardAttackFactory;
    FrostbiteStatus frostbiteStatus;
    SleepStatus sleepStatus;
    PanicStatus panicStatus;
    BurnStatus burnStatus;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant TIMEOUT_DURATION = 100;

    Mon dummyMon;
    IMoveSet dummyAttack;

    /**
     * - ensure only 1 effect can be applied at a time
     *  - ensure that the effects actually do what they should do:
     *   - frostbite does damage at eot
     *   - frostbit reduces sp atk
     *   - sleep prevents moves
     *   - fright reduces stamina
     *   - sleep and fright end after 3 turns
     *   - burn reduces attack and deals damage at eot
     *   - burn degree increases over time, increasing damage
     */
    function setUp() public {
        mockOracle = new MockRandomnessOracle();
        engine = new Engine();
        commitManager = new CommitManager(engine);
        engine.setCommitManager(address(commitManager));
        oneMonOneMoveValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        typeCalc = new TestTypeCalculator();
        defaultRegistry = new TestTeamRegistry();

        // Deploy StandardAttackFactory
        standardAttackFactory = new StandardAttackFactory(engine, typeCalc);

        // Deploy all effects
        statBoosts = new StatBoosts(engine);
        frostbiteStatus = new FrostbiteStatus(engine, statBoosts);
        sleepStatus = new SleepStatus(engine);
        panicStatus = new PanicStatus(engine);
        burnStatus = new BurnStatus(engine, statBoosts);
    }

    function _commitRevealExecuteForAliceAndBob(
        bytes32 battleKey,
        uint256 aliceMoveIndex,
        uint256 bobMoveIndex,
        bytes memory aliceExtraData,
        bytes memory bobExtraData
    ) internal {
        bytes32 salt = "";
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(aliceMoveIndex, salt, aliceExtraData));
        bytes32 bobMoveHash = keccak256(abi.encodePacked(bobMoveIndex, salt, bobExtraData));
        vm.startPrank(ALICE);
        commitManager.commitMove(battleKey, aliceMoveHash);
        vm.startPrank(BOB);
        commitManager.commitMove(battleKey, bobMoveHash);
        vm.startPrank(ALICE);
        commitManager.revealMove(battleKey, aliceMoveIndex, salt, aliceExtraData, false);
        vm.startPrank(BOB);
        commitManager.revealMove(battleKey, bobMoveIndex, salt, bobExtraData, false);
        engine.execute(battleKey);
    }

    function test_frostbite() public {
        // Deploy an attack with frostbite
        IMoveSet frostbiteAttack = standardAttackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "FrostbiteHit",
                EFFECT: frostbiteStatus
            })
        );

        // Verify the name matches
        assertEq(frostbiteAttack.name(), "FrostbiteHit");

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = frostbiteAttack;
        Mon memory mon = Mon({
            stats: MonStats({
                hp: 20,
                stamina: 2,
                speed: 2,
                attack: 1,
                defense: 1,
                specialAttack: 20,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory team = new Mon[](1);
        team[0] = mon;

        // Register both teams
        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: oneMonOneMoveValidator,
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
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                keccak256(abi.encodePacked(bytes32(""), uint256(0)))
            )
        );
        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);
        vm.prank(ALICE);
        engine.startBattle(battleKey, "", 0);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice and Bob both select attacks, both of them are move index 0 (do frostbite damage)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons have an effect length of 2 (including stat boost)
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        // Check that both mons took 1 damage (we should round down)
        assertEq(state.monStates[0][0].hpDelta, -1);
        assertEq(state.monStates[1][0].hpDelta, -1);

        // Check that the special attack of both mons was reduced by 50%
        assertEq(state.monStates[0][0].specialAttackDelta, -10);
        assertEq(state.monStates[1][0].specialAttackDelta, -10);

        // Alice and Bob both select attacks, both of them are move index 0 (do frostbite damage)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons still have an effect length of 2 (including stat boost)
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        assertEq(state.monStates[0][0].hpDelta, -2);
        assertEq(state.monStates[1][0].hpDelta, -2);

        // Alice and Bob both select to do a no op
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Check that health was reduced
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].hpDelta, -3);
        assertEq(state.monStates[1][0].hpDelta, -3);
    }

    function test_another_frostbite() public {
        // Deploy an attack with frostbite
        IMoveSet frostbiteAttack = standardAttackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "FrostbiteHit",
                EFFECT: frostbiteStatus
            })
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = frostbiteAttack;
        Mon memory mon = Mon({
            stats: MonStats({
                hp: 20,
                stamina: 2,
                speed: 2,
                attack: 1,
                defense: 1,
                specialAttack: 20,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory team = new Mon[](2);
        team[0] = mon;
        team[1] = mon;

        DefaultValidator twoMonOneMoveValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        // Register both teams
        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonOneMoveValidator,
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

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice switches to mon index 1, Bob induces frostbite
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Check that Alice's new mon at index 0 has taken damage
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][1].hpDelta, -1);
    }

    function test_sleep() public {
        // Deploy an attack with sleep
        IMoveSet sleepAttack = standardAttackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 1,
                STAMINA_COST: 0, // Does 1 damage
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "SleepHit",
                EFFECT: sleepStatus
            })
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = sleepAttack;
        Mon memory slowMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                speed: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory slowTeam = new Mon[](2);
        slowTeam[0] = slowMon;
        slowTeam[1] = slowMon;
        Mon memory fastMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                speed: 10,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory fastTeam = new Mon[](2);
        fastTeam[0] = fastMon;
        fastTeam[1] = fastMon;

        // Register both teams
        defaultRegistry.setTeam(ALICE, slowTeam);
        defaultRegistry.setTeam(BOB, fastTeam);

        // Two Mon Validator
        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
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
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                keccak256(abi.encodePacked(bytes32(""), uint256(0)))
            )
        );
        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);
        vm.prank(ALICE);

        engine.startBattle(battleKey, "", 0);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice and Bob both select attacks, both of them are move index 0 (do sleep damage)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both Alice's mon has an effect length of 1 and Bob's mon has no targeted effects
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 0);

        // Assert that Bob's mon dealt damage, and that Alice's mon did not (Bob outspeeds and inflicts sleep so the turn is skipped)
        assertEq(state.monStates[0][0].hpDelta, -1);
        assertEq(state.monStates[1][0].hpDelta, 0);

        // Set the oracle to report back 1 for the next turn (we do not exit sleep early)
        mockOracle.setRNG(1);

        // Alice and Bob both select attacks, both of them are move index 0 (do sleep damage)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Get newest state
        state = engine.getBattleState(battleKey);

        // Check that both Alice's mon has an effect length of 1 and Bob's mon has no targeted effects (still)
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 0);

        // Assert that Bob's mon dealt damage, and that Alice's mon did not because it is sleeping
        assertEq(state.monStates[0][0].hpDelta, -2);
        assertEq(state.monStates[1][0].hpDelta, 0);

        // Assert that the extraData for Alice's targeted effect is now 1 because 2 turn ends have passed
        assertEq(state.monStates[0][0].extraDataForTargetedEffects[0], abi.encode(1));

        // Set the oracle to report back 0 for the next turn (exit sleep early)
        mockOracle.setRNG(0);

        // Alice attacks, Bob does a no-op
        _commitRevealExecuteForAliceAndBob(battleKey, 0, NO_OP_MOVE_INDEX, "", "");

        // Alice should wake up early and inflict sleep on Bob
        state = engine.getBattleState(battleKey);

        // Bob should now have the sleep condition and take 1 damage from the attack
        assertEq(state.monStates[0][0].targetedEffects.length, 0);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].hpDelta, -1);

        // Set the oracle to report back 0 for the next turn (exit sleep early for Bob)
        mockOracle.setRNG(0);

        // Bob tries again to inflict sleep, while Alice does NO_OP
        // Bob should wake up, Alice should become asleep
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, 0, "", "");
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 0);

        // Set oracle to report back 1 (no early sleep awake)
        mockOracle.setRNG(1);

        // Alice is asleep but tries to swap, swap should succeed, and the flag should be cleared
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(1), "");
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][1].shouldSkipTurn, false);

        // But sleep effect should still persist
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
    }

    /**
     * - Alice and Bob both have mons that induce panic
     *  - Alice outspeeds Bob, and Bob should not have enough stamina after the effect's onApply trigger
     *  - So Bob's effect should fizzle
     *  - Wait 3 turns, Bob just does nothing, Alice does nothing
     *  - Wait for effect to end by itself
     *  - Check that Bob's mon has no more targeted effects
     */
    function test_panic() public {
        // Deploy an attack with panic
        IMoveSet panicAttack = standardAttackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 1,
                STAMINA_COST: 1, // Does 1 damage, costs 1 stamina
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Cosmic,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "PanicHit",
                EFFECT: panicStatus
            })
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = panicAttack;

        Mon memory fastMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 5,
                speed: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon memory slowMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 1, // Only 1 stamina
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;

        // Register both teams
        defaultRegistry.setTeam(ALICE, fastTeam);
        defaultRegistry.setTeam(BOB, slowTeam);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: oneMonOneMoveValidator,
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
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                keccak256(abi.encodePacked(bytes32(""), uint256(0)))
            )
        );
        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);
        vm.prank(ALICE);
        engine.startBattle(battleKey, "", 0);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice and Bob both select attacks, both of them are move index 0 (inflict panic)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Get newest state
        BattleState memory state = engine.getBattleState(battleKey);

        // Both mons have inflicted panic
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);

        // Assert that both mons took 1 damage
        assertEq(state.monStates[1][0].hpDelta, -1);
        assertEq(state.monStates[0][0].hpDelta, -1);

        // Assert that Alice's mon has a stamina delta of -2 (max stamina of 5)
        assertEq(state.monStates[0][0].staminaDelta, -2);

        // Assert that Bob's mon has a stamina delta of -1 (max stamina of 1)
        assertEq(state.monStates[1][0].staminaDelta, -1);

        // Set the oracle to report back 1 for the next turn (we do not exit panic early)
        mockOracle.setRNG(1);

        // Alice and Bob both select attacks, both of them are no ops (we wait a turn)
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Alice and Bob both select attacks, both of them are no ops (we wait another turn)
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // The panic effect should be over now
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[1][0].targetedEffects.length, 0);
    }

    function test_burn() public {
        // Deploy an attack with burn status
        IMoveSet burnAttack = standardAttackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Fire,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "BurnHit",
                EFFECT: burnStatus
            })
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = burnAttack;

        // Create mons with HP = 256 for easy division by 16 (burn damage denominator)
        Mon memory mon = Mon({
            stats: MonStats({
                hp: 256,
                stamina: 10,
                speed: 5,
                attack: 32, // Use 32 for easy division by 2 (attack reduction denominator)
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](1);
        team[0] = mon;

        // Register both teams
        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: oneMonOneMoveValidator,
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
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                keccak256(abi.encodePacked(bytes32(""), uint256(0)))
            )
        );
        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);
        vm.prank(ALICE);
        engine.startBattle(battleKey, "", 0);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice and Bob both select attacks, both of them are move index 0 (apply burn status)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons have an effect length of 2 (including stat boost)
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        // Check that the attack of both mons was reduced by 50% (32/2 = 16)
        assertEq(state.monStates[0][0].attackDelta, -16);
        assertEq(state.monStates[1][0].attackDelta, -16);

        // Check that both mons took 1/16 damage at end of round (256/16 = 16)
        assertEq(state.monStates[0][0].hpDelta, -16);
        assertEq(state.monStates[1][0].hpDelta, -16);

        // Alice and Bob both select attacks again to increase burn degree
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons still have an effect length of 2 (including stat boost)
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        // Check that both mons took additional 1/8 damage (256/8 = 32)
        // Total damage should be 16 (first round) + 32 (second round) = 48
        assertEq(state.monStates[0][0].hpDelta, -48);
        assertEq(state.monStates[1][0].hpDelta, -48);

        // Alice and Bob both select attacks again to increase burn degree to maximum
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons still have an effect length of 1
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        // Check that both mons took additional 1/4 damage (256/4 = 64)
        // Total damage should be 16 (first round) + 32 (second round) + 64 (third round) = 112
        assertEq(state.monStates[0][0].hpDelta, -112);
        assertEq(state.monStates[1][0].hpDelta, -112);

        // Alice and Bob both select attacks again to increase burn degree to maximum
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons still have an effect length of 1
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 2);
        assertEq(state.monStates[1][0].targetedEffects.length, 2);

        // Check that both mons took another 1/4 damage (max burn degree)
        // Total damage should be 16 (first round) + 32 (second round) + 64 (third round) + 64 (fourth round) = 176
        assertEq(state.monStates[0][0].hpDelta, -176);
        assertEq(state.monStates[1][0].hpDelta, -176);
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {CommitManager} from "../src/deprecated/CommitManager.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {DefaultValidator} from "../src/deprecated/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";
import {IValidator} from "../src/IValidator.sol";
import {IAbility} from "../src/abilities/IAbility.sol";
import {IEffect} from "../src/effects/IEffect.sol";

import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {ITypeCalculator} from "../src/types/ITypeCalculator.sol";
import {MockRandomnessOracle} from "./mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "./mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "./mocks/TestTypeCalculator.sol";

// Import effects

import {FrightStatus} from "../src/effects/status/FrightStatus.sol";
import {FrostbiteStatus} from "../src/effects/status/FrostbiteStatus.sol";
import {SleepStatus} from "../src/effects/status/SleepStatus.sol";

// Import custom effect attack factory and template

import {CustomEffectAttack} from "../src/moves/CustomEffectAttack.sol";
import {CustomEffectAttackFactory} from "../src/moves/CustomEffectAttackFactory.sol";

contract EngineTest is Test {
    CommitManager commitManager;
    Engine engine;
    DefaultValidator oneMonOneMoveValidator;
    ITypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;

    CustomEffectAttackFactory customEffectAttackFactory;
    FrostbiteStatus frostbiteStatus;
    SleepStatus sleepStatus;
    FrightStatus frightStatus;

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

        // Deploy CustomEffectAttack template and factory
        CustomEffectAttack template = new CustomEffectAttack(engine, typeCalc);
        customEffectAttackFactory = new CustomEffectAttackFactory(template);

        // Deploy all effects
        frostbiteStatus = new FrostbiteStatus(engine);
        sleepStatus = new SleepStatus(engine);
        frightStatus = new FrightStatus(engine);
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
        IMoveSet frostbiteAttack = customEffectAttackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT: frostbiteStatus,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                NAME: bytes32("FrostbiteHit")
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

        // Check that both mons have an effect length of 1
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);

        // Check that both mons took 1 damage (we should round down)
        assertEq(state.monStates[0][0].hpDelta, -1);
        assertEq(state.monStates[1][0].hpDelta, -1);

        // Check that the special attack of both mons was reduced by 50%
        assertEq(state.monStates[0][0].specialAttackDelta, -10);
        assertEq(state.monStates[1][0].specialAttackDelta, -10);

        // Alice and Bob both select attacks, both of them are move index 0 (do frostbite damage)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Check that both mons still have an effect length of 1
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);

        assertEq(state.monStates[0][0].hpDelta, -2);
        assertEq(state.monStates[1][0].hpDelta, -2);

        // Alice and Bob both select to do a no op
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Check that health was reduced
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].hpDelta, -3);
        assertEq(state.monStates[1][0].hpDelta, -3);
    }

    function test_frostbite2() public {
        // Deploy an attack with frostbite
        IMoveSet frostbiteAttack = customEffectAttackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT: frostbiteStatus,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                NAME: bytes32("FrostbiteHit")
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
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                args.p0TeamHash
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

        // Alice switches to mon index 1, Bob induces frostbite
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Check that Alice's new mon at index 0 has taken damage
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][1].hpDelta, -1);
    }

    function test_sleep() public {
        // Deploy an attack with sleep
        IMoveSet sleepAttack = customEffectAttackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 1,
                STAMINA_COST: // Does 1 damage
                    0,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Ice,
                EFFECT: sleepStatus,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                NAME: bytes32("SleepHit")
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
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;
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
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;

        // Register both teams
        defaultRegistry.setTeam(ALICE, slowTeam);
        defaultRegistry.setTeam(BOB, fastTeam);

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
    }

    /**
     * - Alice and Bob both have mons that induce fright
     *  - Alice outspeeds Bob, and Bob should not have enough stamina after the effect's onApply trigger
     *  - So Bob's effect should fizzle
     *  - Wait 3 turns, Bob just does nothing, Alice does nothing
     *  - Wait for effect to end by itself
     *  - Check that Bob's mon has no more targeted effects
     */
    function test_fright() public {
        // Deploy an attack with fright
        IMoveSet frightAttack = customEffectAttackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 1,
                STAMINA_COST: // Does 1 damage
                    1,
                ACCURACY: // Costs 1 stamina
                    100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Cosmic,
                EFFECT: frightStatus,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                NAME: bytes32("FrightHit")
            })
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = frightAttack;

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

        // Alice and Bob both select attacks, both of them are move index 0 (inflict fright)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Get newest state
        BattleState memory state = engine.getBattleState(battleKey);

        // Both mons have inflicted fright
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);

        // Assert that both mons took 1 damage
        assertEq(state.monStates[1][0].hpDelta, -1);
        assertEq(state.monStates[0][0].hpDelta, -1);

        // Assert that Alice's mon has a stamina delta of -2 (max stamina of 5)
        assertEq(state.monStates[0][0].staminaDelta, -2);
        
        // Assert that Bob's mon has a stamina delta of -1 (max stamina of 1)
        assertEq(state.monStates[1][0].staminaDelta, -1);

        // Set the oracle to report back 1 for the next turn (we do not exit fright early)
        mockOracle.setRNG(1);

        // Alice and Bob both select attacks, both of them are no ops (we wait a turn)
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Alice and Bob both select attacks, both of them are no ops (we wait another turn)
        _commitRevealExecuteForAliceAndBob(battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // The stamina effect should be over now
        state = engine.getBattleState(battleKey);
        assertEq(state.monStates[1][0].targetedEffects.length, 0);
    }
}

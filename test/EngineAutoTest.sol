// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {CommitManager} from "../src/CommitManager.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";
import {IValidator} from "../src/IValidator.sol";
import {IAbility} from "../src/abilities/IAbility.sol";

import {DefaultStaminaRegen} from "../src/effects/DefaultStaminaRegen.sol";
import {IEffect} from "../src/effects/IEffect.sol";

import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";
import {ITypeCalculator} from "../src/types/ITypeCalculator.sol";
import {CustomAttack} from "./mocks/CustomAttack.sol";

import {AfterDamageReboundEffect} from "./mocks/AfterDamageReboundEffect.sol";
import {EffectAbility} from "./mocks/EffectAbility.sol";
import {EffectAttack} from "./mocks/EffectAttack.sol";
import {ForceSwitchMove} from "./mocks/ForceSwitchMove.sol";
import {GlobalEffectAttack} from "./mocks/GlobalEffectAttack.sol";
import {InstantDeathEffect} from "./mocks/InstantDeathEffect.sol";
import {InstantDeathOnSwitchInEffect} from "./mocks/InstantDeathOnSwitchInEffect.sol";
import {InvalidMove} from "./mocks/InvalidMove.sol";
import {MockRandomnessOracle} from "./mocks/MockRandomnessOracle.sol";
import {SingleInstanceEffect} from "./mocks/SingleInstanceEffect.sol";
import {SkipTurnMove} from "./mocks/SkipTurnMove.sol";
import {TempStatBoostEffect} from "./mocks/TempStatBoostEffect.sol";
import {TestTeamRegistry} from "./mocks/TestTeamRegistry.sol";

import {TestTypeCalculator} from "./mocks/TestTypeCalculator.sol";

/**
 * A subset of tests to check that the auto-execute flow from CommitManager works as expected
 */
contract EngineAutoTest is Test {
    CommitManager commitManager;
    Engine engine;
    DefaultValidator validator;
    ITypeCalculator typeCalc;
    DefaultRandomnessOracle defaultOracle;
    TestTeamRegistry defaultRegistry;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant TIMEOUT_DURATION = 100;

    Mon dummyMon;
    IMoveSet dummyAttack;

    function setUp() public {
        defaultOracle = new DefaultRandomnessOracle();
        engine = new Engine();
        commitManager = new CommitManager(engine);
        engine.setCommitManager(address(commitManager));
        validator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        typeCalc = new TestTypeCalculator();
        dummyAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 0, ACCURACY: 0, STAMINA_COST: 0, PRIORITY: 0})
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = dummyAttack;
        dummyMon = Mon({
            stats: MonStats({
                hp: 1,
                stamina: 1,
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
        defaultRegistry = new TestTeamRegistry();
    }

    // Helper function, creates a battle with two mons for Alice and Bob
    function _startDummyBattle() internal returns (bytes32) {
        Mon[][] memory dummyTeams = new Mon[][](2);
        Mon[] memory dummyTeam = new Mon[](1);
        dummyTeam[0] = dummyMon;
        dummyTeams[0] = dummyTeam;
        dummyTeams[1] = dummyTeam;

        // Register teams
        defaultRegistry.setTeam(ALICE, dummyTeams[0]);
        defaultRegistry.setTeam(BOB, dummyTeams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: defaultOracle,
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

        return battleKey;
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
        commitManager.revealMove(battleKey, aliceMoveIndex, salt, aliceExtraData, true);
        vm.startPrank(BOB);
        commitManager.revealMove(battleKey, bobMoveIndex, salt, bobExtraData, true);
    }

    function test_fasterSpeedKOsGameOver() public {
        // Initialize mons
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory fastMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 1,
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
                stamina: 1,
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
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;
        teams[0] = fastTeam;
        teams[1] = slowTeam;
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: defaultOracle,
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

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        // (Alice should win because her mon is faster)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert Alice wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, ALICE);

        // Assert that the staminaDelta was set correctly
        assertEq(state.monStates[0][0].staminaDelta, -1);
    }

    function test_fasterPriorityKOsGameOver() public {
        // Initialize fast and slow mons
        IMoveSet slowAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet fastAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory slowMoves = new IMoveSet[](1);
        slowMoves[0] = slowAttack;
        IMoveSet[] memory fastMoves = new IMoveSet[](1);
        fastMoves[0] = fastAttack;
        Mon memory fastMon = Mon({
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
            moves: slowMoves,
            ability: IAbility(address(0))
        });
        Mon memory slowMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: fastMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;
        teams[0] = fastTeam;
        teams[1] = slowTeam;
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: defaultOracle,
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

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert Bob wins as he has faster priority on a slower mon
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);

        // Assert that the staminaDelta was set correctly for Bob's mon
        assertEq(state.monStates[1][0].staminaDelta, -1);
    }

    function _setup2v2FasterPriorityBattleAndForceSwitch() internal returns (bytes32) {
        // Initialize fast and slow mons
        IMoveSet slowAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet fastAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory slowMoves = new IMoveSet[](1);
        slowMoves[0] = slowAttack;
        IMoveSet[] memory fastMoves = new IMoveSet[](1);
        fastMoves[0] = fastAttack;
        Mon memory fastMon = Mon({
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
            moves: slowMoves,
            ability: IAbility(address(0))
        });
        Mon memory slowMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: fastMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory fastTeam = new Mon[](2);
        fastTeam[0] = fastMon;
        fastTeam[1] = fastMon;
        Mon[] memory slowTeam = new Mon[](2);
        slowTeam[0] = slowMon;
        slowTeam[1] = slowMon;
        teams[0] = fastTeam;
        teams[1] = slowTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            rngOracle: defaultOracle,
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

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        return battleKey;
    }

    function test_fasterPriorityKOsForcesSwitchCorrectlyFailsOnInvalidSwitchNoCommit() public {
        bytes32 battleKey = _setup2v2FasterPriorityBattleAndForceSwitch();

        // Check that Alice (p0) now has the playerSwitch flag set
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);

        // Attempt to forcibly advance the game state
        vm.expectRevert();
        engine.execute(battleKey);

        // Assume Alice AFKs

        // Check that timeout succeeds for Bob in this case
        vm.warp(TIMEOUT_DURATION + 1);
        engine.end(battleKey);

        // Assert Bob wins
        state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);
    }

    function test_nonKOSubsequentMoves() public {
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2, // need to have enough stamina for 2 moves
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
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](1);
        team[0] = normalMon;
        teams[0] = team;
        teams[1] = team;
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            rngOracle: defaultOracle,
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

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        // (No mons are knocked out yet)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Let Alice and Bob commit and reveal to both choosing attack again
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Both Alice and Bob's mons have the same speed, so the final priority player is rng % 2
        BattleState memory state = engine.getBattleState(battleKey);
        uint256 finalRNG = state.pRNGStream[state.pRNGStream.length - 1];
        uint256 winnerIndex = finalRNG % 2;
        if (winnerIndex == 0) {
            assertEq(state.winner, ALICE);
        } else {
            assertEq(state.winner, BOB);
        }

        // Assert that the staminaDelta was set correctly (2 moves spent) for the winning mon
        assertEq(state.monStates[winnerIndex][0].staminaDelta, -2);
    }

    function test_switchPriorityIsFasterThanMove() public {
        // Initialize mons and moves
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None,
                speed: 2
            }),
            // need to have enough stamina for 2 moves
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        teams[0] = team;
        teams[1] = team;
        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            rngOracle: defaultOracle,
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

        // Second move, have Alice swap out to mon at index 1, have Bob use attack
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Assert that mon index for Alice is 1
        // Assert that the mon state for Alice has -5 applied to the switched in mon
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.activeMonIndex[0], 1);
        assertEq(state.monStates[0][1].hpDelta, -5);
    }

    function test_switchPriorityIsSlowerThanSuperfastMove() public {
        // Initialize mons and moves
        IMoveSet superFastAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = superFastAttack;
        Mon memory normalMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None,
                speed: 2
            }),
            // need to have enough stamina for 2 moves
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        teams[0] = team;
        teams[1] = team;
        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            rngOracle: defaultOracle,
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

        // Second move, have Alice swap out to mon at index 1, have Bob use fast attack
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Assert that mon index for Alice is 1
        // Assert that the mon state for Alice has -5 applied to the previous mon
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.activeMonIndex[0], 1);
        assertEq(state.monStates[0][0].hpDelta, -5);
    }

    function test_switchPriorityIsSlowerThanSuperfastMoveWithKO() public {
        // Initialize mons and moves
        IMoveSet superFastAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = superFastAttack;
        Mon memory normalMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None,
                speed: 2
            }),
            // need to have enough stamina for 2 moves
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        teams[0] = team;
        teams[1] = team;
        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            rngOracle: defaultOracle,
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

        // Second move, have Alice swap out to mon at index 1, have Bob use fast attack which supersedes Switch
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Given that it's a KO (even though Alice chose switch),
        // check that now they have the priority flag again
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);
    }

    function test_defaultStaminaRegenEffect() public {
        // Initialize mons and moves
        IMoveSet superFastAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = superFastAttack;
        Mon memory normalMon = Mon({
            stats: MonStats({
                hp: 10,
                stamina: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None,
                speed: 2
            }),
            // need to have enough stamina for 2 moves
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        teams[0] = team;
        teams[1] = team;
        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        DefaultStaminaRegen regen = new DefaultStaminaRegen(engine);
        DefaultRuleset rules = new DefaultRuleset(engine, IEffect(address(regen)));
        // Register teams
        defaultRegistry.setTeam(ALICE, teams[0]);
        defaultRegistry.setTeam(BOB, teams[1]);

        StartBattleArgs memory args = StartBattleArgs({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            rngOracle: defaultOracle,
            ruleset: rules,
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

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        // (No mons are knocked out yet)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        BattleState memory state = engine.getBattleState(battleKey);

        // Assert that the staminaDelta was set correctly (now back to 0)
        assertEq(state.monStates[0][0].staminaDelta, 0);
    }

}

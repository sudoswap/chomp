// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {DefaultValidator} from "../src/DefaultValidator.sol";

import {Engine} from "../src/Engine.sol";
import {IValidator} from "../src/IValidator.sol";

import {IAbility} from "../src/abilities/IAbility.sol";
import {IEffect} from "../src/effects/IEffect.sol";

import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";

import {EffectAbility} from "./mocks/EffectAbility.sol";
import {EffectAttack} from "./mocks/EffectAttack.sol";
import {GlobalEffectAttack} from "./mocks/GlobalEffectAttack.sol";
import {SingleInstanceEffect} from "./mocks/SingleInstanceEffect.sol";

import {ForceSwitchMove} from "./mocks/ForceSwitchMove.sol";
import {InstantDeathEffect} from "./mocks/InstantDeathEffect.sol";
import {InstantDeathOnSwitchInEffect} from "./mocks/InstantDeathOnSwitchInEffect.sol";

import {MockRandomnessOracle} from "./mocks/MockRandomnessOracle.sol";
import {SkipTurnMove} from "./mocks/SkipTurnMove.sol";

import {TypeCalculator} from "../src/types/TypeCalculator.sol";

import {CustomAttack} from "../src/moves/CustomAttack.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

import {DefaultStaminaRegen} from "../src/effects/DefaultStaminaRegen.sol";

/**
 * Tests:
 * Battle initiated, stored to state [x]
 * Battle initiated, MUST select swap [x]
 * Faster Speed Wins KO, leads to game over if team size = 1 [x]
 * Faster Priority Wins KO, leads to game over if team size = 1 [x]
 * Faster Priority Wins KO, leads to forced switch if team size is >= 2 [x]
 * Execute reverts if game is already over [x]
 * Switches are forced correctly on KO [x]
 * Faster Speed Wins KO, leads to forced switch if team size is >= 2 [ ]
 * Non-KO moves lead to subsequent move for both players [x]
 * Switching executes at correct priority [x]
 * Global Stamina Recovery effect works as expected [x]
 * Accuracy works as expected (i.e. controls damage or no damage, modify oracle) [x]
 * Stamina works as expected (i.e. controls whether or not a move can be used, deltas are updated) [x]
 * Effects work as expected (create a damage over time effect, check that Effect can KO) [x]
 * shouldSkipTurn flag works as expected (create an effect that skips move, and a move that skips move) [x]
 * Moves that force switch work and revert when expected (e.g. invalid switch) [ ]
 */
contract EngineTest is Test {
    Engine engine;
    DefaultValidator validator;
    TypeCalculator typeCalc;
    DefaultRandomnessOracle defaultOracle;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant TIMEOUT_DURATION = 100;

    Mon dummyMon;
    IMoveSet dummyAttack;

    function setUp() public {
        defaultOracle = new DefaultRandomnessOracle();
        engine = new Engine();
        validator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        typeCalc = new TypeCalculator();
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });
    }

    // Helper function, creates a battle with two mons for Alice and Bob
    function _startDummyBattle() internal returns (bytes32) {
        Mon[][] memory dummyTeams = new Mon[][](2);
        Mon[] memory dummyTeam = new Mon[](1);
        dummyTeam[0] = dummyMon;
        dummyTeams[0] = dummyTeam;
        dummyTeams[1] = dummyTeam;
        Battle memory dummyBattle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: dummyTeams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });
        vm.startPrank(ALICE);
        return engine.start(dummyBattle);
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
        engine.commitMove(battleKey, aliceMoveHash);
        vm.startPrank(BOB);
        engine.commitMove(battleKey, bobMoveHash);
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, aliceMoveIndex, salt, aliceExtraData);
        vm.startPrank(BOB);
        engine.revealMove(battleKey, bobMoveIndex, salt, bobExtraData);
        engine.execute(battleKey);
    }

    function test_canStartBattle() public {
        _startDummyBattle();
    }

    /*
        Tests the following behaviors:
        - battle creation does not revert
        - cannot reveal before other player has committed
        - cannot reveal before commit
        - cannot reveal correct preimage, invalid due to validator
        - cannot reveal incorrect preimage
        - cannot commit twice
        - cannot execute without both reveals
        - cannot commit new move, even after committing/revealing existing move if execute is not called
    */
    function test_canStartBattleMustChooseSwap() public {
        bytes32 battleKey = _startDummyBattle();

        // Let Alice commit to choosing switch
        bytes32 salt = "";
        bytes memory extraData = abi.encode(0);
        bytes32 moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, extraData));
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, moveHash);

        // Ensure Alice cannot reveal yet because Bob has not committed
        vm.expectRevert(Engine.RevealBeforeOtherCommit.selector);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Ensure Bob cannot reveal before choosing a move
        // (on turn 0, this will be a Wrong Preimage error as finding the hash to bytes32(0) is intractable)
        vm.startPrank(BOB);
        vm.expectRevert(Engine.WrongPreimage.selector);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Let Bob commit to choosing move index of 0 instead
        uint256 moveIndex = 0;
        moveHash = keccak256(abi.encodePacked(moveIndex, salt, ""));
        engine.commitMove(battleKey, moveHash);

        // Ensure that Bob cannot reveal correctly because validation will fail
        // (move index MUST be SWITCH_INDEX on turn 0)
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", BOB));
        engine.revealMove(battleKey, moveIndex, salt, "");

        // Ensure that Bob cannot reveal incorrectly because the preimage will fail
        vm.expectRevert(Engine.WrongPreimage.selector);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Ensure that Bob cannot re-commit because he has already committed
        vm.expectRevert(Engine.AlreadyCommited.selector);
        engine.commitMove(battleKey, moveHash);

        // Check that Alice can still reveal
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Ensure that execute cannot proceed
        vm.expectRevert();
        engine.execute(battleKey);

        // Check that Alice cannot commit a new move
        vm.expectRevert(Engine.AlreadyCommited.selector);
        engine.commitMove(battleKey, moveHash);

        // Check that timeout succeeds (need to add to validator/engine)
        vm.warp(TIMEOUT_DURATION + 1);
        engine.end(battleKey);

        // Assert Alice wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, ALICE);

        // Expect revert on calling end again
        vm.expectRevert(Engine.GameAlreadyOver.selector);
        engine.end(battleKey);

        // Expect revert on calling execute again
        vm.expectRevert(Engine.GameAlreadyOver.selector);
        engine.end(battleKey);
    }

    function test_canStartBattleBothPlayersNoOpAfterSwap() public {
        bytes32 battleKey = _startDummyBattle();

        // Let Alice commit to choosing switch
        bytes32 salt = "";
        bytes memory extraData = abi.encode(0);
        bytes32 moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, extraData));
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, moveHash);

        // Let Bob commit to choosing switch as well
        vm.startPrank(BOB);
        engine.commitMove(battleKey, moveHash);

        // Let Alice and Bob both reveal
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);
        vm.startPrank(BOB);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Advance game state
        engine.execute(battleKey);

        // Let Alice and Bob each commit to a no op
        extraData = "";
        moveHash = keccak256(abi.encodePacked(NO_OP_MOVE_INDEX, salt, extraData));
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, moveHash);
        vm.startPrank(BOB);
        engine.commitMove(battleKey, moveHash);

        // Let Alice and Bob both reveal
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, NO_OP_MOVE_INDEX, salt, extraData);
        vm.startPrank(BOB);
        engine.revealMove(battleKey, NO_OP_MOVE_INDEX, salt, extraData);

        // Advance game state
        engine.execute(battleKey);

        // Turn ID should now be 2
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.turnId, 2);
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        return battleKey;
    }

    function test_fasterPriorityKOsForcesSwitch() public {
        bytes32 battleKey = _setup2v2FasterPriorityBattleAndForceSwitch();

        // Check that Alice (p0) now has the playerSwitch flag set
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);

        // Alice now switches to mon index 1, Bob does not choose
        vm.startPrank(ALICE);
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, bytes32(""), abi.encode(1)));
        engine.commitMove(battleKey, aliceMoveHash);

        // Assert that Bob cannot commit anything because of the turn flag
        // (we just reuse Alice's move hash bc it doesn't matter)
        vm.startPrank(BOB);
        vm.expectRevert(Engine.OnlyP0Allowed.selector);
        engine.commitMove(battleKey, aliceMoveHash);

        // Reveal Alice's move, and advance game state
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, bytes32(""), abi.encode(1));
        engine.execute(battleKey);

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert Bob wins as he has faster priority on a slower mon
        state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);

        // Assert that the staminaDelta was set correctly for Bob's mon
        // (we used two attacks of 1 stamina, so -2)
        assertEq(state.monStates[1][0].staminaDelta, -2);
    }

    function test_fasterPriorityKOsForcesSwitchCorrectlyFailsOnInvalidSwitchReveal() public {
        bytes32 battleKey = _setup2v2FasterPriorityBattleAndForceSwitch();

        // Check that Alice (p0) now has the playerSwitch flag set
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);

        // Alice now switches (invalidly) to mon index 0
        vm.startPrank(ALICE);
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, bytes32(""), abi.encode(0)));
        engine.commitMove(battleKey, aliceMoveHash);

        // Attempt to reveal Alice's move, and assert that we cannot advance the game state
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, bytes32(""), abi.encode(0));

        // Attempt to forcibly advance the game state
        vm.expectRevert();
        engine.execute(battleKey);

        // Check that timeout succeeds for Bob in this case
        vm.warp(TIMEOUT_DURATION + 1);
        engine.end(battleKey);

        // Assert Bob wins
        state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);
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
        // Initialize fast and slow mons
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
                defence: 1,
                specialAttack: 1,
                specialDefence: 1,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        // (No mons are knocked out yet)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Let Alice and Bob commit and reveal to both choosing attack again
        // (Now Alice should win because her mon is faster)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert Alice wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, ALICE);

        // Assert that the staminaDelta was set correctly (2 moves spent)
        assertEq(state.monStates[0][0].staminaDelta, -2);
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
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        // Start the battle
        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        // Start the battle
        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        // Start the battle
        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
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
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: rules,
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

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

    function test_accuracyWorksAsExpectedWithRNG() public {
        // Deploy a custom RNG oracle that returns a fixed value
        MockRandomnessOracle mockOracle = new MockRandomnessOracle();
        mockOracle.setRNG(1);

        // Initialize mons and moves
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet inaccurateAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 1, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory normalMoves = new IMoveSet[](1);
        normalMoves[0] = normalAttack;
        IMoveSet[] memory inaccurateMoves = new IMoveSet[](1);
        inaccurateMoves[0] = inaccurateAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: normalMoves,
            ability: IAbility(address(0))
        });
        Mon memory inaccurateMon = Mon({
            hp: 10,
            stamina: 2, // need to have enough stamina for 2 moves
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: inaccurateMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory normalTeam = new Mon[](1);
        normalTeam[0] = normalMon;
        Mon[] memory inaccurateTeam = new Mon[](1);
        inaccurateTeam[0] = inaccurateMon;
        teams[0] = normalTeam;
        teams[1] = inaccurateTeam;

        // Initialize battle with custom rng oracle
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: mockOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let Alice and Bob commit and reveal to both choosing attack (move index 0)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert that Bob's move missed (did no damage)
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].hpDelta, 0);

        // Assert that Alice's move did damage
        assertEq(state.monStates[1][0].hpDelta, -5);
    }

    function test_invalidMoveIfStaminaCostTooHigh() public {
        // Initialize mons and moves
        IMoveSet highStaminaAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 2, PRIORITY: 0})
        );
        IMoveSet[] memory highStaminaMoves = new IMoveSet[](1);
        highStaminaMoves[0] = highStaminaAttack;
        IMoveSet normalStaminaAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory normalStaminaMoves = new IMoveSet[](1);
        normalStaminaMoves[0] = normalStaminaAttack;
        Mon memory highStaminaMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: highStaminaMoves,
            ability: IAbility(address(0))
        });
        Mon memory normalStaminaMon = Mon({
            hp: 10,
            stamina: 2,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: normalStaminaMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory highStaminaTeam = new Mon[](1);
        highStaminaTeam[0] = highStaminaMon;
        Mon[] memory normalStaminaTeam = new Mon[](1);
        normalStaminaTeam[0] = normalStaminaMon;
        teams[0] = highStaminaTeam;
        teams[1] = normalStaminaTeam;
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Commit move index 0 for Alice
        uint256 moveIndex = 0;
        vm.startPrank(ALICE);
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(moveIndex, bytes32(""), ""));
        engine.commitMove(battleKey, aliceMoveHash);

        // Commit move index 0 for Bob
        vm.startPrank(BOB);
        bytes32 bobMoveHash = keccak256(abi.encodePacked(moveIndex, bytes32(""), ""));
        engine.commitMove(battleKey, bobMoveHash);

        // Reveal Bob's move (valid)
        vm.startPrank(BOB);
        engine.revealMove(battleKey, moveIndex, bytes32(""), "");

        // Assert that Alice cannot reveal anything because of the stamina cost (she has the high stamina cost mon)
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        engine.revealMove(battleKey, moveIndex, bytes32(""), "");
    }

    // Ensure that we cannot write to mon state when there is no active execute() call in the call stack
    function test_ensureWritingToStateFailsWhenNotInCallStack() public {
        _startDummyBattle();

        // Updating mon state directly should revert
        vm.startPrank(ALICE);
        vm.expectRevert(Engine.NoWriteAllowed.selector);
        engine.updateMonState(0, 0, MonStateIndexName.Hp, 0);

        // Adding effect directly should revert
        vm.startPrank(ALICE);
        vm.expectRevert(Engine.NoWriteAllowed.selector);
        engine.addEffect(0, 0, IEffect(address(0)), "");

        // Deleting effect directly should revert
        vm.startPrank(ALICE);
        vm.expectRevert(Engine.NoWriteAllowed.selector);
        engine.removeEffect(0, 0, 0);
    }

    function test_effectAppliedByAttackCanKOForGameEnd() public {
        // Initialize mons and moves
        IMoveSet normalStaminaAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalStaminaAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Instant death attack
        IEffect instantDeath = new InstantDeathEffect(engine);
        IMoveSet instantDeathAttack =
            new EffectAttack(engine, instantDeath, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory deathMoves = new IMoveSet[](1);
        deathMoves[0] = instantDeathAttack;
        Mon memory instantDeathMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: deathMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](1);
        team[0] = normalMon;
        Mon[] memory deathTeam = new Mon[](1);
        deathTeam[0] = instantDeathMon;
        teams[0] = team;
        teams[1] = deathTeam;
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, which for Bob afflicts the instant death condition on the
        // opposing mon (Alice's) and knocks it out
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Assert Bob wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);
    }

    function test_effectAppliedByAttackCanKOAndForceSwitch() public {
        // Initialize mons and moves
        IMoveSet normalStaminaAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalStaminaAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Instant death attack
        IEffect instantDeath = new InstantDeathEffect(engine);
        IMoveSet instantDeathAttack =
            new EffectAttack(engine, instantDeath, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory deathMoves = new IMoveSet[](1);
        deathMoves[0] = instantDeathAttack;
        Mon memory instantDeathMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: deathMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        Mon[] memory deathTeam = new Mon[](2);
        deathTeam[0] = instantDeathMon;
        deathTeam[1] = instantDeathMon;
        teams[0] = team;
        teams[1] = deathTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            status: BattleProposalStatus.Accepted
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, which for Bob afflicts the instant death condition on the
        // opposing mon (Alice's) and knocks it out
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Now only Alice should be able to switch
        vm.startPrank(ALICE);
        bytes32 salt = "";
        bytes32 moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, abi.encode(1)));
        engine.commitMove(battleKey, moveHash);

        // Alice should be able to reveal because she is the only player (player flag should be set)
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, abi.encode(1));

        // Execute the switch
        engine.execute(battleKey);
    }

    function test_moveKOSupersedesRoundEndEffectKOForGameEnd() public {
        // Initialize mons and moves
        IMoveSet lethalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 7})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = lethalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Instant death attack
        IEffect instantDeath = new InstantDeathEffect(engine);
        IMoveSet instantDeathAttack =
            new EffectAttack(engine, instantDeath, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory deathMoves = new IMoveSet[](1);
        deathMoves[0] = instantDeathAttack;
        Mon memory instantDeathMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: deathMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](1);
        team[0] = normalMon;
        Mon[] memory deathTeam = new Mon[](1);
        deathTeam[0] = instantDeathMon;
        teams[0] = team;
        teams[1] = deathTeam;
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, which for Bob afflicts the instant death condition on the
        // opposing mon (Alice's)
        // But Alice's mon should KO Bob's before the end of round takes place
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Assert Alice wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, ALICE);
    }

    function test_moveKOAndEffectKOLeadToDualSwapOtherMoveRevertsForAlice() public {
        // Initialize mons and moves
        IMoveSet lethalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = lethalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Instant death attack
        IEffect instantDeath = new InstantDeathEffect(engine);
        IMoveSet instantDeathAttack =
            new EffectAttack(engine, instantDeath, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory deathMoves = new IMoveSet[](1);
        deathMoves[0] = instantDeathAttack;
        Mon memory instantDeathMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: deathMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        Mon[] memory deathTeam = new Mon[](2);
        deathTeam[0] = instantDeathMon;
        deathTeam[1] = instantDeathMon;
        teams[0] = team;
        teams[1] = deathTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, which for Bob afflicts the instant death condition on the
        // opposing mon (Alice's) and knocks it out
        // But Bob moves first (higher priority), so he gets the instant death affliction
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Now if Alice tries to pick a non-switch move, the engine should revert
        vm.startPrank(ALICE);
        bytes32 salt = "";
        uint256 aliceMoveIndex = 0;
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(aliceMoveIndex, salt, extraData));
        engine.commitMove(battleKey, aliceMoveHash);

        // (Assume Bob correctly commits to swapping his mon)
        vm.startPrank(BOB);
        salt = "";
        bytes32 bobMoveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, abi.encode(1)));
        engine.commitMove(battleKey, bobMoveHash);

        // Bob's reveal should succeed
        vm.startPrank(BOB);
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, abi.encode(1));

        // Alice's reveal will revert (must choose switch)
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        engine.revealMove(battleKey, aliceMoveIndex, salt, extraData);
    }

    function test_moveKOAndEffectKOLeadToDualSwapAndSwapSucceeds() public {
        // Initialize mons and moves
        IMoveSet lethalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = lethalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Instant death attack
        IEffect instantDeath = new InstantDeathEffect(engine);
        IMoveSet instantDeathAttack =
            new EffectAttack(engine, instantDeath, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory deathMoves = new IMoveSet[](1);
        deathMoves[0] = instantDeathAttack;
        Mon memory instantDeathMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: deathMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](2);
        team[0] = normalMon;
        team[1] = normalMon;
        Mon[] memory deathTeam = new Mon[](2);
        deathTeam[0] = instantDeathMon;
        deathTeam[1] = instantDeathMon;
        teams[0] = team;
        teams[1] = deathTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, which for Bob afflicts the instant death condition on the
        // opposing mon (Alice's) and knocks it out
        // But Bob moves first (higher priority), so he gets the instant death affliction
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Now both moves have to swap to index 1 for their mons
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(1), abi.encode(1)
        );
    }

    function test_shouldSkipTurnFlagWorks() public {
        // Initialize mons and moves
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 6})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        // Skip Turn attack to skip move
        IMoveSet skipAttack =
            new SkipTurnMove(engine, SkipTurnMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 7}));
        IMoveSet[] memory skipMoves = new IMoveSet[](1);
        skipMoves[0] = skipAttack;
        Mon memory skipMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: skipMoves,
            ability: IAbility(address(0))
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](1);
        team[0] = normalMon;
        Mon[] memory skipTeam = new Mon[](1);
        skipTeam[0] = skipMon;
        teams[0] = team;
        teams[1] = skipTeam;
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: validator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0
        // Bob goes for a fast skip turn effect
        // Alice tries to go fast for a lethal effect
        // Bob should win priority and inflict skip turn effect
        uint256 moveIndex = 0;
        bytes memory extraData = "";
        _commitRevealExecuteForAliceAndBob(battleKey, moveIndex, moveIndex, extraData, extraData);

        // Assert no winner, and no damage dealt
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, address(0));
        assertEq(state.monStates[1][0].hpDelta, 0);
    }

    function test_forceSwitchMoveCorrectlySwitchesNonPriorityPlayerEndOfRound() public {
        // Initialize mons and moves
        // Attack to force a switch (should be lower priority than the other move)
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 0}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        Mon[] memory team = new Mon[](2);
        team[0] = switchMon;
        team[1] = switchMon;

        Mon[] memory otherTeam = new Mon[](2);
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        otherTeam[0] = normalMon;
        otherTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, but Alice encodes a swap to mon index 1 for player index 1 (Bob)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, abi.encode(1, 1), "");

        // Verify that Bob's mon is now index 1
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.activeMonIndex[1], 1);

        // Verify that Alice's mon took damage
        assertEq(state.monStates[0][0].hpDelta, -5);
    }

    function test_forceSwitchMoveCorrectlySwitchesPriorityPlayerAfterAttacking() public {
        // Initialize mons and moves
        // Attack to force a switch for user (should be higher priority than the other move)
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = switchMon;
        team[1] = switchMon;
        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = normalMon;
        otherTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both player pick move index 0, but Alice encodes a swap to mon index 1 for player index 0 (Alice)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, abi.encode(0, 1), "");

        // Assert that Alice's mon is now index 1
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.activeMonIndex[0], 1);

        // Assert that Alice's new mon took damage
        assertEq(state.monStates[0][1].hpDelta, -5);
    }

    function test_forceSwitchMoveRevertsWhenInvalidSwitchTargetPriorityPlayerAfterAttacking() public {
        // Initialize mons and moves
        // Attack to force a switch for user (should be higher priority than the other move)
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = switchMon;
        team[1] = switchMon;
        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = normalMon;
        otherTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let Alice commit to switching to mon index 0 (invalid target) with player index 0 (herself)
        bytes32 salt = "";
        uint256 moveIndex = 0;
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, keccak256(abi.encodePacked(moveIndex, salt, abi.encode(0, 0))));

        // Let Bob commit and reveal to attack (move index 0)
        bytes memory extraData = "";
        vm.startPrank(BOB);
        engine.commitMove(battleKey, keccak256(abi.encodePacked(moveIndex, salt, extraData)));

        // Ensure Bob can reveal
        engine.revealMove(battleKey, moveIndex, salt, extraData);

        // Expect revert if Alice tries to reveal (should be marked as invalid switch)
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        engine.revealMove(battleKey, moveIndex, salt, abi.encode(0, 0));
    }

    function test_forceSwitchMoveRevertsWhenInvalidSwitchTargetNonPriorityPlayerAfterAttacking() public {
        // Initialize mons and moves
        // Attack to force a switch for user (should be higher priority than the other move)
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = switchMon;
        team[1] = switchMon;
        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = normalMon;
        otherTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let Alice commit to switching to mon index 1 (invalid target) with player index 0 (same mon)
        bytes32 salt = "";
        uint256 moveIndex = 0;
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, keccak256(abi.encodePacked(moveIndex, salt, abi.encode(1, 0))));

        // Let Bob commit and reveal to attack (move index 0)
        bytes memory extraData = "";
        vm.startPrank(BOB);
        engine.commitMove(battleKey, keccak256(abi.encodePacked(moveIndex, salt, extraData)));

        // Ensure Bob can reveal
        engine.revealMove(battleKey, moveIndex, salt, extraData);

        // Expect revert if Alice tries to reveal (should be marked as invalid switch)
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        engine.revealMove(battleKey, moveIndex, salt, abi.encode(1, 0));
    }

    // environmental effect kills mon after switch in from player move and forces switch
    function test_effectOnSwitchInFromSwitchMoveKOsAndForcesSwitch() public {
        // Initialize mons and moves
        // Attack to force a switch for user (should be higher priority than the other move)
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });

        // Create a new GlobalEffectAttack that applies InstantDeathOnSwitchIn
        IEffect instantDeathOnSwitchIn = new InstantDeathOnSwitchInEffect(engine);

        // Move should be higher priority than the switch attack
        IMoveSet instantDeathOnSwitchInAttack = new GlobalEffectAttack(
            engine, instantDeathOnSwitchIn, GlobalEffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = instantDeathOnSwitchInAttack;
        Mon memory stageHazardMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = switchMon;
        team[1] = switchMon;
        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = stageHazardMon;
        otherTeam[1] = stageHazardMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Let both players select move index 0
        // (Have Alice force themselves to switch to mon index 1)
        // (But swapping to mon index 1 will trigger on switch in and kill the mon)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, abi.encode(0, 1), "");

        // Assert that the player switch for turn flag is now 0, indicating Alice has to switch
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);

        // Assert that Alice's new mon is now KOed
        assertEq(state.monStates[0][1].isKnockedOut, true);
    }

    // environmental effect kills mon after switch in from other player move and forces switch
    function test_effectOnSwitchInFromSwitchMoveForOtherPlayerKOsAndForcesSwitch() public {
        // Initialize mons and moves
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1}));
        IEffect instantDeathOnSwitchIn = new InstantDeathOnSwitchInEffect(engine);
        IMoveSet instantDeathOnSwitchInAttack = new GlobalEffectAttack(
            engine, instantDeathOnSwitchIn, GlobalEffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2})
        );

        IMoveSet[] memory moves = new IMoveSet[](2);
        moves[0] = switchAttack;
        moves[1] = instantDeathOnSwitchInAttack;

        Mon memory mon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = mon;
        team[1] = mon;

        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = mon;
        otherTeam[1] = mon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 2, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // (Have Alice force Bob to switch to mon index 1, have Bob select the instant death switch in effect
        // (But swapping to mon index 1 will trigger on switch in and kill the mon)
        // Instant death on switch in (by Bob's mon) will trigger and kill his own mon
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 1, abi.encode(1, 1), "");

        // Assert that the player switch for turn flag is now 0, indicating Bob has to switch
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 1);

        // Assert that Bob's new mon is now KOed
        assertEq(state.monStates[1][1].isKnockedOut, true);
    }

    // environmental effect kills mon after switch in move (not as a side effect from move)
    function test_effectOnSwitchInFromDirectSwitchMoveKOsAndForcesSwitch() public {
        // Initialize mons and moves
        IEffect instantDeathOnSwitchIn = new InstantDeathOnSwitchInEffect(engine);

        // Set priority to be higher than switch
        IMoveSet instantDeathOnSwitchInAttack = new GlobalEffectAttack(
            engine, instantDeathOnSwitchIn, GlobalEffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 10})
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = instantDeathOnSwitchInAttack;

        Mon memory mon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = mon;
        team[1] = mon;

        Mon[] memory otherTeam = new Mon[](2);
        otherTeam[0] = mon;
        otherTeam[1] = mon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = otherTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Have Alice switch to their second mon, have Bob select the instant death switch in effect
        // (But swapping to mon index 1 for Alice will trigger on switch in and kill the mon)
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Assert that the player switch for turn flag is now 0, indicating Alice has to switch
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.playerSwitchForTurnFlag, 0);

        // Assert that Alice's new mon is now KOed
        assertEq(state.monStates[0][1].isKnockedOut, true);
    }

    // ability triggers effect leading to death on self after switch-in (lol)
    function test_abilityOnSwitchInKOsAndLeadsToGameOver() public {
        // Initialize mons and moves
        IMoveSet[] memory moves = new IMoveSet[](0);
        IEffect instantDeathAtEndOfTurn = new InstantDeathEffect(engine);
        IAbility suicideAbility = new EffectAbility(engine, instantDeathAtEndOfTurn);
        Mon memory suicideMon = Mon({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: suicideAbility
        });
        Mon memory normalMon = Mon({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory suicideTeam = new Mon[](1);
        suicideTeam[0] = suicideMon;
        Mon[] memory normalTeam = new Mon[](1);
        normalTeam[0] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = suicideTeam;
        teams[1] = normalTeam;

        DefaultValidator oneMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 0, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: oneMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // After this, Alice's mon should be dead and Bob should be the winner
        // Verify Bob is the winner
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, BOB);
    }

    // ability triggers effect leading to death on self after being switched in from self move
    function test_abilityOnSwitchInFromSwitchInMoveKOsAndLeadsToGameOver() public {
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        IEffect instantDeathAtEndOfTurn = new InstantDeathEffect(engine);
        IAbility suicideAbility = new EffectAbility(engine, instantDeathAtEndOfTurn);
        Mon memory suicideMon = Mon({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: suicideAbility
        });

        // A normal mon with a damaging move
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory suicideTeam = new Mon[](2);
        suicideTeam[0] = switchMon;
        suicideTeam[1] = suicideMon;

        Mon[] memory normalTeam = new Mon[](2);
        normalTeam[0] = normalMon;
        normalTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = suicideTeam;
        teams[1] = normalTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice switches themselves to mon index 1, while Bob chooses move index 0
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, abi.encode(0, 1), "");

        // Assert that Alice's new mon is now KOed
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][1].isKnockedOut, true);

        // Assert that player switch flag for turn is now 0, indicating Alice has to switch
        assertEq(state.playerSwitchForTurnFlag, 0);
    }

    // ability triggers effect from a manual switch
    function test_abilityOnSwitchInFromManualSwitchKOsAndLeadsToGameOver() public {
        IMoveSet switchAttack =
            new ForceSwitchMove(engine, ForceSwitchMove.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 2}));
        IMoveSet[] memory switchMoves = new IMoveSet[](1);
        switchMoves[0] = switchAttack;
        Mon memory switchMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: IAbility(address(0))
        });
        IEffect instantDeathAtEndOfTurn = new InstantDeathEffect(engine);
        IAbility suicideAbility = new EffectAbility(engine, instantDeathAtEndOfTurn);
        Mon memory suicideMon = Mon({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: switchMoves,
            ability: suicideAbility
        });

        // A normal mon with a damaging move
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 5, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory normalMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory suicideTeam = new Mon[](2);
        suicideTeam[0] = switchMon;
        suicideTeam[1] = suicideMon;

        Mon[] memory normalTeam = new Mon[](2);
        normalTeam[0] = normalMon;
        normalTeam[1] = normalMon;

        Mon[][] memory teams = new Mon[][](2);
        teams[0] = suicideTeam;
        teams[1] = normalTeam;

        DefaultValidator twoMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: twoMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice switches themselves to mon index 1, while Bob chooses move index 0
        _commitRevealExecuteForAliceAndBob(battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Assert that Alice's new mon is now KOed
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][1].isKnockedOut, true);

        // Assert that player switch flag for turn is now 0, indicating Alice has to switch
        assertEq(state.playerSwitchForTurnFlag, 0);
    }

    // attack that applies effect can only apply once (checks using an effect that writes to global KV)
    function test_attackThatAppliesEffectCanOnlyApplyOnce() public {
        // Single instance effect
        IEffect singleInstanceEffect = new SingleInstanceEffect(engine);
        IMoveSet effectAttack = new EffectAttack(
            engine, singleInstanceEffect, EffectAttack.Args({TYPE: Type.Fire, STAMINA_COST: 1, PRIORITY: 1})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = effectAttack;
        Mon memory mon = Mon({
            hp: 10,
            stamina: 2,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves,
            ability: IAbility(address(0))
        });
        Mon[] memory team = new Mon[](1);
        team[0] = mon;
        Mon[][] memory teams = new Mon[][](2);
        teams[0] = team;
        teams[1] = team;

        DefaultValidator oneMonValidator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        Battle memory battle = Battle({
            p0: ALICE,
            p1: BOB,
            validator: oneMonValidator,
            teams: teams,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0))
        });

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.start(battle);

        // First move of the game has to be selecting their mons (both index 0)
        _commitRevealExecuteForAliceAndBob(
            battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice and Bob both select attacks (they should apply the single instance effect on hit)
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Alice and Bob again both select attacks again
        _commitRevealExecuteForAliceAndBob(battleKey, 0, 0, "", "");

        // Assert that the effect was only applied once
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.monStates[0][0].targetedEffects.length, 1);
        assertEq(state.monStates[1][0].targetedEffects.length, 1);
    }
}
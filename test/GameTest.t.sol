// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";
import {IValidator} from "../src/IValidator.sol";

import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";

import {TypeCalculator} from "../src/types/TypeCalculator.sol";

import {CustomAttack} from "../src/moves/CustomAttack.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

contract GameTest is Test {
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
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves
        });
    }

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
     * Non-KO moves lead to subsequent move for both players [ ]
     * Switching executes at correct priority [ ]
     * Global Stamina Recovery effect works as expected [ ]
     * Accuracy works as expected (i.e. controls damage or no damage, modify oracle) [ ]
     * Stamina works as expected (i.e. controls whether or not a move can be used, deltas are updated) [ ]
     * Effects work as expected (create a damage over time effect, check that Effect can KO) [ ]
     */

    // Helper function, creates a battle with two mons for Alice and Bob
    function _startDummyBattle() internal returns (bytes32) {
        Mon[][] memory dummyTeams = new Mon[][](2);
        Mon[] memory dummyTeam = new Mon[](1);
        dummyTeam[0] = dummyMon;
        dummyTeams[0] = dummyTeam;
        dummyTeams[1] = dummyTeam;
        Battle memory dummyBattle =
            Battle({p0: ALICE, p1: BOB, validator: validator, teams: dummyTeams, rngOracle: defaultOracle});
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
        bytes32 bobMoveHash = keccak256(abi.encodePacked(aliceMoveIndex, salt, bobExtraData));
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
        vm.expectRevert(Engine.InvalidMove.selector);
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

    function test_FasterSpeedKOsGameOver() public {
        // Initialize fast and slow mons
        IMoveSet normalAttack = new CustomAttack(
            engine,
            typeCalc,
            CustomAttack.Args({TYPE: Type.Fire, BASE_POWER: 10, ACCURACY: 100, STAMINA_COST: 1, PRIORITY: 0})
        );
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = normalAttack;
        Mon memory fastMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves
        });
        Mon memory slowMon = Mon({
            hp: 10,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: moves
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;
        teams[0] = fastTeam;
        teams[1] = slowTeam;
        Battle memory battle =
            Battle({p0: ALICE, p1: BOB, validator: validator, teams: teams, rngOracle: defaultOracle});

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

    function test_FasterPriorityKOsGameOver() public {
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
            hp: 10,
            stamina: 2,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: slowMoves
        });
        Mon memory slowMon = Mon({
            hp: 10,
            stamina: 2,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: fastMoves
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory fastTeam = new Mon[](1);
        fastTeam[0] = fastMon;
        Mon[] memory slowTeam = new Mon[](1);
        slowTeam[0] = slowMon;
        teams[0] = fastTeam;
        teams[1] = slowTeam;
        Battle memory battle =
            Battle({p0: ALICE, p1: BOB, validator: validator, teams: teams, rngOracle: defaultOracle});

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

    // Helper function used to check that we correctly force a switch in priority matchups
    // if we knock out a mon (with higher priority), and there are mons remaining
    // End result is it Bob in the lead with 2 mons vs 1 mon for Alice
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
            hp: 10,
            stamina: 2,
            speed: 2,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: slowMoves
        });
        Mon memory slowMon = Mon({
            hp: 10,
            stamina: 2,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None,
            moves: fastMoves
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

        Battle memory battle =
            Battle({p0: ALICE, p1: BOB, validator: twoMonValidator, teams: teams, rngOracle: defaultOracle});

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

    function test_FasterPriorityKOsForcesSwitch() public {
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

    function test_FasterPriorityKOsForcesSwitchCorrectlyFailsOnInvalidSwitchReveal() public {
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
        vm.expectRevert(Engine.InvalidMove.selector);
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

    function test_FasterPriorityKOsForcesSwitchCorrectlyFailsOnInvalidSwitchNoCommit() public {
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

    function test_NonKOSubsequentMoves() public {
         // Initialize fast and slow mons
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
            moves: moves
        });
        Mon[][] memory teams = new Mon[][](2);
        Mon[] memory team = new Mon[](1);
        team[0] = normalMon;
        teams[0] = team;
        teams[1] = team;
        Battle memory battle =
            Battle({p0: ALICE, p1: BOB, validator: validator, teams: teams, rngOracle: defaultOracle});

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
}

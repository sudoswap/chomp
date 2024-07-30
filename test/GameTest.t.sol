// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Structs.sol";
import "../src/Enums.sol";
import "../src/Constants.sol";

import {IValidator} from "../src/IValidator.sol";
import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";

import {TypeCalculator} from "../src/types/TypeCalculator.sol";

import {CustomAttack} from "../src/moves/CustomAttack.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

contract GameTest is Test {
    Engine engine;
    DefaultValidator validator;
    TypeCalculator typeCalc;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant TIMEOUT_DURATION = 100;

    Mon dummyMon;
    IMoveSet dummyAttack;

    function setUp() public {
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
     * Battle initiated, stored to state [x]
     * - 2 players can start a battle
     *     - both players need to select a swap as their first move
     *
     * Battle initiated, MUST select swap [ ]
     * - 2 players can start a battle
     *     - after selecting mons
     *     - both players can call no op
     *     - turn should advance to count 2
     *
     * (for both p0 and p1)
     *
     * Faster Speed Wins KO/No-KO [ ]
     * - 2 players can start a battle
     *     - after selecting mons
     *     - player0's mon should move faster than player 1's mon if it's speedier
     *     - player0's mon should do damage (assume KO)
     *     - player1's mon should not do damage
     *     - if player1 only has 1 mon, it should be game over
     *
     * Faster Priority Wins KO/No-KO [ ]
     * - 2 players can start a battle
     *     - after selecting mons
     *     - player0's mon should move faster than player 1's mon if it's higher priority
     *     (regardless of p0 mon vs p1 mon speed)
     *
     *     - player0's mon should do damage (assume KO)
     *     - player1's mon should not do damage
     *     - if player1 only has 1 mon, it should be game over
     *
     * - Execute reverts if game is already over [x]
     */

    // Helper function, creates a battle with two mons for Alice and Bob
    function _startDummyBattle() internal returns (bytes32) {
        Mon[][] memory dummyTeams = new Mon[][](2);
        Mon[] memory dummyTeam = new Mon[](1);
        dummyTeam[0] = dummyMon;
        dummyTeams[0] = dummyTeam;
        dummyTeams[1] = dummyTeam;
        Battle memory dummyBattle = Battle({p0: ALICE, p1: BOB, validator: validator, teams: dummyTeams});
        vm.startPrank(ALICE);
        return engine.start(dummyBattle);
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

        // Assert ALICE wins
        BattleState memory state = engine.getBattleState(battleKey);
        assertEq(state.winner, ALICE);

        // Expect revert on calling end again
        vm.expectRevert(Engine.GameAlreadyOver.selector);
        engine.end(battleKey);

        // Expect revert on calling execute again
        vm.expectRevert(Engine.GameAlreadyOver.selector);
        engine.end(battleKey);
    }
}

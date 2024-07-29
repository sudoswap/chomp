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

    address ALICE = address(111111111111111111);
    address BOB = address(2222222222222222222);

    Mon dummyMon;
    IMoveSet dummyAttack;

    function setUp() public {
        engine = new Engine();
        validator = new DefaultValidator(engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1}));
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
     * Battle initiated, stored to state
     * - 2 players can start a battle
     *     - both players need to select a swap as their first move
     *
     * Battle initiated, MUST select swap
     * - 2 players can start a battle
     *     - after selecting mons
     *     - both players can call no op
     *     - turn should advance to count 2
     *
     * (for both p0 and p1)
     *
     * Faster Speed Wins KO/No-KO
     * - 2 players can start a battle
     *     - after selecting mons
     *     - player0's mon should move faster than player 1's mon if it's speedier
     *     - player0's mon should do damage (assume KO)
     *     - player1's mon should not do damage
     *     - if player1 only has 1 mon, it should be game over
     *
     * Faster Priority Wins KO/No-KO
     * - 2 players can start a battle
     *     - after selecting mons
     *     - player0's mon should move faster than player 1's mon if it's higher priority
     *     (regardless of p0 mon vs p1 mon speed)
     *
     *     - player0's mon should do damage (assume KO)
     *     - player1's mon should not do damage
     *     - if player1 only has 1 mon, it should be game over
     *
     * - Execute reverts if game is already over
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

        // TODO: fix for turn zero move selections
        engine.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData);

        // Let Bob commit to choosing move index of 0 instead
        uint256 moveIndex = 0;
        moveHash = keccak256(abi.encodePacked(moveIndex, salt, ""));
        vm.startPrank(BOB);
        engine.commitMove(battleKey, moveHash);

        // Ensure that Bob cannot reveal because validation will fail

        // Ensure that Bob cannot re-commit because he has already committed

        // Check that Alice can still reveal
    }
}

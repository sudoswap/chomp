// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {FastCommitManager} from "../src/FastCommitManager.sol";
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
import {OneTurnStatBoost} from "./mocks/OneTurnStatBoost.sol";
import {TestTeamRegistry} from "./mocks/TestTeamRegistry.sol";

import {TestTypeCalculator} from "./mocks/TestTypeCalculator.sol";

contract FastEngineTest is Test {
    FastCommitManager commitManager;
    Engine engine;
    ITypeCalculator typeCalc;
    DefaultRandomnessOracle defaultOracle;
    TestTeamRegistry defaultRegistry;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    address constant CARL = address(3);
    uint256 constant TIMEOUT_DURATION = 100;

    function setUp() public {
        defaultOracle = new DefaultRandomnessOracle();
        engine = new Engine();
        commitManager = new FastCommitManager(engine);
        engine.setCommitManager(address(commitManager));
        typeCalc = new TestTypeCalculator();
        defaultRegistry = new TestTeamRegistry();
    }

    // Helper function, creates a battle with two mons each for Alice and Bob
    function _startDummyBattle() internal returns (bytes32) {
        IMoveSet[] memory moves = new IMoveSet[](1);
        Mon memory dummyMon = Mon({
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

        Mon[] memory dummyTeam = new Mon[](2);
        dummyTeam[0] = dummyMon;
        dummyTeam[1] = dummyMon;

        // Register teams
        defaultRegistry.setTeam(ALICE, dummyTeam);
        defaultRegistry.setTeam(BOB, dummyTeam);

        // Set up validator
        DefaultValidator validator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

        // Setup battle
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
                args.p0TeamHash
            )
        );
        vm.prank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);
        vm.prank(ALICE);
        engine.startBattle(battleKey, "", 0);

        return battleKey;
    }

    function test_commitBattleWithoutAcceptReverts() public {

        /*
        - both players can propose (without accepting) and nonce will not increase (i.e. battle key does not change)
        - accepting a battle increments the nonce for the next propose (i.e. battle key changes)
        - committing should fail if the battle is not accepted
        */

        IMoveSet[] memory moves = new IMoveSet[](1);
        Mon memory dummyMon = Mon({
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
        Mon[] memory dummyTeam = new Mon[](1);
        dummyTeam[0] = dummyMon;

        // Register teams
        defaultRegistry.setTeam(ALICE, dummyTeam);
        defaultRegistry.setTeam(BOB, dummyTeam);

        // Set up validator
        DefaultValidator validator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );

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
        vm.startPrank(ALICE);
        bytes32 battleKey = engine.proposeBattle(args);

        // Have Bob propose a battle
        vm.startPrank(BOB);
        StartBattleArgs memory bobArgs = StartBattleArgs({
            p0: BOB,
            p1: ALICE,
            validator: validator,
            rngOracle: defaultOracle,
            ruleset: IRuleset(address(0)),
            teamRegistry: defaultRegistry,
            p0TeamHash: keccak256(
                abi.encodePacked(bytes32(""), uint256(0), defaultRegistry.getMonRegistryIndicesForTeam(BOB, 0))
            )
        });
        bytes32 updatedBattleKey = engine.proposeBattle(bobArgs);

        // Battle key should be the same when no one accepts
        assertEq(battleKey, updatedBattleKey);

        // Assert it reverts for Alice upon commit
        vm.expectRevert(FastCommitManager.BattleNotStarted.selector);
        vm.startPrank(ALICE);
        commitManager.commitMove(battleKey, "");

        // Assert it reverts for Bob upon commit
        vm.expectRevert(FastCommitManager.BattleNotStarted.selector);
        vm.startPrank(BOB);
        commitManager.commitMove(battleKey, "");

        // Have Alice accept the battle bob proposed
        vm.startPrank(ALICE);
        bytes32 battleIntegrityHash = keccak256(
            abi.encodePacked(
                args.validator,
                args.rngOracle,
                args.ruleset,
                args.teamRegistry,
                bobArgs.p0TeamHash
            )
        );
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);

        // Have Bob start the Battle (given that Alice accepted)
        vm.startPrank(BOB);
        engine.startBattle(battleKey, "", 0);

        // Have Bob propose a new battle
        vm.warp(validator.TIMEOUT_DURATION() + 1);
        vm.startPrank(BOB);
        bytes32 newBattleKey = engine.proposeBattle(bobArgs);

        // Battle key should be different when one accepts
        assertNotEq(battleKey, newBattleKey);
    }

    /*
    Checks that:
    - reveal for player who has to commit) correctly reverts if they haven't committed
    - reveal for player who does not have to commit() correctly reverts if the other player hasn't committed
    - non-players cannot commit or reveal
    - revealing an invalid move reverts
    - after revealing a valid move, auto-execute advances game state
    */
    function test_turn0FastCommitManagerValidPreimage() public {
        bytes32 battleKey = _startDummyBattle();
        bytes32 salt = "";
        bytes memory extraData = abi.encode(0);
        bytes32 moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, extraData));

        // Ensure Alice cannot reveal yet because Alice has not yet committed
        // It is turn 0, so Alice must first commit then reveal
        // We will attempt to calculate the preimage, which will fail
        vm.startPrank(ALICE);
        vm.expectRevert(FastCommitManager.WrongPreimage.selector);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Ensure Bob cannot commit as they only need to reveal
        vm.startPrank(BOB);
        vm.expectRevert(FastCommitManager.PlayerNotAllowed.selector);
        commitManager.commitMove(battleKey, moveHash);

        // Bob cannot reveal yet as Alice has not committed
        vm.expectRevert(FastCommitManager.RevealBeforeOtherCommit.selector);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Ensure Carl cannot commit as they are not in the battle
        vm.startPrank(CARL);
        vm.expectRevert(FastCommitManager.NotP0OrP1.selector);
        commitManager.commitMove(battleKey, moveHash);

        // Carl should also be unable to reveal
        vm.expectRevert(FastCommitManager.NotP0OrP1.selector);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Let Alice commit the first move (switching in mon index 0)
        vm.startPrank(ALICE);
        commitManager.commitMove(battleKey, moveHash);

        // Let Bob reveal their invalid move index of 0
        vm.startPrank(BOB);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", BOB));
        commitManager.revealMove(battleKey, 0, salt, extraData, true);

        // Now let Bob reveal a valid move
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Alice reveals her move
        vm.startPrank(ALICE);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Assert that the game state executed
        uint256 turnId = engine.getTurnIdForBattleState(battleKey);
        assertEq(turnId, 1);
    }

    /*
    Checks that:
    - committing an invalid state prevents reveal
    - advancing state has the same reverts as expected, but now for the other player index
    */
    function test_turn0FastCommitManagerInvalidPreimage() public {
        bytes32 battleKey = _startDummyBattle();

        // Let Alice commit to choosing switch
        bytes32 salt = "";
        bytes memory extraData = abi.encode(0);
        bytes32 moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, extraData));

        // Let Alice commit the first move (switching in mon index 0)
        vm.startPrank(ALICE);
        commitManager.commitMove(battleKey, moveHash);

        // Let Bob reveal their invalid move index of 0
        vm.startPrank(BOB);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Alice reveals her move incorrectly, leading to an error
        vm.startPrank(ALICE);
        vm.expectRevert(FastCommitManager.WrongPreimage.selector);
        commitManager.revealMove(battleKey, 0, salt, extraData, true);

        // Alice correctly reveals her move, advancing the game state
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // New turn, both players swap to mon index 1
        extraData = abi.encode(1);
        moveHash = keccak256(abi.encodePacked(SWITCH_MOVE_INDEX, salt, extraData));

        // Ensure Bob cannot reveal yet because Bob has not yet committed
        // It is turn 1, so Bob must first commit then reveal
        // We will attempt to calculate the preimage, which will fail
        vm.startPrank(BOB);
        vm.expectRevert(FastCommitManager.WrongPreimage.selector);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Ensure Alice cannot commit as they only need to reveal
        vm.startPrank(ALICE);
        vm.expectRevert(FastCommitManager.PlayerNotAllowed.selector);
        commitManager.commitMove(battleKey, moveHash);

        // Alice cannot reveal yet as Bob has not committed
        vm.expectRevert(FastCommitManager.RevealBeforeOtherCommit.selector);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Let Bob commit the first move (switching in mon index 0)
        vm.startPrank(BOB);
        commitManager.commitMove(battleKey, moveHash);

        // Let Alice reveal their invalid move index of 0
        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSignature("InvalidMove(address)", ALICE));
        bytes memory invalidExtraData = abi.encode(0);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, invalidExtraData, true);

        // Now let Alice reveal a valid move
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Bob reveals their move
        vm.startPrank(BOB);
        commitManager.revealMove(battleKey, SWITCH_MOVE_INDEX, salt, extraData, true);

        // Assert that the game state executed
        uint256 turnId = engine.getTurnIdForBattleState(battleKey);
        assertEq(turnId, 2);
    }
}
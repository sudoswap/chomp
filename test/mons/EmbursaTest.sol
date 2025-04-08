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
import {SplitThePot} from "../../src/mons/embursa/SplitThePot.sol";
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

contract EmbursaTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    SplitThePot splitThePot;
    StandardAttackFactory attackFactory;

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
        splitThePot = new SplitThePot(IEngine(address(engine)));
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
    }

    function test_splitThePot_healing() public {
        // Create a team with two mons that have SplitThePot ability
        int32 hpScale = 100;

        // Create an attack that deals exactly HEAL_DENOM damage
        IMoveSet standardAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: uint32(hpScale) * 2,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Fire,
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "DamageAttack",
                EFFECT: IEffect(address(0))
            })
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = standardAttack;

        // Create two mons with SplitThePot ability and HP = hpScale * HEAL_DENOM
        Mon memory embursa = Mon({
            stats: MonStats({
                hp: uint32(splitThePot.HEAL_DENOM() * hpScale),
                stamina: 5,
                speed: 10,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(splitThePot))
        });

        // Create a regular mon for the opponent
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: uint32(splitThePot.HEAL_DENOM() * hpScale),
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Create teams
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = embursa;
        aliceTeam[1] = regularMon;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = regularMon;
        bobTeam[1] = regularMon;

        // Register teams
        defaultRegistry.setTeam(ALICE, aliceTeam);
        defaultRegistry.setTeam(BOB, bobTeam);

        // Start battle
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

        // Test 1: Both players NO_OP, which should not trigger healing for p0 as all mons are at full HP
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify no healing occurred
        assertEq(engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp), 0, "Mon 0 should not be healed");
        assertEq(engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Hp), 0, "Mon 1 should not be healed");

        // First, Bob deals damage, and Alice does a No-Op
        // Alice moves first (higher speed), so this shouldn't heal her because it's before damage is done
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", "");

        // Verify damage occurred
        assertEq(
            engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp),
            -2 * hpScale,
            "Mon 0 should have taken damage"
        );

        // Next, both players do a No-Op, which should trigger healing for p0
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify healing occurred
        // Mon 0 should be healed by HEAL_DENOM/HEAL_DENOM = 1/16 of max HP
        assertEq(
            engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp),
            -1 * hpScale,
            "Mon 0 should be healed by 1/DENOM of max HP"
        );

        // Now, Alice should switch to mon index 1, and Bob should choose the damage move
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, SWITCH_MOVE_INDEX, 0, abi.encode(1), "");

        // Verify damage occurred
        assertEq(
            engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Hp),
            -2 * hpScale,
            "Mon 1 should have taken damage"
        );

        // Next, both players do a No-Op, which should NOT trigger healing for p0 as mon 1 does not have SplitThePot
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify no healing occurred
        assertEq(engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Hp), -2 * hpScale, "Mon 1 should not be healed");

        // Next, Alice switches back to mon index 0, and Bob chooses to No-Op
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(0), "");

        // Verify no healing occurred
        assertEq(engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp), -1 * hpScale, "Mon 0 should not be healed");

        // Next, both players do a No-Op, which should trigger healing for p0 (both mons)
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify healing occurred for both mons
        assertEq(
            engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp),
            0,
            "Mon 0 should be healed by 1/DENOM of max HP"
        );
        assertEq(
            engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Hp),
            -1 * hpScale,
            "Mon 1 should be healed by 1/DENOM of max HP"
        );
    }
}

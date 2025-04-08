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

import {StatBoost} from "../../src/effects/StatBoost.sol";
import {Interweaving} from "../../src/mons/inutia/Interweaving.sol";
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

contract InutiaTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    Interweaving interweaving;
    StatBoost statBoost;
    StandardAttackFactory attackFactory;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 0, TIMEOUT_DURATION: 10})
        );
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));
        statBoost = new StatBoost(IEngine(address(engine)));
        interweaving = new Interweaving(IEngine(address(engine)), IEffect(address(statBoost)));
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
    }

    function test_interweaving() public {
        // Create a team with a mon that has Interweaving ability
        IMoveSet[] memory moves = new IMoveSet[](0);
        // Create a mon with Interweaving ability
        Mon memory interweavingMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 5,
                speed: 5,
                attack: 10,
                defense: 5,
                specialAttack: 10,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(interweaving))
        });

        // Create a regular mon without the ability
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 5,
                speed: 5,
                attack: 10,
                defense: 5,
                specialAttack: 10,
                specialDefense: 5,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Set up teams with two mons each
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = regularMon;
        aliceTeam[1] = interweavingMon;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = regularMon;
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

        // Store Bob's mon initial Attack stat
        int32 bobInitialAttack = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Attack);
        int32 bobInitialSpecialAttack = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialAttack);

        // First move: Alice switches to the mon with Interweaving ability, Bob switches to the other mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(1), abi.encode(0)
        );

        // Check that Bob's mon Attack stat has been decreased
        int32 bobAttackAfterSwapIn = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Attack);
        int32 expectedAttackDecrease = -1; // -1 * base Attack / DECREASE_DENOM
        assertEq(
            bobAttackAfterSwapIn, bobInitialAttack + expectedAttackDecrease, "Attack should be decreased after swap in"
        );

        // Alice switches back to the regular mon, Bob does a No-Op
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(0), ""
        );

        // Check that Bob's mon SpecialAttack stat has been decreased
        int32 bobSpecialAttackAfterSwapOut =
            engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialAttack);
        int32 expectedSpecialAttackDecrease = -1; // -1 * base SpecialAttack / DECREASE_DENOM
        assertEq(
            bobSpecialAttackAfterSwapOut,
            bobInitialSpecialAttack + expectedSpecialAttackDecrease,
            "SpecialAttack should be decreased after swap out"
        );
    }
}

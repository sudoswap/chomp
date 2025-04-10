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
import {Overclock} from "../../src/mons/volthare/Overclock.sol";
import {Storm} from "../../src/effects/weather/Storm.sol";
import {StatBoost} from "../../src/effects/StatBoost.sol";
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

contract VolthareTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    Overclock overclock;
    Storm storm;
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
        storm = new Storm(IEngine(address(engine)), IEffect(address(statBoost)));
        overclock = new Overclock(IEngine(address(engine)), storm);
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
    }

    function test_overclockAppliesStorm() public {
        // Create a team with a mon that has Overclock ability
        IMoveSet[] memory moves = new IMoveSet[](0);

        // Create a mon with Overclock ability and nice round stats
        Mon memory overclockMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 100,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 100,
                type1: Type.Lightning,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(overclock))
        });

        // Create a regular mon with the same stats but no ability
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 100,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 100,
                type1: Type.Lightning,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Create teams for Alice and Bob
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = overclockMon;
        aliceTeam[1] = regularMon;

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

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Verify that Storm effect is applied
        // Check if the Storm duration is set to the default duration (2) (because turn end already ran)
        uint256 stormDuration = storm.getDuration(battleKey, 0);
        assertEq(stormDuration, storm.DEFAULT_DURATION() - 1, "Storm should be applied with default duration");

        // Verify that Alice's mon's speed is boosted according to Storm's constants
        // Speed should be increased by SPEED_NUM/SPEED_DENOM (5/4)
        int32 expectedSpeedBoost = int32(100) / storm.SPEED_DENOM();
        int32 speedDelta = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Speed);
        assertEq(speedDelta, expectedSpeedBoost, "Speed should be boosted");

        // Verify that Alice's mon's special defense is decreased according to Storm's constants
        // SpDef should be decreased (3/4)
        int32 expectedSpDefDebuff = -1 * int32(100) / storm.SP_DEF_DENOM();
        int32 spDefDelta = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialDefense);
        assertEq(spDefDelta, expectedSpDefDebuff, "Special Defense should be decreased");

        // Bob's mon should not be affected by the Storm since it's on Alice's side
        int32 bobSpeedDelta = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Speed);
        int32 bobSpDefDelta = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialDefense);
        assertEq(bobSpeedDelta, 0, "Bob's mon's speed should not be affected by Storm");
        assertEq(bobSpDefDelta, 0, "Bob's mon's special defense should not be affected by Storm");

        // Alice swaps in mon index 1, Bob does nothing (duration is now 1)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, NO_OP_MOVE_INDEX, abi.encode(1), ""
        );

        // Verify that Alice's new mon's speed/spdef are affected the same way
        speedDelta = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Speed);
        spDefDelta = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.SpecialDefense);
        assertEq(speedDelta, expectedSpeedBoost, "Speed should be boosted");
        assertEq(spDefDelta, expectedSpDefDebuff, "Special Defense should be decreased");

        // Both players do nothing, storm subsides (duration is now 0)
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Verify that Alice's mon's speed/spdef are reset
        speedDelta = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Speed);
        spDefDelta = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.SpecialDefense);
        assertEq(speedDelta, 0, "Speed should be reset after Storm subsides");
        assertEq(spDefDelta, 0, "Special Defense should be reset after Storm subsides");

        // Verify that Storm is removed from global effects
        (IEffect[] memory effects,) = engine.getEffects(battleKey, 2, 0);
        assertEq(effects.length, 0, "Storm effect should be removed from global effects after Storm subsides");
    }

    function test_doubleOverclock() public {
        // Create a team with a mon that has Overclock ability
        IMoveSet[] memory moves = new IMoveSet[](0);

        // Create a mon with Overclock ability and nice round stats
        Mon memory overclockMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 100,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 100,
                type1: Type.Lightning,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(overclock))
        });

        // Create a regular mon with the same stats but no ability
        Mon memory regularMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 100,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 100,
                type1: Type.Lightning,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // Create teams for Alice and Bob
        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = overclockMon;
        aliceTeam[1] = regularMon;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = regularMon;
        bobTeam[1] = overclockMon;

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

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Alice does nothing, Bob switches in his Overclock mon
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, SWITCH_MOVE_INDEX, "", abi.encode(1)
        );

        // Verify that the stat changes are applied to Bob's mon
        int32 expectedSpeedBoost = int32(100) / storm.SPEED_DENOM();
        int32 expectedSpDefDebuff = -1 * int32(100) / storm.SP_DEF_DENOM();
        int32 bobSpeedDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.Speed);
        int32 bobSpDefDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.SpecialDefense);
        assertEq(bobSpeedDelta, expectedSpeedBoost, "Bob's mon's speed should be boosted");
        assertEq(bobSpDefDelta, expectedSpDefDebuff, "Bob's mon's special defense should be decreased");

        // Wait a turn
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Alice's mon should have its stats reset
        int32 aliceSpeedDelta = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Speed);
        int32 aliceSpDefDelta = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialDefense);
        assertEq(aliceSpeedDelta, 0, "Alice's mon's speed should be reset");
        assertEq(aliceSpDefDelta, 0, "Alice's mon's special defense should be reset");

        // Bob should not be reset
        bobSpeedDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.Speed);
        bobSpDefDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.SpecialDefense);
        assertEq(bobSpeedDelta, expectedSpeedBoost, "Bob's mon's speed should not be reset");
        assertEq(bobSpDefDelta, expectedSpDefDebuff, "Bob's mon's special defense should not be reset");

        // Wait another turn
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, NO_OP_MOVE_INDEX, NO_OP_MOVE_INDEX, "", "");

        // Bob's mon should have its stats reset
        bobSpeedDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.Speed);
        bobSpDefDelta = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.SpecialDefense);
        assertEq(bobSpeedDelta, 0, "Bob's mon's speed should be reset");
        assertEq(bobSpDefDelta, 0, "Bob's mon's special defense should be reset");
    }
}
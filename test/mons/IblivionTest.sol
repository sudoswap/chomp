// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Structs.sol";
import {Test} from "forge-std/Test.sol";

import {Engine} from "../../src/Engine.sol";
import {MonStateIndexName, MoveClass, Type, EffectStep} from "../../src/Enums.sol";
import {FastCommitManager} from "../../src/FastCommitManager.sol";

import {FastValidator} from "../../src/FastValidator.sol";
import {IEngine} from "../../src/IEngine.sol";
import {IFastCommitManager} from "../../src/IFastCommitManager.sol";
import {IRuleset} from "../../src/IRuleset.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

import {StatBoost} from "../../src/effects/StatBoost.sol";
import {IntrinsicValue} from "../../src/mons/iblivion/IntrinsicValue.sol";
import {Baselight} from "../../src/mons/iblivion/Baselight.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";
import {StatBoostMove} from "../mocks/StatBoostMove.sol";

contract IblivionTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    IntrinsicValue intrinsicValue;
    Baselight baselight;
    StatBoost statBoost;
    StatBoostMove statBoostMove;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: 10})
        );
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));
        statBoost = new StatBoost(IEngine(address(engine)));
        baselight = new Baselight(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
        intrinsicValue = new IntrinsicValue(IEngine(address(engine)), baselight, IEffect(address(statBoost)));
        statBoostMove = new StatBoostMove(IEngine(address(engine)), statBoost);
    }

    function test_intrinsicValueResetsDebuffsAndIncreasesBaselightLevel() public {
        // Test all stat types
        _testStatDebuffReset(MonStateIndexName.Attack);
        _testStatDebuffReset(MonStateIndexName.Defense);
        _testStatDebuffReset(MonStateIndexName.SpecialAttack);
        _testStatDebuffReset(MonStateIndexName.SpecialDefense);
        _testStatDebuffReset(MonStateIndexName.Speed);
    }

    function _testStatDebuffReset(MonStateIndexName statType) internal {
        // Create a team with a mon that has IntrinsicValue ability and Baselight move
        IMoveSet[] memory aliceMoves = new IMoveSet[](1);
        aliceMoves[0] = baselight;

        Mon memory aliceMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: aliceMoves,
            ability: IAbility(address(intrinsicValue))
        });

        // Create a StandardAttack that applies any debuff
        IMoveSet[] memory bobMoves = new IMoveSet[](1);
        bobMoves[0] = statBoostMove;

        Mon memory bobMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 10,
                speed: 5, // Lower speed so Alice goes first
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: bobMoves,
            ability: IAbility(address(0)) // No ability
        });

        // Set up teams
        Mon[] memory aliceTeam = new Mon[](1);
        aliceTeam[0] = aliceMon;

        Mon[] memory bobTeam = new Mon[](1);
        bobTeam[0] = bobMon;

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

        vm.startPrank(ALICE);
        bytes32 battleKey = engine.proposeBattle(args);

        bytes32 battleIntegrityHash = keccak256(
            abi.encodePacked(args.validator, args.rngOracle, args.ruleset, args.teamRegistry, args.p0TeamHash)
        );

        vm.startPrank(BOB);
        engine.acceptBattle(battleKey, 0, battleIntegrityHash);

        vm.startPrank(ALICE);
        engine.startBattle(battleKey, "", 0);

        // First move: Both players select their first mon (index 0)
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Check that Alice's mon has the IntrinsicValue effect
        (IEffect[] memory aliceEffects,) = engine.getEffects(battleKey, 0, 0);
        bool hasIntrinsicValueEffect = false;
        for (uint i = 0; i < aliceEffects.length; i++) {
            if (aliceEffects[i] == IEffect(address(intrinsicValue))) {
                hasIntrinsicValueEffect = true;
                break;
            }
        }
        assertTrue(hasIntrinsicValueEffect, "Alice's mon should have IntrinsicValue effect");

        // Get initial stat value
        int32 statBefore = engine.getMonStateForBattle(battleKey, 0, 0, statType);

        // Get initial Baselight level
        uint256 baselightLevelBefore = baselight.getBaselightLevel(battleKey, 0, 0);

        // Bob uses debuff attack on Alice's mon
        // The debuff applies -1 to the specified stat, which then gets reset at end of round
        bytes memory debuffData = abi.encode(0, 0, uint256(statType), int32(-1));
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", debuffData
        );

        // Check that Alice's mon's stat debuff has been reset
        int32 statAfterReset = engine.getMonStateForBattle(battleKey, 0, 0, statType);
        assertEq(statAfterReset, statBefore, string(abi.encodePacked("Stat debuff for ", _getStatName(statType), " should be reset")));

        // Check that Baselight level has been increased
        uint256 baselightLevelAfter = baselight.getBaselightLevel(battleKey, 0, 0);
        assertEq(baselightLevelAfter, baselightLevelBefore + 1, string(abi.encodePacked("Baselight level should be increased by 1 after resetting ", _getStatName(statType), " debuff")));
    }

    // Helper function to get stat name for better error messages
    function _getStatName(MonStateIndexName statType) internal pure returns (string memory) {
        if (statType == MonStateIndexName.Attack) return "Attack";
        if (statType == MonStateIndexName.Defense) return "Defense";
        if (statType == MonStateIndexName.SpecialAttack) return "SpecialAttack";
        if (statType == MonStateIndexName.SpecialDefense) return "SpecialDefense";
        if (statType == MonStateIndexName.Speed) return "Speed";
        return "Unknown";
    }
}
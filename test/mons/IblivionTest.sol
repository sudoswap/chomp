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

import {StatBoosts} from "../../src/effects/StatBoosts.sol";
import {IntrinsicValue} from "../../src/mons/iblivion/IntrinsicValue.sol";
import {Baselight} from "../../src/mons/iblivion/Baselight.sol";
import {Loop} from "../../src/mons/iblivion/Loop.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";
import {StandardAttack} from "../../src/moves/StandardAttack.sol";
import {StandardAttackFactory} from "../../src/moves/StandardAttackFactory.sol";
import {StatBoostsMove} from "../mocks/StatBoostsMove.sol";

contract IblivionTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    IntrinsicValue intrinsicValue;
    Baselight baselight;
    Loop loop;
    StatBoosts statBoost;
    StatBoostsMove statBoostMove;
    StandardAttackFactory attackFactory;

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
        statBoost = new StatBoosts(IEngine(address(engine)));
        baselight = new Baselight(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
        loop = new Loop(IEngine(address(engine)));
        intrinsicValue = new IntrinsicValue(IEngine(address(engine)), baselight, statBoost);
        statBoostMove = new StatBoostsMove(IEngine(address(engine)), statBoost);
        attackFactory = new StandardAttackFactory(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));
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
                stamina: 100,
                speed: 100,
                attack: 100,
                defense: 100,
                specialAttack: 100,
                specialDefense: 100,
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
                speed: 10,
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
        // The debuff applies -1% to the specified stat, which then gets reset at end of round
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

    function test_baselightSequentialUse() public {
        // Create a team with a mon that has Baselight move and high HP
        IMoveSet[] memory aliceMoves = new IMoveSet[](1);
        aliceMoves[0] = baselight;

        Mon memory aliceMon = Mon({
            stats: MonStats({
                hp: 1000,
                stamina: 20,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: aliceMoves,
            ability: IAbility(address(0))
        });

        // Create a mon with high HP to receive damage
        IMoveSet[] memory bobMoves = new IMoveSet[](1);
        bobMoves[0] = statBoostMove; // Just a placeholder move

        Mon memory bobMon = Mon({
            stats: MonStats({
                hp: 10000,
                stamina: 20,
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

        // Use Baselight sequentially and verify damage and stamina cost
        for (uint256 i = 0; i < baselight.MAX_BASELIGHT_LEVEL(); i++) {
            // Get current Baselight level before the move
            uint256 currentBaselightLevel = baselight.getBaselightLevel(battleKey, 0, 0);
            assertEq(currentBaselightLevel, i, string(abi.encodePacked("Baselight level should be ", vm.toString(i), " before move")));

            // Get current stamina before the move
            int32 aliceStaminaBefore = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);

            // Get Bob's HP before the move
            int32 bobHpBefore = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Hp);

            // Alice uses Baselight, Bob uses NO_OP
            _commitRevealExecuteForAliceAndBob(
                engine, commitManager, battleKey, 0, NO_OP_MOVE_INDEX, "", ""
            );

            // Get new Baselight level after the move
            uint256 newBaselightLevel = baselight.getBaselightLevel(battleKey, 0, 0);
            assertEq(newBaselightLevel, i + 1, string(abi.encodePacked("Baselight level should be ", vm.toString(i + 1), " after move")));

            // Get stamina after the move
            int32 aliceStaminaAfter = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);

            // Verify stamina cost (should be equal to the Baselight level before the move)
            int32 expectedStaminaCost = int32(int256(currentBaselightLevel));
            assertEq(aliceStaminaBefore - aliceStaminaAfter, expectedStaminaCost,
                string(abi.encodePacked("Stamina cost should be ", vm.toString(uint256(uint32(expectedStaminaCost))), " at level ", vm.toString(currentBaselightLevel))));

            // Get Bob's HP after the move
            int32 bobHpAfter = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Hp);
            uint32 expectedBasePower = baselight.BASE_POWER() + (uint32(currentBaselightLevel) * baselight.BASELIGHT_LEVEL_BOOST());
            uint32 damageDealt = uint32(bobHpBefore - bobHpAfter);
            assertApproxEqRel(damageDealt, expectedBasePower, 2e17, string(abi.encodePacked("Damage dealt should be ", vm.toString(expectedBasePower), " at level ", vm.toString(currentBaselightLevel))));
        }

        // Do it one more time and verify that Baselight does not go up more
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, 0, NO_OP_MOVE_INDEX, "", ""
        );

        uint256 finalBaselightLevel = baselight.getBaselightLevel(battleKey, 0, 0);
        assertEq(finalBaselightLevel, baselight.MAX_BASELIGHT_LEVEL(), "Baselight level should not exceed max level");
    }

    function test_loop() public {
        // Create a new validator with 2 moves per mon
        FastValidator twoMovesValidator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 2, TIMEOUT_DURATION: 10})
        );

        // Create a StandardAttack with 5 stamina cost but 0 damage
        StandardAttack highStaminaAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: 0, // No damage
                STAMINA_COST: 5, // High stamina cost
                ACCURACY: 100,
                PRIORITY: 0,
                MOVE_TYPE: Type.Fire,
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "Stamina Drain",
                EFFECT: IEffect(address(0))
            })
        );

        // Create a team with a mon that has Loop move and the high stamina cost attack
        IMoveSet[] memory aliceMoves = new IMoveSet[](2);
        aliceMoves[0] = highStaminaAttack;
        aliceMoves[1] = loop;

        Mon memory aliceMon = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 6,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: aliceMoves,
            ability: IAbility(address(0))
        });

        // Create a mon for Bob
        IMoveSet[] memory bobMoves = new IMoveSet[](2);
        bobMoves[0] = statBoostMove; // Just a placeholder move
        bobMoves[1] = statBoostMove; // Just a placeholder move

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
            validator: twoMovesValidator, // Use the validator with 2 moves per mon
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

        // Alice uses high stamina cost attack, Bob does nothing
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, 0, NO_OP_MOVE_INDEX, "", ""
        );

        // Get the stamina delta (staminaDelta is stored in the Stamina field)
        int32 staminaDelta = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);
        assertEq(staminaDelta, -5, "Stamina should be 0 after using high stamina cost attack");

        // Alice uses Loop, Bob does nothing
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, 1, NO_OP_MOVE_INDEX, "", ""
        );

        // Check that Alice's mon's stamina delta is reset
        int32 staminaDeltaAfterLoop = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Stamina);
        assertEq(staminaDeltaAfterLoop, 0, "Stamina delta should be reset to 0 after using Loop");
    }
}
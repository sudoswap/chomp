// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../../lib/forge-std/src/Test.sol";

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {Engine} from "../../src/Engine.sol";
import {FastCommitManager} from "../../src/FastCommitManager.sol";
import {FastValidator} from "../../src/FastValidator.sol";
import {IEngine} from "../../src/IEngine.sol";
import {IFastCommitManager} from "../../src/IFastCommitManager.sol";
import {IRuleset} from "../../src/IRuleset.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {StatBoost} from "../../src/effects/StatBoost.sol";
import {StatBoostMove} from "../mocks/StatBoostMove.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";

contract StatBoostTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    IValidator validator;
    StatBoost statBoost;
    StatBoostMove statBoostMove;

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

        // Create the StatBoost effect and move
        statBoost = new StatBoost(IEngine(address(engine)));
        statBoostMove = new StatBoostMove(IEngine(address(engine)), statBoost);
    }

    function test_statBoostMove() public {
        // Create teams with two mons each
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = statBoostMove; // Stat boost move (we'll pass different params when using it)

        Mon memory mon1 = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 100,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon memory mon2 = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 100,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = mon1;
        aliceTeam[1] = mon2;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = mon1;
        bobTeam[1] = mon2;

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

        // We'll test Attack stat in detail
        testStatBoost(battleKey, uint256(MonStateIndexName.Attack));
    }

    /*
        - Create a boost
        - Check to see that the effect is added to the mon's effects array
        - Next turn, update, the boost
        - Check to see that the effect is still in the mon's effects array (but no extra array value)
        - Next turn, add a debuff that reduces the boost
        - Check to see that the effect is still in the mon's effects array (but no extra array value)
        - Next turn, switch out
        - Check to see that the effect is removed from the mon's effects array
    */
    function testStatBoost(bytes32 battleKey, uint256 statIndex) internal {
        string memory statName = getStatName(statIndex);

        // 1. Apply a positive boost (+2) to Alice's mon
        console.log("Testing %s stat boost", statName);
        console.log("1. Applying +2 boost to Alice's mon");

        int32 initialStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndex));

        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            0, // Alice uses stat boost move
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(0, 0, statIndex, int32(2)), // Alice boosts her own mon by +2
            "" // Bob does nothing
        );

        // Verify the stat was boosted
        int32 boostedStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndex));
        assertEq(boostedStat, initialStat + 2, "Stat should be boosted by +2");

        // Verify the effect was added to Alice's mon
        (IEffect[] memory effects,) = engine.getEffects(battleKey, 0, 0);
        bool foundEffect = false;
        for (uint256 i = 0; i < effects.length; i++) {
            if (keccak256(abi.encodePacked(effects[i].name())) == keccak256(abi.encodePacked(statBoost.name()))) {
                foundEffect = true;
                break;
            }
        }
        assertTrue(foundEffect, "StatBoost effect should be added to mon's effects");
        uint256 effectCount = effects.length;

        // 2. Apply another boost (+1) to the same stat
        console.log("2. Applying additional +1 boost to Alice's mon");

        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            0, // Alice uses stat boost move
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(0, 0, statIndex, int32(1)), // Alice boosts her own mon by +1
            "" // Bob does nothing
        );

        // Verify the stat was boosted further
        int32 furtherBoostedStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndex));
        assertEq(furtherBoostedStat, initialStat + 3, "Stat should be boosted by +3 total");

        // Verify no duplicate effect was added
        (effects,) = engine.getEffects(battleKey, 0, 0);
        assertEq(effects.length, effectCount, "No duplicate effect should be added");

        // 3. Apply a debuff (-2) to the same stat
        console.log("3. Applying -2 debuff to Alice's mon");

        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            0, // Alice uses stat boost move
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(0, 0, statIndex, int32(-2)), // Alice debuffs her own mon by -2
            "" // Bob does nothing
        );

        // Verify the stat was debuffed
        int32 debuffedStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndex));
        assertEq(debuffedStat, initialStat + 1, "Stat should be at +1 after debuff");

        // Verify no duplicate effect was added
        (effects,) = engine.getEffects(battleKey, 0, 0);
        assertEq(effects.length, effectCount, "No duplicate effect should be added");

        // 4. Switch out the mon
        console.log("4. Switching out Alice's mon");

        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            SWITCH_MOVE_INDEX, // Alice switches
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(1), // Alice switches to mon 1
            "" // Bob does nothing
        );

        // Verify the effect was removed
        (effects,) = engine.getEffects(battleKey, 0, 1);
        foundEffect = false;
        for (uint256 i = 0; i < effects.length; i++) {
            if (keccak256(abi.encodePacked(effects[i].name())) == keccak256(abi.encodePacked("StatBoost"))) {
                foundEffect = true;
                break;
            }
        }
        assertFalse(foundEffect, "StatBoost effect should be removed after switching out");

        // 5. Switch back to the original mon and verify stat is reset
        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            SWITCH_MOVE_INDEX, // Alice switches
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(0), // Alice switches back to mon 0
            "" // Bob does nothing
        );

        // Verify the stat was reset
        int32 resetStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndex));
        assertEq(resetStat, initialStat, "Stat should be reset after switching out and back in");
    }

    function getStatName(uint256 statIndex) internal pure returns (string memory) {
        if (statIndex == uint256(MonStateIndexName.Attack)) return "Attack";
        if (statIndex == uint256(MonStateIndexName.Defense)) return "Defense";
        if (statIndex == uint256(MonStateIndexName.SpecialAttack)) return "Special Attack";
        if (statIndex == uint256(MonStateIndexName.SpecialDefense)) return "Special Defense";
        if (statIndex == uint256(MonStateIndexName.Speed)) return "Speed";
        return "Unknown";
    }

    function test_allStatBoosts() public {
        // Create teams with two mons each
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = statBoostMove; // Stat boost move (we'll pass different params when using it)

        Mon memory mon1 = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 100,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon memory mon2 = Mon({
            stats: MonStats({
                hp: 100,
                stamina: 100,
                speed: 10,
                attack: 10,
                defense: 10,
                specialAttack: 10,
                specialDefense: 10,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory aliceTeam = new Mon[](2);
        aliceTeam[0] = mon1;
        aliceTeam[1] = mon2;

        Mon[] memory bobTeam = new Mon[](2);
        bobTeam[0] = mon1;
        bobTeam[1] = mon2;

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

        // Test all stats
        uint256[] memory statIndices = new uint256[](5);
        statIndices[0] = uint256(MonStateIndexName.Attack);
        statIndices[1] = uint256(MonStateIndexName.Defense);
        statIndices[2] = uint256(MonStateIndexName.SpecialAttack);
        statIndices[3] = uint256(MonStateIndexName.SpecialDefense);
        statIndices[4] = uint256(MonStateIndexName.Speed);

        for (uint256 i = 0; i < statIndices.length; i++) {
            // Apply a boost to each stat
            _commitRevealExecuteForAliceAndBob(
                engine,
                commitManager,
                battleKey,
                0, // Alice uses stat boost move
                NO_OP_MOVE_INDEX, // Bob does nothing
                abi.encode(0, 0, statIndices[i], int32(2)), // Alice boosts her own mon by +2
                "" // Bob does nothing
            );

            // Verify the stat was boosted
            int32 boostedStat = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName(statIndices[i]));
            assertEq(boostedStat, 2, "Stat should be boosted by +2");

            // Verify the effect was added
            (IEffect[] memory statEffects,) = engine.getEffects(battleKey, 0, 0);
            bool foundStatEffect = false;
            for (uint256 j = 0; j < statEffects.length; j++) {
                if (keccak256(abi.encodePacked(statEffects[j].name())) == keccak256(abi.encodePacked(statBoost.name())))
                {
                    foundStatEffect = true;
                    break;
                }
            }
            assertTrue(foundStatEffect, "StatBoost effect should be added for each stat");
        }

        // Switch out and verify all effects are removed
        _commitRevealExecuteForAliceAndBob(
            engine,
            commitManager,
            battleKey,
            SWITCH_MOVE_INDEX, // Alice switches
            NO_OP_MOVE_INDEX, // Bob does nothing
            abi.encode(1), // Alice switches to mon 1
            "" // Bob does nothing
        );

        // Verify all effects were removed
        (IEffect[] memory effects,) = engine.getEffects(battleKey, 0, 1);
        for (uint256 i = 0; i < effects.length; i++) {
            assertFalse(
                keccak256(abi.encodePacked(effects[i].name())) == keccak256(abi.encodePacked(statBoost.name())),
                "No StatBoost effects should remain after switching out"
            );
        }
    }
}

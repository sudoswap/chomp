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
import {StatBoosts} from "../../src/effects/StatBoosts.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";
import {TypeCalculator} from "../../src/types/TypeCalculator.sol";
import {BattleHelper} from "../abstract/BattleHelper.sol";
import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";
import {StandardAttack} from "../../src/moves/StandardAttack.sol";
import {StandardAttackFactory} from "../../src/moves/StandardAttackFactory.sol";
import {ATTACK_PARAMS} from "../../src/moves/StandardAttackStructs.sol";

import {Interweaving} from "../../src/mons/inutia/Interweaving.sol";
import {ShrineStrike} from "../../src/mons/inutia/ShrineStrike.sol";
import {Initialize} from "../../src/mons/inutia/Initialize.sol";
import {ChainExpansion} from "../../src/mons/inutia/ChainExpansion.sol";

contract InutiaTest is Test, BattleHelper {
    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    Interweaving interweaving;
    StatBoosts statBoost;
    StandardAttackFactory attackFactory;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));
        statBoost = new StatBoosts(IEngine(address(engine)));
        interweaving = new Interweaving(IEngine(address(engine)), statBoost);
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

        FastValidator validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 0, TIMEOUT_DURATION: 10})
        );

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

    function test_shrineStrike() public {
        ShrineStrike shrineStrike = new ShrineStrike(IEngine(address(engine)), ITypeCalculator(address(typeCalc)));

        // Create a validator with 1 mon and 1 move per mon
        FastValidator oneMonOneMove = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: 10})
        );

        // Create a StandardAttack that deals significant damage
        uint256 hpScale = 1024; // Large HP amount as requested
        int32 healDenom = shrineStrike.HEAL_DENOM();

        // Create a damage-dealing attack that will do at least hpScale/healDenom damage
        StandardAttack damageAttack = attackFactory.createAttack(
            ATTACK_PARAMS({
                BASE_POWER: uint32(hpScale / 4), // Ensure it deals enough damage
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Fire,
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 0,
                VOLATILITY: 0,
                NAME: "Damage Attack",
                EFFECT: IEffect(address(0))
            })
        );

        // Create mons with ShrineStrike and the damage attack
        IMoveSet[] memory aliceMoves = new IMoveSet[](1);
        aliceMoves[0] = shrineStrike;

        IMoveSet[] memory bobMoves = new IMoveSet[](1);
        bobMoves[0] = damageAttack;

        // Create mons with large HP and minimal other stats
        Mon memory aliceMon = Mon({
            stats: MonStats({
                hp: uint32(hpScale),
                stamina: 10,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: aliceMoves,
            ability: IAbility(address(0))
        });

        Mon memory bobMon = Mon({
            stats: MonStats({
                hp: uint32(hpScale),
                stamina: 10,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: bobMoves,
            ability: IAbility(address(0))
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
            validator: oneMonOneMove,
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

        // First move: Both players select their mons
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Second move: Bob attacks Alice, Alice does nothing
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, NO_OP_MOVE_INDEX, 0, "", ""
        );

        // Record Alice's HP after taking damage
        int32 aliceHpAfterDamage = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp);

        // Third move: Alice uses ShrineStrike, Bob does nothing
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, 0, NO_OP_MOVE_INDEX, "", ""
        );

        // Check that Alice's mon was healed by the correct amount (1/HEAL_DENOM of max HP)
        int32 aliceHpAfterHealing = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Hp);
        int32 expectedHealAmount = int32(int256(hpScale)) / healDenom;
        int32 actualHealAmount = aliceHpAfterHealing - aliceHpAfterDamage;

        assertEq(actualHealAmount, expectedHealAmount, "ShrineStrike should heal for 1/HEAL_DENOM of max HP");
    }

    function test_initialize() public {
        Initialize initialize = new Initialize(engine, statBoost);

        // Create a validator with 2 mons and 1 move per mon
        FastValidator validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 1, TIMEOUT_DURATION: 10})
        );

        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = initialize;

         // Create mon with initialize
        Mon memory initializeMon = Mon({
            stats: MonStats({
                hp: 1,
                stamina: 10,
                speed: 1,
                attack: 64,
                defense: 1,
                specialAttack: 128,
                specialDefense: 1,
                type1: Type.Water,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](2);
        team[0] = initializeMon;
        team[1] = initializeMon;

        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        bytes32 battleKey = _startBattle(validator, engine, mockOracle, defaultRegistry);

        // Send in mons
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both players select move index 0
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, 0, 0, "", "");

        // Assert both mons have a sp atk / atk buff of 64 (half of 128) and 32 (half of 64)
        int32 aliceSpAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);
        int32 aliceAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Attack);
        int32 bobSpAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialAttack);
        int32 bobAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Attack);
        assertEq(aliceSpAtk, 64);
        assertEq(bobSpAtk, 64);
        assertEq(aliceAtk, 32);
        assertEq(bobAtk, 32);

        // Both players select move index 0 again (nothing should happen)
        aliceSpAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);
        aliceAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Attack);
        bobSpAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialAttack);
        bobAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Attack);
        assertEq(aliceSpAtk, 64);
        assertEq(bobSpAtk, 64);
        assertEq(aliceAtk, 32);
        assertEq(bobAtk, 32);

        // Now both players swap to mon index 1
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(1), abi.encode(1)
        );

        // The stat boost should carry over
        aliceSpAtk = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.SpecialAttack);
        aliceAtk = engine.getMonStateForBattle(battleKey, 0, 1, MonStateIndexName.Attack);
        bobSpAtk = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.SpecialAttack);
        bobAtk = engine.getMonStateForBattle(battleKey, 1, 1, MonStateIndexName.Attack);
        assertEq(aliceSpAtk, 64);
        assertEq(bobSpAtk, 64);
        assertEq(aliceAtk, 32);
        assertEq(bobAtk, 32);

        // Now both players swap back to mon index 0
        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Both players select move index 0
        _commitRevealExecuteForAliceAndBob(engine, commitManager, battleKey, 0, 0, "", "");

        // It should do something again, as the global effect is cleared
        aliceSpAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.SpecialAttack);
        aliceAtk = engine.getMonStateForBattle(battleKey, 0, 0, MonStateIndexName.Attack);
        bobSpAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.SpecialAttack);
        bobAtk = engine.getMonStateForBattle(battleKey, 1, 0, MonStateIndexName.Attack);
        assertEq(aliceSpAtk, 64);
        assertEq(bobSpAtk, 64);
        assertEq(aliceAtk, 32);
        assertEq(bobAtk, 32);
    }

    function test_chainExpansion() public {
        TypeCalculator tc = new TypeCalculator();
        ChainExpansion ce = new ChainExpansion(engine, tc);
        FastValidator v = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 3, MOVES_PER_MON: 2, TIMEOUT_DURATION: 10})
        );

        IMoveSet[] memory moves = new IMoveSet[](2);
        moves[0] = ce;
        moves[1] = attackFactory.createAttack(ATTACK_PARAMS({
            BASE_POWER: 64,
            STAMINA_COST: 0,
            ACCURACY: 100,
            PRIORITY: 1,
            MOVE_TYPE: Type.Fire,
            EFFECT_ACCURACY: 0,
            MOVE_CLASS: MoveClass.Physical,
            CRIT_RATE: 0,
            VOLATILITY: 0,
            NAME: "Damage Attack",
            EFFECT: IEffect(address(0))
        }));

        // 1/8 damage
        Mon memory m1 = Mon({
            stats: MonStats({
                hp: 1024,
                stamina: 10,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Metal,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // 1/16 damage
        Mon memory m2 = Mon({
            stats: MonStats({
                hp: 1024,
                stamina: 10,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Nature,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        // 1/4 damage
        Mon memory m3 = Mon({
            stats: MonStats({
                hp: 1024,
                stamina: 10,
                speed: 1,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Yang,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(0))
        });

        Mon[] memory team = new Mon[](3);
        team[0] = m1;
        team[1] = m2;
        team[2] = m3;

        defaultRegistry.setTeam(ALICE, team);
        defaultRegistry.setTeam(BOB, team);

        bytes32 battleKey = _startBattle(v, engine, mockOracle, defaultRegistry);

        _commitRevealExecuteForAliceAndBob(
            engine, commitManager, battleKey, SWITCH_MOVE_INDEX, SWITCH_MOVE_INDEX, abi.encode(0), abi.encode(0)
        );

        // Using Chain Expansion twice will not lead to two global effects

        // Test the damage
        // Test the heal
        // Test the duration
    }
}

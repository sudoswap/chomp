// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/moves/StandardAttack.sol";
import "../src/moves/StandardAttackFactory.sol";
import "../src/Engine.sol";
import "../src/types/TypeCalculator.sol";
import "../src/effects/IEffect.sol";
import "../src/Enums.sol";

contract StandardAttackFactoryTest is Test {
    StandardAttack public template;
    StandardAttackFactory public factory;
    Engine public engine;
    TypeCalculator public typeCalc;
    bytes32 constant TEST_BATTLE_KEY = bytes32(uint256(1));

    function setUp() public {
        engine = new Engine();
        typeCalc = new TypeCalculator();
        template = new StandardAttack(engine, typeCalc);
        factory = new StandardAttackFactory(template);
    }

    function test_CreateAttackWithAllParameters() public {
        // Define test parameters
        uint64 basePower = 80;
        uint64 staminaCost = 2;
        uint64 accuracy = 95;
        uint64 priority = 3;
        Type moveType = Type.Fire;
        uint64 effectAccuracy = 100;
        MoveClass moveClass = MoveClass.Physical;
        uint64 critRate = 10;
        uint64 volatility = 5;
        bytes32 name = bytes32("Flame Strike");
        IEffect effect = IEffect(address(0x123)); // Mock effect address

        // Create attack using factory
        StandardAttack attack = factory.createAttack(
            StandardAttackFactory.ATTACK_PARAMS({
                BASE_POWER: basePower,
                STAMINA_COST: staminaCost,
                ACCURACY: accuracy,
                PRIORITY: priority,
                MOVE_TYPE: moveType,
                EFFECT_ACCURACY: effectAccuracy,
                MOVE_CLASS: moveClass,
                CRIT_RATE: critRate,
                VOLATILITY: volatility,
                NAME: name,
                EFFECT: effect
            })
        );

        // Verify all parameters were set correctly using the actual function names
        assertEq(attack.basePower(TEST_BATTLE_KEY), basePower, "Base power mismatch");
        assertEq(attack.stamina(TEST_BATTLE_KEY), staminaCost, "Stamina cost mismatch");
        assertEq(uint32(attack.moveType(TEST_BATTLE_KEY)), uint32(moveType), "Move type mismatch");
        assertEq(attack.priority(TEST_BATTLE_KEY), priority, "Priority mismatch");
        assertEq(attack.effectAccuracy(TEST_BATTLE_KEY), effectAccuracy, "Effect accuracy mismatch");
        assertEq(uint32(attack.moveClass(TEST_BATTLE_KEY)), uint32(moveClass), "Move class mismatch");
        assertEq(attack.critRate(TEST_BATTLE_KEY), critRate, "Crit rate mismatch");
        assertEq(attack.volatility(TEST_BATTLE_KEY), volatility, "Volatility mismatch");
        assertEq(address(attack.effect(TEST_BATTLE_KEY)), address(effect), "Effect address mismatch");
        assertEq(bytes32(abi.encodePacked(attack.name())), name, "Name mismatch");
    }

    function test_CreateAttackEmitsEvent() public {
        // Create basic attack parameters
        StandardAttackFactory.ATTACK_PARAMS memory params = StandardAttackFactory.ATTACK_PARAMS({
            BASE_POWER: 1,
            STAMINA_COST: 1,
            ACCURACY: 100,
            PRIORITY: 0,
            MOVE_TYPE: Type.Fire,
            EFFECT_ACCURACY: 100,
            MOVE_CLASS: MoveClass.Physical,
            CRIT_RATE: 0,
            VOLATILITY: 0,
            NAME: bytes32("Test Attack"),
            EFFECT: IEffect(address(0))
        });

        // Expect the StandardAttackCreated event to be emitted
        vm.expectEmit(true, false, false, false);
        emit StandardAttackFactory.StandardAttackCreated(address(0)); // address will be different but we only check first topic

        // Create the attack
        factory.createAttack(params);
    }

    function test_CreateMultipleAttacks() public {
        // Create first attack
        StandardAttack attack1 = factory.createAttack(
            StandardAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 80,
                STAMINA_COST: 2,
                ACCURACY: 95,
                PRIORITY: 3,
                MOVE_TYPE: Type.Fire,
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Physical,
                CRIT_RATE: 10,
                VOLATILITY: 5,
                NAME: bytes32("Fire Attack"),
                EFFECT: IEffect(address(0))
            })
        );

        // Create second attack with different parameters
        StandardAttack attack2 = factory.createAttack(
            StandardAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 60,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Water,
                EFFECT_ACCURACY: 50,
                MOVE_CLASS: MoveClass.Special,
                CRIT_RATE: 15,
                VOLATILITY: 3,
                NAME: bytes32("Water Attack"),
                EFFECT: IEffect(address(0))
            })
        );

        // Verify attacks are different and have correct parameters
        assertFalse(address(attack1) == address(attack2), "Attacks should have different addresses");
        assertEq(attack1.basePower(TEST_BATTLE_KEY), 80, "Attack1 base power mismatch");
        assertEq(attack2.basePower(TEST_BATTLE_KEY), 60, "Attack2 base power mismatch");
        assertEq(uint32(attack1.moveType(TEST_BATTLE_KEY)), uint32(Type.Fire), "Attack1 type mismatch");
        assertEq(uint32(attack2.moveType(TEST_BATTLE_KEY)), uint32(Type.Water), "Attack2 type mismatch");
    }
}

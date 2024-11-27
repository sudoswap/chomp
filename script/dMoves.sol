// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/Enums.sol";

import {Engine} from "../src/Engine.sol";
import {IEffect} from "../src/effects/IEffect.sol";
import {CustomEffectAttack} from "../src/moves/CustomEffectAttack.sol";
import {CustomEffectAttackFactory} from "../src/moves/CustomEffectAttackFactory.sol";

contract dMoves is Script {
    struct NameAndAttack {
        string name;
        CustomEffectAttack attack;
    }

    function run() external returns (NameAndAttack[] memory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        string[] memory names = new string[](9);
        address attackFactoryAddress = vm.envAddress("CUSTOM_EFFECT_ATTACK_FACTORY");
        CustomEffectAttackFactory attackFactory = CustomEffectAttackFactory(attackFactoryAddress);

        // Normal stamina/priority attack
        names[0] = "Blow";
        CustomEffectAttack attack0 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 80,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Air,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: stringToBytes32(names[0])
            })
        );

        // Normal priority, higher stamina, strong attack
        names[1] = "Philosophize";
        CustomEffectAttack attack1 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 120,
                STAMINA_COST: 3,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Cosmic,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Special,
                NAME: stringToBytes32(names[1])
            })
        );

        // Low priority, normal stamina attack + inflict status
        names[2] = "Spook";
        CustomEffectAttack attack2 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 30,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 2,
                MOVE_TYPE: Type.Yang,
                EFFECT: IEffect(vm.envAddress("FRIGHT_STATUS")),
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Special,
                NAME: stringToBytes32(names[2])
            })
        );

        // Low priority, high stamina, inflict status
        names[3] = "Sleep";
        CustomEffectAttack attack3 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 0,
                STAMINA_COST: 3,
                ACCURACY: 100,
                PRIORITY: 2,
                MOVE_TYPE: Type.Yin,
                EFFECT: IEffect(vm.envAddress("SLEEP_STATUS")),
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Other,
                NAME: stringToBytes32(names[3])
            })
        );

        // Normal priority, high stamina, damage + inflict status
        names[4] = "Chill Out";
        CustomEffectAttack attack4 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 50,
                STAMINA_COST: 3,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Ice,
                EFFECT: IEffect(vm.envAddress("FROSTBITE_STATUS")),
                EFFECT_ACCURACY: 100,
                MOVE_CLASS: MoveClass.Special,
                NAME: stringToBytes32(names[4])
            })
        );

        // High priority, normal stamina, damage
        names[5] = "Spark";
        CustomEffectAttack attack5 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 50,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 4,
                MOVE_TYPE: Type.Lightning,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: stringToBytes32(names[5])
            })
        );

        // Normal priority, normal stamina, damage
        names[6] = "Throw Rock";
        CustomEffectAttack attack6 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 100,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Earth,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: stringToBytes32(names[6])
            })
        );

        // Normal priority, normal stamina, high damage
        names[7] = "Allergies";
        CustomEffectAttack attack7 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 90,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Nature,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: stringToBytes32(names[7])
            })
        );

        // Normal priority, normal stamina, high damage
        names[8] = "Ineffable Blast";
        CustomEffectAttack attack8 = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: 80,
                STAMINA_COST: 2,
                ACCURACY: 100,
                PRIORITY: 3,
                MOVE_TYPE: Type.Mythic,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Special,
                NAME: stringToBytes32(names[8])
            })
        );

        NameAndAttack[] memory attackAndNames = new NameAndAttack[](9);

        attackAndNames[0] = NameAndAttack({name: names[0], attack: attack0});
        attackAndNames[1] = NameAndAttack({name: names[1], attack: attack1});
        attackAndNames[2] = NameAndAttack({name: names[2], attack: attack2});
        attackAndNames[3] = NameAndAttack({name: names[3], attack: attack3});
        attackAndNames[4] = NameAndAttack({name: names[4], attack: attack4});
        attackAndNames[5] = NameAndAttack({name: names[5], attack: attack5});
        attackAndNames[6] = NameAndAttack({name: names[6], attack: attack6});
        attackAndNames[7] = NameAndAttack({name: names[7], attack: attack7});
        attackAndNames[8] = NameAndAttack({name: names[8], attack: attack8});

        vm.stopBroadcast();
        return attackAndNames;
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}

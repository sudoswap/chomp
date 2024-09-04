// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IEffect} from "../IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IStatusEffect} from "./IStatusEffect.sol";

contract FrostbiteStatus is IStatusEffect {

    uint32 constant DAMAGE_DENOMINATOR = 16;
    uint32 constant SP_ATTACK_DENOMINATOR = 2;

    constructor(IEngine engine) IStatusEffect(engine) {}

    function name() public pure override returns (string memory) {
        return "Frostbite";
    }

    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return (r == EffectStep.OnApply || r == EffectStep.RoundEnd || r == EffectStep.OnRemove);
    }

    function onApply(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external override
        returns (bytes memory updatedExtraData) {
        
        // Get the special attack of the affected mon
        uint32 baseSpecialAttack = ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.specialAttack;

        // Reduce special attack by half
        int32 specialAttackAmountToReduce = int32(baseSpecialAttack / SP_ATTACK_DENOMINATOR) * -1;

        // Reduce special attack
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.SpecialAttack, specialAttackAmountToReduce);

        // Do not update data
        return (extraData);
    }

    function onRemove(bytes memory, uint256 targetIndex, uint256 monIndex) external override {
        // Reset the special attack reduction

        // Get the special attack of the affected mon
        uint32 baseSpecialAttack = ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.specialAttack;

        // Reduce special attack by half
        int32 specialAttackAmountToIncrease = int32(baseSpecialAttack / SP_ATTACK_DENOMINATOR);

        // Reduce special attack
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.SpecialAttack, specialAttackAmountToIncrease);
    }

    function onRoundEnd(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external override
        returns (bytes memory, bool) {
        
        // Get the max health of the affected mon
        uint32 maxHealth = ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.hp;

        // Calculate damage
        uint32 damage = maxHealth / DAMAGE_DENOMINATOR;

        // Deal the damage
        ENGINE.dealDamage(targetIndex, monIndex, damage);

        // Do not update data
        return (extraData, false);
    }
}
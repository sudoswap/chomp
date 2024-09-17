// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IEffect} from "../IEffect.sol";

import {StatusEffect} from "./StatusEffect.sol";

contract FrostbiteStatus is StatusEffect {
    uint32 constant DAMAGE_DENOMINATOR = 16;
    uint32 constant SP_ATTACK_DENOMINATOR = 2;

    constructor(IEngine engine) StatusEffect(engine) {}

    function name() public pure override returns (string memory) {
        return "Frostbite";
    }

    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return (r == EffectStep.OnApply || r == EffectStep.RoundEnd || r == EffectStep.OnRemove);
    }

    function onApply(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData)
    {
        // Get the special attack of the affected mon
        uint32 baseSpecialAttack =
            ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.specialAttack;

        // Reduce special attack by half
        int32 specialAttackAmountToReduce = int32(baseSpecialAttack / SP_ATTACK_DENOMINATOR) * -1;

        // Reduce special attack
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.SpecialAttack, specialAttackAmountToReduce);

        // Do not update data
        return (extraData);
    }

    function onRemove(bytes memory data, uint256 targetIndex, uint256 monIndex) public override {
        super.onRemove(data, targetIndex, monIndex);

        // Reset the special attack reduction

        // Get the special attack of the affected mon
        uint32 baseSpecialAttack =
            ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.specialAttack;

        // Reduce special attack by half
        int32 specialAttackAmountToIncrease = int32(baseSpecialAttack / SP_ATTACK_DENOMINATOR);

        // Reduce special attack
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.SpecialAttack, specialAttackAmountToIncrease);
    }

    function onRoundEnd(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        public
        override
        returns (bytes memory, bool)
    {
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

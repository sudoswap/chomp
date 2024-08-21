// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {ITypeCalculator} from "../types/ITypeCalculator.sol";

abstract contract AttackCalculator {
    uint256 constant MOVE_VARIANCE = 0;

    IEngine immutable ENGINE;
    ITypeCalculator immutable TYPE_CALCULATOR;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR) {
        ENGINE = _ENGINE;
        TYPE_CALCULATOR = _TYPE_CALCULATOR;
    }

    function calculateDamage(
        bytes32 battleKey,
        uint256 attackerPlayerIndex,
        uint32 basePower,
        uint32 accuracy, // out of 100
        uint256,
        Type attackType,
        AttackSupertype attackSupertype,
        uint256 rng
    ) public {
        BattleState memory state = ENGINE.getBattleState(battleKey);

        // Do accuracy check first to decide whether or not to short circuit
        if ((rng % 100) >= accuracy) {
            return;
        }

        uint32 damage;
        Mon memory defenderMon;
        uint256 defenderPlayerIndex = (attackerPlayerIndex + 1) % 2;

        {
            uint32 attackStat;
            uint32 defenceStat;

            Mon memory attackerMon =
                (ENGINE.getBattle(battleKey)).teams[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]];
            MonState memory attackerMonState =
                state.monStates[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]];
            defenderMon =
                (ENGINE.getBattle(battleKey)).teams[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]];
            MonState memory defenderMonState =
                state.monStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]];

            // Grab the right atk/defense stats, and apply the delta if needed
            if (attackSupertype == AttackSupertype.Physical) {
                attackStat = uint32(int32(attackerMon.attack) + attackerMonState.attackDelta);
                defenceStat = uint32(int32(defenderMon.defence) + defenderMonState.defenceDelta);
            } else {
                attackStat = uint32(int32(attackerMon.specialAttack) + attackerMonState.specialAttackDelta);
                defenceStat = uint32(int32(defenderMon.specialDefence) + defenderMonState.specialDefenceDelta);
            }

            uint32 typeMultiplier = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.type1);
            if (defenderMon.type2 != Type.None) {
                uint32 secondaryTypeMultiplier = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.type2);
                typeMultiplier = typeMultiplier * secondaryTypeMultiplier;
            }

            uint32 rngScaling = 0;
            if (MOVE_VARIANCE > 0) {
                rngScaling = uint32(rng % (MOVE_VARIANCE + 1));
            }

            damage = (basePower * attackStat * (100 - rngScaling) * typeMultiplier) / (defenceStat * 100);
        }

        // Do damage calc and check for KO on defending mon
        ENGINE.updateMonState(
            defenderPlayerIndex, state.activeMonIndex[defenderPlayerIndex], MonStateIndexName.Hp, -1 * int32(damage)
        );

        // Check for KO and set if so on defending mon
        int32 newTotalHealth = int32(defenderMon.hp)
            + state.monStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]].hpDelta - int32(damage);
        if (newTotalHealth <= 0) {
            ENGINE.updateMonState(
                defenderPlayerIndex, state.activeMonIndex[defenderPlayerIndex], MonStateIndexName.IsKnockedOut, 1
            );
        }
    }
}

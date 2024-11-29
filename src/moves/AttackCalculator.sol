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
        MoveClass attackSupertype,
        uint256 rng
    ) public {
        BattleState memory state = ENGINE.getBattleState(battleKey);

        // Do accuracy check first to decide whether or not to short circuit
        if ((rng % 100) >= accuracy) {
            return;
        }
        uint256[] memory monIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);
        uint32 damage;
        uint256 defenderPlayerIndex = (attackerPlayerIndex + 1) % 2;

        {
            uint32 attackStat;
            uint32 defenceStat;

            MonState memory attackerMonState =
                state.monStates[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]];
            MonState memory defenderMonState =
                state.monStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]];

            // Grab the right atk/defense stats, and apply the delta if needed
            if (attackSupertype == MoveClass.Physical) {
                attackStat = uint32(int32(
                    ENGINE.getMonValueForBattle(battleKey, attackerPlayerIndex, monIndex[attackerPlayerIndex], MonStateIndexName.Attack)
                ) + attackerMonState.attackDelta);
                defenceStat = uint32(int32(
                    ENGINE.getMonValueForBattle(battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Defense)
                ) + defenderMonState.defenceDelta);
            } else {
                attackStat = uint32(int32(
                    ENGINE.getMonValueForBattle(battleKey, attackerPlayerIndex, monIndex[attackerPlayerIndex], MonStateIndexName.SpecialAttack)
                ) + attackerMonState.specialAttackDelta);
                defenceStat = uint32(int32(
                    ENGINE.getMonValueForBattle(battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.SpecialDefense)
                ) + defenderMonState.specialDefenceDelta);
            }

            uint32 scaledBasePower =
                TYPE_CALCULATOR.getTypeEffectiveness(attackType, 
                Type(ENGINE.getMonValueForBattle(battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Type1)), basePower);
            Type defenderType2 = Type(ENGINE.getMonValueForBattle(battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Type2));
            if (defenderType2 != Type.None) {
                scaledBasePower =
                    TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderType2, scaledBasePower);
            }

            uint32 rngScaling = 0;
            if (MOVE_VARIANCE > 0) {
                rngScaling = uint32(rng % (MOVE_VARIANCE + 1));
            }
            damage = (scaledBasePower * attackStat * (100 - rngScaling)) / (defenceStat * 100);
        }
        ENGINE.dealDamage(defenderPlayerIndex, state.activeMonIndex[defenderPlayerIndex], damage);
    }
}

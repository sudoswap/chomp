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
    ) public view returns (int32) {
        BattleState memory state = ENGINE.getBattleState(battleKey);

        // Do accuracy check first to decide whether or not to short circuit
        if ((rng % 100) >= accuracy) {
            return 0;
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
                attackStat = uint32(int32(attackerMon.stats.attack) + attackerMonState.attackDelta);
                defenceStat = uint32(int32(defenderMon.stats.defence) + defenderMonState.defenceDelta);
            } else {
                attackStat = uint32(int32(attackerMon.stats.specialAttack) + attackerMonState.specialAttackDelta);
                defenceStat = uint32(int32(defenderMon.stats.specialDefence) + defenderMonState.specialDefenceDelta);
            }

            uint32 typeMultiplier = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.stats.type1);
            if (defenderMon.stats.type2 != Type.None) {
                uint32 secondaryTypeMultiplier =
                    TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.stats.type2);
                typeMultiplier = typeMultiplier * secondaryTypeMultiplier;
            }

            uint32 rngScaling = 0;
            if (MOVE_VARIANCE > 0) {
                rngScaling = uint32(rng % (MOVE_VARIANCE + 1));
            }

            damage = (basePower * attackStat * (100 - rngScaling) * typeMultiplier) / (defenceStat * 100);
        }

        return int32(damage);
    }
}

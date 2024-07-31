// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

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
        uint256 basePower,
        uint256 accuracy, // out of 100
        uint256 staminaCost,
        Type attackType,
        AttackSupertype attackSupertype,
        uint256 rng
    ) public returns (MonState[][] memory, uint256[] memory, IEffect[][] memory, bytes[][] memory, bytes32, bytes32) {
        BattleState memory state = ENGINE.getBattleState(battleKey);
        IEffect[][] memory emptyEffects = new IEffect[][](0);
        bytes[][] memory emptyData = new bytes[][](0);

        // Do accuracy check first to decide whether or not to short circuit
        if ((rng % 100) >= accuracy) {
            return (state.monStates, state.activeMonIndex, emptyEffects, emptyData, "", "");
        }

        uint256 damage;
        Mon memory defenderMon;
        uint256 defenderPlayerIndex = (attackerPlayerIndex + 1) % 2;

        {
            uint256 attackStat;
            uint256 defenceStat;

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
                attackStat = uint256(int256(attackerMon.attack) + attackerMonState.attackDelta);
                defenceStat = uint256(int256(defenderMon.defence) + defenderMonState.defenceDelta);
            } else {
                attackStat = uint256(int256(attackerMon.specialAttack) + attackerMonState.specialAttackDelta);
                defenceStat = uint256(int256(defenderMon.specialDefence) + defenderMonState.specialDefenceDelta);
            }

            uint256 typeMultiplier = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.type1);
            if (defenderMon.type2 != Type.None) {
                uint256 secondaryTypeMultiplier = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderMon.type2);
                typeMultiplier = typeMultiplier * secondaryTypeMultiplier;
            }

            uint256 rngScaling = 0;
            if (MOVE_VARIANCE > 0) {
                rngScaling = rng % (MOVE_VARIANCE + 1);
            }

            damage = (basePower * attackStat * (100 - rngScaling) * typeMultiplier) / (defenceStat * 100);
        }

        // Update stamina delta for the attacker mon
        MonState[][] memory updatedStates = state.monStates;
        updatedStates[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]].staminaDelta -=
            int256(staminaCost);

        // Do damage calc and check for KO on defending mon
        updatedStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]].hpDelta -= int256(damage);

        if (
            updatedStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]].hpDelta
                + int256(defenderMon.hp) <= 0
        ) {
            updatedStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]].isKnockedOut = true;
        }

        return (updatedStates, state.activeMonIndex, emptyEffects, emptyData, "", "");
    }
}

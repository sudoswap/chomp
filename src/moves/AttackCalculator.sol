// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEngine} from "../IEngine.sol";

abstract contract AttackCalculator {

    uint256 constant MOVE_VARIANCE = 10;
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function calculateDamage(
        bytes32 battleKey,
        uint256 attackerPlayerIndex,
        uint256 basePower,
        uint256 accuracy, // out of 100
        AttackSupertype attackSupertype,
        uint256 rng
    ) public view returns (uint256) {
        BattleState memory state = ENGINE.getBattleState(battleKey);
        Mon memory attackerMon = (ENGINE.getBattle(battleKey)).teams[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]];
        MonState memory attackerMonState = state.monStates[attackerPlayerIndex][state.activeMonIndex[attackerPlayerIndex]];
        uint256 defenderPlayerIndex = attackerPlayerIndex + 1 % 2;
        Mon memory defenderMon = (ENGINE.getBattle(battleKey)).teams[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]];
        MonState memory defenderMonState = state.monStates[defenderPlayerIndex][state.activeMonIndex[defenderPlayerIndex]];
        uint256 attackStat;
        uint256 defenceStat;
        if (attackSupertype == AttackSupertype.Physical) {
            attackStat = uint256(int256(attackerMon.attack) + attackerMonState.attackDelta);
            defenceStat = uint256(int256(defenderMon.defence) + defenderMonState.defenceDelta);
        }
        else {
            attackStat = uint256(int256(attackerMon.specialAttack) + attackerMonState.specialAttackDelta);
            defenceStat = uint256(int256(defenderMon.specialDefence) + defenderMonState.specialDefenceDelta);
        }
        // TODO: handle move typings and STAB
        uint256 rngScaling = rng % MOVE_VARIANCE;
        uint256 damage = (basePower * attackStat * (100 - rngScaling)) / (defenceStat * 100);

        // Accuracy check
        uint256 accuracyCheck = rng % 100;
        if (accuracyCheck > accuracy) {
            damage = 0;
        }

        return damage;
    }
}

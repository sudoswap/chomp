// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {ITypeCalculator} from "../types/ITypeCalculator.sol";

abstract contract AttackCalculator {
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
        uint256 volatility,
        Type attackType,
        MoveClass attackSupertype,
        uint256 rng
    ) public {
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

            // Grab the right atk/defense stats, and apply the delta if needed
            if (attackSupertype == MoveClass.Physical) {
                attackStat = uint32(
                    int32(
                        ENGINE.getMonValueForBattle(
                            battleKey, attackerPlayerIndex, monIndex[attackerPlayerIndex], MonStateIndexName.Attack
                        )
                    )
                        + ENGINE.getMonStateForBattle(
                            battleKey, attackerPlayerIndex, monIndex[attackerPlayerIndex], MonStateIndexName.Attack
                        )
                );
                defenceStat = uint32(
                    int32(
                        ENGINE.getMonValueForBattle(
                            battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Defense
                        )
                    )
                        + ENGINE.getMonStateForBattle(
                            battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Defense
                        )
                );
            } else {
                attackStat = uint32(
                    int32(
                        ENGINE.getMonValueForBattle(
                            battleKey,
                            attackerPlayerIndex,
                            monIndex[attackerPlayerIndex],
                            MonStateIndexName.SpecialAttack
                        )
                    )
                        + ENGINE.getMonStateForBattle(
                            battleKey, attackerPlayerIndex, monIndex[attackerPlayerIndex], MonStateIndexName.SpecialAttack
                        )
                );
                defenceStat = uint32(
                    int32(
                        ENGINE.getMonValueForBattle(
                            battleKey,
                            defenderPlayerIndex,
                            monIndex[defenderPlayerIndex],
                            MonStateIndexName.SpecialDefense
                        )
                    )
                        + ENGINE.getMonStateForBattle(
                            battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.SpecialDefense
                        )
                );
            }
            uint32 scaledBasePower = TYPE_CALCULATOR.getTypeEffectiveness(
                attackType,
                Type(
                    ENGINE.getMonValueForBattle(
                        battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Type1
                    )
                ),
                basePower
            );
            Type defenderType2 = Type(
                ENGINE.getMonValueForBattle(
                    battleKey, defenderPlayerIndex, monIndex[defenderPlayerIndex], MonStateIndexName.Type2
                )
            );
            if (defenderType2 != Type.None) {
                scaledBasePower = TYPE_CALCULATOR.getTypeEffectiveness(attackType, defenderType2, scaledBasePower);
            }

            // Calculate move volatility
            // Check if rng flag is even or odd
            // Either way, take half the value use it as the scaling factor
            uint32 rngScaling = 100;
            if (volatility > 0) {
                if (rng % 2 == 0) {
                    rngScaling = 100 + rngScaling / 2;
                } else {
                    rngScaling = 100 - (rngScaling + 1) / 2;
                }
            }

            // Calculate crit chance

            damage = (scaledBasePower * attackStat * rngScaling) / (defenceStat * 100);
        }
        ENGINE.dealDamage(defenderPlayerIndex, monIndex[defenderPlayerIndex], damage);
    }
}

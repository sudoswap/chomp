// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Constants.sol";
import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";

import {IEffect} from "../effects/IEffect.sol";
import {Clone} from "../lib/Clone.sol";
import {ITypeCalculator} from "../types/ITypeCalculator.sol";
import {AttackCalculator} from "./AttackCalculator.sol";
import {IMoveSet} from "./IMoveSet.sol";

contract CustomEffectAttack is AttackCalculator, IMoveSet, Clone {
    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR) AttackCalculator(_ENGINE, _TYPE_CALCULATOR) {}

    /**
     * Args ordering (bytes):
     *  0: BASE_POWER
     *  32: STAMINA_COST
     *  64: ACCURACY
     *  96: PRIORITY
     *  128: TYPE
     *  160: EFFECT
     *  180: EFFECT_ACCURACY
     *  212: MOVE_CLASS
     *  244: NAME
     */
    function name() external pure returns (string memory) {
        return _bytes32ToString(bytes32(_getArgUint256(244)));
    }

    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng) external {
        // Deal the damage
        uint32 basePowerValue = uint32(_getArgUint256(0));
        uint32 accuracy = uint32(_getArgUint256(64));
        Type typeForMove = Type(_getArgUint256(128));
        MoveClass classForMove = MoveClass(_getArgUint256(212));

        if (basePowerValue > 0) {
            calculateDamage(
                battleKey,
                attackerPlayerIndex,
                basePowerValue,
                accuracy,
                0, /* volatility */
                typeForMove,
                classForMove,
                rng,
                0 /* crit rate */
            );
        }

        // Apply the effect as well if the accuracy is valid
        uint256 effectAccuracy = _getArgUint256(180);
        if (rng % 100 < effectAccuracy) {
            uint256 defenderPlayerIndex = (attackerPlayerIndex + 1) % 2;
            uint256 defenderMonIndex =
                ENGINE.getActiveMonIndexForBattleState(ENGINE.battleKeyForWrite())[defenderPlayerIndex];
            ENGINE.addEffect(defenderPlayerIndex, defenderMonIndex, IEffect(_getArgAddress(160)), "");
        }
    }

    function priority(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint256(96));
    }

    function stamina(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint256(32));
    }

    function moveType(bytes32) external pure returns (Type) {
        return Type(_getArgUint256(128));
    }

    function isValidTarget(bytes32, bytes calldata) external pure returns (bool) {
        return true;
    }

    function moveClass(bytes32) external pure returns (MoveClass) {
        return MoveClass(_getArgUint256(212));
    }

    function basePower(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint256(0));
    }
}

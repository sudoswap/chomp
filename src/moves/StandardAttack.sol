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

contract StandardAttack is AttackCalculator, IMoveSet, Clone {
    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR) AttackCalculator(_ENGINE, _TYPE_CALCULATOR) {}

    /**
     * Args ordering (bytes):
     *  0: BASE_POWER
     *  8: STAMINA_COST
     *  16: ACCURACY
     *  24: PRIORITY
     *  32: TYPE
     *  40: EFFECT_ACCURACY
     *  48: MOVE_CLASS
     *  56: CRIT_RATE
     *  64: VOL
     *  72: NAME (32 bytes from here)
     *  104: EFFECT (20 bytes from here)
     */
    function name() external pure returns (string memory) {
        return _bytes32ToString(bytes32(_getArgUint256(72)));
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

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng)
        external
        returns (bool)
    {
        // Deal the damage
        uint32 basePowerValue = uint32(_getArgUint64(0));
        uint32 accuracy = uint32(_getArgUint64(16));
        Type typeForMove = Type(_getArgUint64(32));
        MoveClass classForMove = MoveClass(_getArgUint64(48));

        if (basePowerValue > 0) {
            calculateDamage(
                battleKey, 
                attackerPlayerIndex, 
                basePowerValue, 
                accuracy, 
                uint32(_getArgUint64(64)), // volatility
                typeForMove, 
                classForMove, 
                rng
            );
        }

        // Apply the effect as well if the accuracy is valid
        uint256 effectAccuracy = _getArgUint64(40);
        if (rng % 100 < effectAccuracy) {
            uint256 defenderPlayerIndex = (attackerPlayerIndex + 1) % 2;
            uint256 defenderMonIndex =
                ENGINE.getActiveMonIndexForBattleState(ENGINE.battleKeyForWrite())[defenderPlayerIndex];
            ENGINE.addEffect(defenderPlayerIndex, defenderMonIndex, IEffect(_getArgAddress(104)), "");
        }

        return false;
    }

    function priority(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(24));
    }

    function stamina(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(8));
    }

    function moveType(bytes32) external pure returns (Type) {
        return Type(_getArgUint64(32));
    }

    function isValidTarget(bytes32) external pure returns (bool) {
        return true;
    }

    function postMoveSwitch(bytes32, uint256, bytes calldata) external pure returns (uint256, uint256) {
        // No-op
        return (NO_SWITCH_FLAG, NO_SWITCH_FLAG);
    }

    function moveClass(bytes32) external pure returns (MoveClass) {
        return MoveClass(_getArgUint64(48));
    }

    function basePower(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(0));
    }

    function critRate(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(56));
    }

    function volatility(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(64));
    }

    function effect(bytes32) external pure returns (IEffect) {
        return IEffect(_getArgAddress(104));
    }

    function effectAccuracy(bytes32) external pure returns (uint32) {
        return uint32(_getArgUint64(40));
    }
}

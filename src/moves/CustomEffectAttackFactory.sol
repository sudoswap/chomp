// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEffect} from "../effects/IEffect.sol";
import {ClonesWithImmutableArgs} from "../lib/ClonesWithImmutableArgs.sol";
import {CustomEffectAttack} from "./CustomEffectAttack.sol";

contract CustomEffectAttackFactory {
    using ClonesWithImmutableArgs for address;

    CustomEffectAttack public immutable TEMPLATE;

    event CustomEffectAttackCreated(address a);

    constructor(CustomEffectAttack template) {
        TEMPLATE = template;
    }

    /**
     * Args ordering:
     *     0: BASE_POWER
     *     32: STAMINA_COST
     *     64: ACCURACY
     *     96: PRIORITY
     *     128: TYPE
     *     160: EFFECT
     *     180: EFFECT_ACCURACY
     *     212: MOVE_CLASS
     */
    function createAttack(
        uint256 basePower,
        uint256 staminaCost,
        uint256 accuracy,
        uint256 priority,
        Type moveType,
        IEffect effect,
        uint256 effectAccuracy,
        MoveClass moveClass
    ) external returns (CustomEffectAttack clone) {
        bytes memory data = abi.encodePacked(
            basePower,
            staminaCost,
            accuracy,
            priority,
            uint256(moveType),
            address(effect),
            effectAccuracy,
            uint256(moveClass)
        );
        clone = CustomEffectAttack(address(TEMPLATE).clone(data));
        emit CustomEffectAttackCreated(address(clone));
    }
}

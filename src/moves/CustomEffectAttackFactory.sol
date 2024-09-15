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
     *     244: NAME
     */
    struct ATTACK_PARAMS {
        uint256 BASE_POWER;
        uint256 STAMINA_COST;
        uint256 ACCURACY;
        uint256 PRIORITY;
        Type MOVE_TYPE;
        IEffect EFFECT;
        uint256 EFFECT_ACCURACY;
        MoveClass MOVE_CLASS;
        bytes32 NAME;
    }

    function createAttack(ATTACK_PARAMS memory params) external returns (CustomEffectAttack clone) {
        bytes memory data = abi.encodePacked(
            params.BASE_POWER,
            params.STAMINA_COST,
            params.ACCURACY,
            params.PRIORITY,
            uint256(params.MOVE_TYPE),
            address(params.EFFECT),
            params.EFFECT_ACCURACY,
            uint256(params.MOVE_CLASS),
            params.NAME
        );
        clone = CustomEffectAttack(address(TEMPLATE).clone(data));
        emit CustomEffectAttackCreated(address(clone));
    }
}

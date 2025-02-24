// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEffect} from "../effects/IEffect.sol";
import {ClonesWithImmutableArgs} from "../lib/ClonesWithImmutableArgs.sol";
import {StandardAttack} from "./StandardAttack.sol";

contract StandardAttackFactory {
    using ClonesWithImmutableArgs for address;

    StandardAttack public immutable TEMPLATE;

    event StandardAttackCreated(address a);

    constructor(StandardAttack template) {
        TEMPLATE = template;
    }

    /**
     * Args ordering:
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
    struct ATTACK_PARAMS {
        uint64 BASE_POWER;
        uint64 STAMINA_COST;
        uint64 ACCURACY;
        uint64 PRIORITY;
        Type MOVE_TYPE;
        uint64 EFFECT_ACCURACY;
        MoveClass MOVE_CLASS;
        uint64 CRIT_RATE;
        uint64 VOLATILITY;
        bytes32 NAME;
        IEffect EFFECT;
    }

    function createAttack(ATTACK_PARAMS memory params) external returns (StandardAttack clone) {
        bytes memory data = abi.encodePacked(
            params.BASE_POWER,
            params.STAMINA_COST,
            params.ACCURACY,
            params.PRIORITY,
            uint64(params.MOVE_TYPE),
            params.EFFECT_ACCURACY,
            uint64(params.MOVE_CLASS),
            params.CRIT_RATE,
            params.VOLATILITY,
            params.NAME,
            address(params.EFFECT)
        );
        clone = StandardAttack(address(TEMPLATE).clone(data));
        emit StandardAttackCreated(address(clone));
    }
}
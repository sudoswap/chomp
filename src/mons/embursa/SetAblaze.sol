// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../Enums.sol";
import "../../Constants.sol";
import {IMoveSet} from "../../moves/IMoveSet.sol";
import {IEngine} from "../../IEngine.sol";
import {ITypeCalculator} from "../../types/ITypeCalculator.sol";
import {StandardAttack} from "../../moves/StandardAttack.sol";
import {ATTACK_PARAMS} from "../../moves/StandardAttackStructs.sol";
import {IEffect} from "../../effects/IEffect.sol";

contract SetAblaze is StandardAttack {

    constructor(IEngine ENGINE, ITypeCalculator TYPE_CALCULATOR, IEffect BURN_STATUS)
        StandardAttack(
            address(msg.sender),
            ENGINE,
            TYPE_CALCULATOR,
            ATTACK_PARAMS({
                NAME: "Set Ablaze",
                BASE_POWER: 90,
                STAMINA_COST: 3,
                ACCURACY: 100,
                MOVE_TYPE: Type.Fire,
                MOVE_CLASS: MoveClass.Special,
                PRIORITY: DEFAULT_PRIORITY,
                CRIT_RATE: DEFAULT_CRIT_RATE,
                VOLATILITY: DEFAULT_VOL,
                EFFECT_ACCURACY: 30,
                EFFECT: BURN_STATUS
            })
        )
    {}

}
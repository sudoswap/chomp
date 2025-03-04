// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import {IEffect} from "../effects/IEffect.sol";

struct ATTACK_PARAMS {
    uint32 BASE_POWER;
    uint32 STAMINA_COST;
    uint32 ACCURACY;
    uint32 PRIORITY;
    Type MOVE_TYPE;
    uint32 EFFECT_ACCURACY;
    MoveClass MOVE_CLASS;
    uint32 CRIT_RATE;
    uint32 VOLATILITY;
    string NAME;
    IEffect EFFECT;
}

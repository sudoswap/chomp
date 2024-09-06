// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {IEngine} from "../../src/IEngine.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

contract EffectAbility is IAbility {
    IEngine immutable ENGINE;
    IEffect immutable EFFECT;

    constructor(IEngine _ENGINE, IEffect _EFFECT) {
        ENGINE = _ENGINE;
        EFFECT = _EFFECT;
    }

    function name() external pure returns (string memory) {
        return "";
    }

    function activateOnSwitch(bytes32, uint256 playerIndex, uint256 monIndex) external {
        ENGINE.addEffect(playerIndex, monIndex, EFFECT, "");
    }
}

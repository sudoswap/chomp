// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";
import {IRuleset} from "./IRuleset.sol";

import {IEffect} from "./effects/IEffect.sol";

contract DefaultRuleset is IRuleset {
    IEngine immutable ENGINE;
    IEffect[] STAMINA_EFFECT;

    constructor(IEngine _ENGINE, IEffect _STAMINA_REGEN) {
        ENGINE = _ENGINE;
        STAMINA_EFFECT.push();
        STAMINA_EFFECT[0] = _STAMINA_REGEN;
    }

    function getInitialGlobalEffects() external view returns (IEffect[] memory, bytes[] memory) {
        bytes[] memory data = new bytes[](1);
        return (STAMINA_EFFECT, data);
    }
}

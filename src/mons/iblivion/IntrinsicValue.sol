// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {BasicEffect} from "../../effects/BasicEffect.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {StatBoost} from "../../effects/StatBoost.sol";

contract IntrinsicValue is IAbility, BasicEffect {

    IEngine immutable ENGINE;
    IEffect immutable STAT_BOOST;

    constructor(IEngine _ENGINE, IEffect _STAT_BOOST) {
        ENGINE = _ENGINE;
        STAT_BOOST = _STAT_BOOST;
    }

    function name() public pure override(IAbility, BasicEffect) returns (string memory) {
        return "Intrinsic Value";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external {
        // Check if the effect has already been set for this mon
        bytes32 monEffectId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monEffectId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon when it switches in
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monEffectId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), abi.encode(0));
        }
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep step) external pure override returns (bool) {
        return (step == EffectStep.RoundEnd);
    }

    function onRoundEnd(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Check for negative stat boosts in ATK/DEF/SpATK/SpDEF/SPD
        
    }
}
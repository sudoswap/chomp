// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";

import {MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IAbility} from "../../abilities/IAbility.sol";

import {BasicEffect} from "../../effects/BasicEffect.sol";
import {IEffect} from "../../effects/IEffect.sol";

contract CarrotHarvest is IAbility, BasicEffect {
    uint256 constant CHANCE = 2;

    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    // IAbility implementation
    function name() public pure override(IAbility, BasicEffect) returns (string memory) {
        return "Carrot Harvest";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external override {
        // Check if the effect has already been set for this mon
        bytes32 monEffectId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monEffectId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon when it switches in
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monEffectId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), "");
        }
    }

    // IEffect implementation
    function shouldRunAtStep(EffectStep step) external pure override returns (bool) {
        return step == EffectStep.RoundEnd;
    }

    // Regain stamina on round end, this can overheal stamina
    function onRoundEnd(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        if (rng % CHANCE == 1) {
            // Update the stamina of the mon
            ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Stamina, 1);
        }
        return (extraData, false);
    }
}

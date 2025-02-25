// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {MonStateIndexName} from "../../Enums.sol";

contract CarrotHarvest is IAbility, IEffect {
    uint256 constant CHANCE = 3;

    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    // IAbility implementation
    function name() public pure override(IAbility, IEffect) returns (string memory)  {
        return "Carrot Harvest";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external {
        // Check if the effect has already been set for this mon
        bytes32 monId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon when it switches in
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), "");
        }
    }

    // IEffect implementation
    function shouldRunAtStep(EffectStep step) external pure returns (bool) {
        return step == EffectStep.RoundEnd;
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    function onRoundStart(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for round start
        return (extraData, false);
    }

    function onRoundEnd(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        if (rng % CHANCE == 0) {
            // Update the stamina of the mon
            ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Stamina, 1);
        }
        return (extraData, false);
    }

    function onMonSwitchIn(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for when a mon switches in
        return (extraData, false);
    }

    function onMonSwitchOut(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for when a mon switches out
        return (extraData, false);
    }

    function onAfterDamage(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for after damage is dealt
        return (extraData, false);
    }

    function onApply(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData)
    {
        // Logic for when the effect is applied
        return extraData;
    }

    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external pure {
        // Logic for when the effect is removed
    }
}

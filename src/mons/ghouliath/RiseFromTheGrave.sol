// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {MonStateIndexName} from "../../Enums.sol";

contract RiseFromTheGrave is IAbility, IEffect {
    
    uint256 constant public REVIVAL_DELAY = 3;

    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    // IAbility implementation
    function name() public pure override(IAbility, IEffect) returns (string memory)  {
        return "Rise From The Grave";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external {
        // Check if the effect has already been set for this mon
        bytes32 monEffectId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monEffectId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon *AND* the battlefield when it switches in
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monEffectId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), "");
        }
    }

    // IEffect implementation
    function shouldRunAtStep(EffectStep step) external pure returns (bool) {
        return (step == EffectStep.RoundEnd || step == EffectStep.AfterDamage);
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    function onAfterDamage(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex, int32 damageDealt)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        /*
        On damage, if the mon is KO'd, add this effect to the global effects list (so we can hook into onRoundEnd)
        and remove this effect (so we stop hooking into it on future applications)
        */
        if (damageDealt < 0) {
            // If the mon is KO'd, add this effect to the global effects list and remove the mon effect
            if (ENGINE.getMonStateForBattle(ENGINE.battleKeyForWrite(), targetIndex, monIndex, MonStateIndexName.IsKnockedOut) == 1) {
                ENGINE.addEffect(targetIndex, monIndex, IEffect(address(this)), abi.encode(REVIVAL_DELAY));
                return (extraData, true);
            }
        }
        return (extraData, false);
    }

    // Regain stamina on round end, this can overheal stamina
    function onRoundEnd(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        uint256 turnsLeft = abi.decode(extraData, (uint256));
        if (turnsLeft == 1) {
            // Revive the mon and remove the effect
            ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.IsKnockedOut, 0);
            return (extraData, true);
        }
        else {
            return (abi.encode(turnsLeft - 1), false);
        }
    }


    function onRoundStart(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for round start
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
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {BasicEffect} from "./BasicEffect.sol";

contract StatBoost is BasicEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    /**
     * Can only be applied once per mon
     * If a mon switches out, clear the effect
     * Maintain a global kv for player index / mon index / stat index
     */
    function name() public pure override returns (string memory) {
        return "StatBoost";
    }

    // Should run at end of round and on apply
    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return (r == EffectStep.OnMonSwitchOut || r == EffectStep.OnApply || r == EffectStep.OnRemove);
    }

    function onApply(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory, bool)
    {
        // Check if an existing stat boost for the mon / stat index already exists
        (uint256 statIndex, int32 newBoostAmount) = abi.decode(extraData, (uint256, int32));
        bytes32 keyForMon = keccak256(abi.encode(targetIndex, monIndex, statIndex, name()));
        int32 existingBoostAmount = int32(int256(uint256(ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), keyForMon))));

        // Compute the new total boost
        int32 totalBoostAmount = existingBoostAmount + newBoostAmount;

        // If the old value was 0, and the new total is non-zero, then we should add the boost to the effects array
        // (ie we don't remove the effect after onApply)
        bool removeAfterRun = true;
        if (existingBoostAmount == 0 && totalBoostAmount != 0) {
            removeAfterRun = false;
        }

        // Update the boost amount in the global kv
        ENGINE.setGlobalKV(keyForMon, bytes32(uint256(int256(totalBoostAmount))));

        // Update the stat boost
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName(statIndex), newBoostAmount);

        return (extraData, removeAfterRun);
    }

    function _resetStatBoosts(uint256 targetIndex, uint256 monIndex, bytes memory extraData) internal {
        (uint256 statIndex,) = abi.decode(extraData, (uint256, int32));
        bytes32 keyForMon = keccak256(abi.encode(targetIndex, monIndex, statIndex, name()));
        int32 existingBoostAmount = int32(int256(uint256(ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), keyForMon))));

        // Reset the global kv
        ENGINE.setGlobalKV(keyForMon, bytes32(0));

        // Reset the stat boost
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName(statIndex), existingBoostAmount * -1);
    }

    function onMonSwitchOut(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        _resetStatBoosts(targetIndex, monIndex, extraData);

        // Remove the effect on switch out
        return ("", true);
    }

    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external override {
        _resetStatBoosts(targetIndex, monIndex, extraData);
    }
}

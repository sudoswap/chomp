// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IEffect} from "../IEffect.sol";

abstract contract StatusEffect is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    bytes32 constant STATUS_EFFECT = "STATUS_EFFECT";

    function _getKeyForMonIndex(uint256 playerIndex, uint256 monIndex) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(STATUS_EFFECT, playerIndex, monIndex));
    }

    function name() external virtual returns (string memory);

    // Whether to run the effect at a specific step
    function shouldRunAtStep(EffectStep r) external virtual returns (bool) {}

    // Whether or not to add the effect if the step condition is met
    function shouldApply(bytes memory, uint256 targetIndex, uint256 monIndex) public virtual returns (bool) {
        bytes32 battleKey = ENGINE.battleKeyForWrite();
        bytes32 keyForMon = _getKeyForMonIndex(targetIndex, monIndex);

        // Get value from ENGINE KV
        bytes32 monStatusFlag = ENGINE.getGlobalKV(battleKey, keyForMon);

        // Check if a status already exists for the mon
        if (monStatusFlag == bytes32(0)) {
            // If not, set the flag and return true
            ENGINE.setGlobalKV(keyForMon, bytes32("1"));
            return true;
        } else {
            // Otherwise return false
            return false;
        }
    }

    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        updatedExtraData = extraData;
        removeAfterRun = false;
    }

    function onRoundEnd(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        updatedExtraData = extraData;
        removeAfterRun = false;
    }

    // NOTE: ONLY RUN ON GLOBAL EFFECTS (mons have their Ability as their own hook to apply an effect on switch in)
    function onMonSwitchIn(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        updatedExtraData = extraData;
        removeAfterRun = false;
    }

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onMonSwitchOut(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        updatedExtraData = extraData;
        removeAfterRun = false;
    }

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onAfterDamage(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        updatedExtraData = extraData;
        removeAfterRun = false;
    }

    // Lifecycle hooks when being applied or removed
    function onApply(uint256, bytes memory extraData, uint256, uint256)
        external
        virtual
        returns (bytes memory updatedExtraData)
    {
        updatedExtraData = extraData;
    }

    function onRemove(bytes memory, uint256 targetIndex, uint256 monIndex) public virtual {
        // On remove, reset the status flag
        bytes32 keyForMon = _getKeyForMonIndex(targetIndex, monIndex);
        ENGINE.setGlobalKV(keyForMon, bytes32(0));
    }
}

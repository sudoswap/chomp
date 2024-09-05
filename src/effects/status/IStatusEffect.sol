// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IEffect} from "../IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {EffectStep} from "../../Enums.sol";

abstract contract IStatusEffect is IEffect {
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
    function shouldApply(bytes memory, uint256 targetIndex, uint256 monIndex) external virtual returns (bool) {
        bytes32 battleKey = ENGINE.battleKeyForWrite();
        bytes32 keyForMon = _getKeyForMonIndex(targetIndex, monIndex);

        // Get value from ENGINE KV
        bytes32 monStatusFlag = ENGINE.getGlobalKV(battleKey, keyForMon);

        // Check if a status already exists for the mon
        if (monStatusFlag == bytes32(0)) {
            ENGINE.setGlobalKV(keyForMon, bytes32("1"));
            return true;
        }
        else {
            return false;
        }
    }

    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun) {
            updatedExtraData = extraData;
        }
    function onRoundEnd(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun) {
            updatedExtraData = extraData;
        }

    // NOTE: ONLY RUN ON GLOBAL EFFECTS (mons have their Ability as their own hook to apply an effect on switch in)
    function onMonSwitchIn(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun) {
            updatedExtraData = extraData;
        }

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onMonSwitchOut(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun) {
            updatedExtraData = extraData;
        }

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onAfterDamage(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData, bool removeAfterRun) {
            updatedExtraData = extraData;
        }

    // Lifecycle hooks when being applied or removed
    function onApply(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external virtual
        returns (bytes memory updatedExtraData) {
            updatedExtraData = extraData;
        }
    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external virtual {
    }
}
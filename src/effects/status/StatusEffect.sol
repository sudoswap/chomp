// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {BasicEffect} from "../BasicEffect.sol";

abstract contract StatusEffect is BasicEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    bytes32 constant STATUS_EFFECT = "STATUS_EFFECT";

    function _getKeyForMonIndex(uint256 playerIndex, uint256 monIndex) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(STATUS_EFFECT, playerIndex, monIndex));
    }

    // Whether or not to add the effect if the step condition is met
    function shouldApply(bytes memory, uint256 targetIndex, uint256 monIndex) public virtual override returns (bool) {
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

    function onRemove(bytes memory, uint256 targetIndex, uint256 monIndex) public virtual override {
        // On remove, reset the status flag
        bytes32 keyForMon = _getKeyForMonIndex(targetIndex, monIndex);
        ENGINE.setGlobalKV(keyForMon, bytes32(0));
    }
}

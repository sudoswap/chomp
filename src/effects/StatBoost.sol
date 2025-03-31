// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {BasicEffect} from "./BasicEffect.sol";

contract StatBoost is BasicEffect {
    /**
     * Can only be applied once per mon
     * If a mon switches out, clear the effect
     * Maintain a global kv for player index / mon index / stat index
     */
    function name() external pure override returns (string memory) {
        return "StatBoost";
    }

    // Should run at end of round and on apply
    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return (r == EffectStep.OnMonSwitchOut || r == EffectStep.OnApply);
    }

    function onApply(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        return ("", false);
    }

    function onMonSwitchOut(bytes32, uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        return ("", true);
    }

}

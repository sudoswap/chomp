// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IEffect} from "../IEffect.sol";

import {IStatusEffect} from "./IStatusEffect.sol";

contract SleepStatus is IStatusEffect {
    uint256 constant DURATION = 3;

    constructor(IEngine engine) IStatusEffect(engine) {}

    function name() public pure override returns (string memory) {
        return "Sleep";
    }

    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return r == EffectStep.RoundStart || r == EffectStep.RoundEnd || r == EffectStep.OnApply;
    }

    // At the start of the turn, check to see if we should apply sleep or end early
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory, bool)
    {
        bool wakeEarly = rng % 3 == 0;
        if (wakeEarly) {
            return (extraData, true);
        } else {
            _applySleep(rng, targetIndex, monIndex);
        }
        return (extraData, false);
    }

    // On apply, checks to apply the sleep flag, and then sets the extraData to be the duration
    function onApply(uint256 rng, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData)
    {
        _applySleep(rng, targetIndex, monIndex);
        return (abi.encode(DURATION));
    }

    // Sleep just skips the turn
    function _applySleep(uint256, uint256 targetIndex, uint256 monIndex) internal {
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.ShouldSkipTurn, 1);
    }

    function onRoundEnd(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        override
        returns (bytes memory, bool removeAfterRun)
    {
        uint256 turnsLeft = abi.decode(extraData, (uint256));
        if (turnsLeft == 1) {
            return (extraData, true);
        } else {
            return (abi.encode(turnsLeft - 1), false);
        }
    }
}

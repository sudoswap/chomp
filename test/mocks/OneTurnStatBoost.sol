// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

contract OneTurnStatBoost is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "";
    }

    // Should run at end of round and on apply
    function shouldRunAtStep(EffectStep r) external pure returns (bool) {
        return (r == EffectStep.RoundEnd || r == EffectStep.OnApply);
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    // Adds a bonus
    function onApply(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData)
    {
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Attack, 1);
        return "";
    }

    // Adds another bonus
    function onRoundEnd(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Attack, 1);
        return ("", true);
    }

    // Everything below is an NoOp
    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

        function onMonSwitchOut(bytes32, uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: ONLY RUN ON GLOBAL EFFECTS (mons have their Ability as their own hook to apply an effect on switch in)
    function onMonSwitchIn(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onMonSwitchOut(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onAfterDamage(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex, int32)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external {}
}

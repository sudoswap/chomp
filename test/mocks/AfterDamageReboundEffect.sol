// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

contract AfterDamageReboundEffect is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "";
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep r) external pure returns (bool) {
        return r == EffectStep.AfterDamage;
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onAfterDamage(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory, bool)
    {
        // Heals for all damage done
        int32 currentDamage = ENGINE.getMonStateForBattle(ENGINE.battleKeyForWrite(), targetIndex, monIndex, MonStateIndexName.Hp);
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Hp, currentDamage * -1);
        return (extraData, false);
    }

    // Everything below is an NoOp
    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    function onRoundEnd(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        pure
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

    // Lifecycle hooks when being applied or removed
    function onApply(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData)
    {}
    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external {}
}

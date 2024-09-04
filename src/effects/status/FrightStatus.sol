// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IEffect} from "../IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IStatusEffect} from "./IStatusEffect.sol";

contract FrightStatus is IStatusEffect {

    uint256 constant DURATION = 3;

    constructor(IEngine engine) IStatusEffect(engine) {}

    function name() public pure override returns (string memory) {
        return "Fright";
    }

    function shouldRunAtStep(EffectStep r) external pure override returns (bool) {
        return r == EffectStep.RoundStart || r == EffectStep.RoundEnd || r == EffectStep.OnApply;
    }

    // At the start of the turn, check to see if we should apply fright or end early
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external override
        returns (bytes memory, bool) {
        uint256 turnsLeft = abi.decode(extraData, (uint256));
        bool wakeEarly = rng % 3 == 0;
        if (turnsLeft == 0 || wakeEarly) {
            return (extraData, true);
        }
        else {
            _applyFright(rng, targetIndex, monIndex);
        }
        return (abi.encode(turnsLeft - 1), false);
    }

    // On apply, checks to apply the sleep flag, and then sets the extraData to be the duration
    function onApply(uint256 rng, bytes memory, uint256 targetIndex, uint256 monIndex)
        external override
        returns (bytes memory updatedExtraData) {
        _applyFright(rng, targetIndex, monIndex);
        return (abi.encode(DURATION));
    }

    // Sleep just skips the turn
    function _applyFright(uint256, uint256 targetIndex, uint256 monIndex) internal {

        // Get current stamina delta of the target mon
        int32 staminaDelta = ENGINE.getMonStatesForBattleState(ENGINE.battleKeyForWrite())[targetIndex][monIndex].staminaDelta;

        // If the stamina is less than the max stamina, then reduce stamina by 1
        uint32 maxStamina = ENGINE.getTeamsForBattle(ENGINE.battleKeyForWrite())[targetIndex][monIndex].stats.stamina;
        if (staminaDelta + int32(maxStamina) > 0) {
            ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Stamina, -1);
        }
    }
}
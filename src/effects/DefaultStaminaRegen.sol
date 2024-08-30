// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {IEffect} from "./IEffect.sol";

contract DefaultStaminaRegen is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "Default Stamina Regen";
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep r) external pure returns (bool roundEnd) {
        roundEnd = r == EffectStep.RoundEnd;
    }

    function onRoundEnd(uint256, bytes memory, uint256, uint256) external returns (bytes memory, bool) {
        bytes32 battleKey = ENGINE.battleKeyForWrite();
        uint256 playerSwitchForTurnFlag = ENGINE.getPlayerSwitchForTurnFlagForBattleState(battleKey);
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);

        // Update stamina for both active mons only if it's a 2 player turn
        if (playerSwitchForTurnFlag == 2) {
            for (uint256 playerIndex; playerIndex < 2; ++playerIndex) {
                int256 currentActiveMonStaminaDelta = monStates[playerIndex][activeMonIndex[playerIndex]].staminaDelta;

                // Cannot go past max stamina, so we only add 1 stamina if the current delta is negative
                if (currentActiveMonStaminaDelta < 0) {
                    ENGINE.updateMonState(playerIndex, activeMonIndex[playerIndex], MonStateIndexName.Stamina, 1);
                }
            }
        }
        // We don't need to store data
        return ("", false);
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    // Everything below is an NoOp
    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
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
    function onAfterDamage(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
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

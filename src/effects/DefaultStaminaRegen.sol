// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {BasicEffect} from "./BasicEffect.sol";

contract DefaultStaminaRegen is BasicEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure override returns (string memory) {
        return "Default Stamina Regen";
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep r) external pure override returns (bool roundEnd) {
        roundEnd = r == EffectStep.RoundEnd;
    }

    function onRoundEnd(uint256, bytes memory, uint256, uint256) external override returns (bytes memory, bool) {
        bytes32 battleKey = ENGINE.battleKeyForWrite();
        uint256 playerSwitchForTurnFlag = ENGINE.getPlayerSwitchForTurnFlagForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);

        // Update stamina for both active mons only if it's a 2 player turn
        if (playerSwitchForTurnFlag == 2) {
            for (uint256 playerIndex; playerIndex < 2; ++playerIndex) {
                int256 currentActiveMonStaminaDelta = ENGINE.getMonStateForBattle(
                    battleKey, playerIndex, activeMonIndex[playerIndex], MonStateIndexName.Stamina
                );

                // Cannot go past max stamina, so we only add 1 stamina if the current delta is negative
                if (currentActiveMonStaminaDelta < 0) {
                    ENGINE.updateMonState(playerIndex, activeMonIndex[playerIndex], MonStateIndexName.Stamina, 1);
                }
            }
        }
        // We don't need to store data
        return ("", false);
    }
}

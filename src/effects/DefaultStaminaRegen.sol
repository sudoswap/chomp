// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEffect} from "./IEffect.sol";
import {IEngine} from "../IEngine.sol";

contract DefaultStaminaRegen is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (bytes32) {
        return "DefaultStaminaRegen";
    }

    // Irrelevant, as it will be registered at the beginning of the battle
    function isValidToRegister(bytes32, uint256) external pure returns (bool) {
        return true;
    }

    // Should run at end of round
    function shouldRunAtRound(Round r) external pure returns (bool) {
        if (r == Round.End) {
            return true;
        } else {
            return false;
        }
    }

    function shouldClearAfterMonSwitch() external pure returns (bool) {
        return false;
    }

    function runEffect(bytes32 battleKey, uint256, bytes memory, uint256)
        external
        view
        returns (MonState[][] memory, bytes memory, bool)
    {
        BattleState memory state = ENGINE.getBattleState(battleKey);
        // By default, update stamina for both active mons
        if (state.playerSwitchForTurnFlag == 0) {
            state.monStates[0] = _regenStaminaDelta(state, 0);
            state.monStates[1] = _regenStaminaDelta(state, 1);
        }
        // Otherwise, if the state player allowance flag is set, only update the stamina delta of the non-swapped-in mon
        else if (state.playerSwitchForTurnFlag == 1) {
            state.monStates[1] = _regenStaminaDelta(state, 1);
        } else if (state.playerSwitchForTurnFlag == 2) {
            state.monStates[0] = _regenStaminaDelta(state, 0);
        }
        // We don't need to store data
        return (state.monStates, "", false);
    }

    function _regenStaminaDelta(BattleState memory state, uint256 playerIndex)
        internal
        pure
        returns (MonState[] memory)
    {
        int256 currentActiveMonStaminaDelta =
            state.monStates[playerIndex][state.activeMonIndex[playerIndex]].staminaDelta;
        int256 updatedActiveMonStaminaDelta = currentActiveMonStaminaDelta;
        // Cannot go past max stamina
        if (currentActiveMonStaminaDelta < 0) {
            updatedActiveMonStaminaDelta = currentActiveMonStaminaDelta + 1;
        }
        MonState[] memory monState = state.monStates[playerIndex];
        monState[state.activeMonIndex[playerIndex]].staminaDelta = updatedActiveMonStaminaDelta;
        return monState;
    }
}

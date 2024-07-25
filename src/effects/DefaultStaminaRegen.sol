// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IEffect} from "./IEffect.sol";
import "../Structs.sol";

contract DefaultStaminaRegen is IEffect {

    // Irrelevant, as it will be registered at the beginning of the battle
    function isValidToRegister(Battle calldata, BattleState calldata, uint256[][] calldata)
        external
        pure
        returns (bool)
    {
        return true;
    }

    // Should not run at beginning of round
    function shouldRunAtRoundStart() external pure returns (bool) {
        return false;
    }

    // Will run at end of round
    function shouldRunAtRoundEnd() external pure returns (bool) {
        return true;
    }

    function handleEffect(
        Battle memory,
        BattleState memory state,
        uint256,
        bytes memory,
        uint256[][] memory
    ) external pure returns (MonState[][] memory, bytes memory) {
        if (state.playerSwitchForTurnFlag == 0) {
            state.monStates[0] = _regenStaminaDelta(state, 0);
            state.monStates[1] = _regenStaminaDelta(state, 1);
        }
        // Otherwise, if the state player allowance flag is set, only update the stamina delta of the non-swapped-in mon
        else if (state.playerSwitchForTurnFlag == 1) {
            state.monStates[1] = _regenStaminaDelta(state, 1);
        }
        else if (state.playerSwitchForTurnFlag == 2) {
            state.monStates[0] = _regenStaminaDelta(state, 0);
        }
        return (state.monStates, "");
    }

    function _regenStaminaDelta(BattleState memory state, uint256 playerIndex) pure internal returns (MonState[] memory) {
        int256 currentActiveMonStaminaDelta = state.monStates[playerIndex][state.activeMonIndex[playerIndex]].staminaDelta;
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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";
import {IRuleset} from "./IRuleset.sol";

contract DefaultRuleset is IRuleset {

    uint256 constant SWITCH_PRIORITY = 6;
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    // Returns which player should move first
    function computePriorityPlayerIndex(bytes32 battleKey, uint256 rng) external view returns (uint256) {
        Mon[][] memory teams = ENGINE.getTeamsForBattle(battleKey);
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);
        RevealedMove[][] memory moveHistory = ENGINE.getMoveHistoryForBattleState(battleKey);
        RevealedMove memory p0Move = moveHistory[0][ENGINE.getTurnIdForBattleState(battleKey)];
        RevealedMove memory p1Move = moveHistory[1][ENGINE.getTurnIdForBattleState(battleKey)];

        uint256 p0Priority;
        uint256 p1Priority;

        // Call the move for its priority, unless it's the switch or no op move index
        {
            if (p0Move.moveIndex == SWITCH_MOVE_INDEX || p0Move.moveIndex == NO_OP_MOVE_INDEX) {
                p0Priority = SWITCH_PRIORITY;
            } else {
                IMoveSet p0MoveSet = teams[0][activeMonIndex[0]].moves[p0Move.moveIndex];
                p0Priority = p0MoveSet.priority(battleKey);
            }

            if (p1Move.moveIndex == SWITCH_MOVE_INDEX || p1Move.moveIndex == NO_OP_MOVE_INDEX) {
                p1Priority = SWITCH_PRIORITY;
            } else {
                IMoveSet p1MoveSet = teams[1][activeMonIndex[1]].moves[p1Move.moveIndex];
                p1Priority = p1MoveSet.priority(battleKey);
            }
        }

        // Determine priority based on (in descending order of importance):
        // - the higher priority tier
        // - within same priority, the higher speed
        // - if both are tied, use the rng value
        if (p0Priority > p1Priority) {
            return 0;
        } else if (p0Priority < p1Priority) {
            return 1;
        } else {
            uint256 p0MonSpeed =
                uint256(int256(teams[0][activeMonIndex[0]].speed) + monStates[0][activeMonIndex[0]].speedDelta);
            uint256 p1MonSpeed =
                uint256(int256(teams[1][activeMonIndex[1]].speed) + monStates[1][activeMonIndex[1]].speedDelta);
            if (p0MonSpeed > p1MonSpeed) {
                return 0;
            } else if (p0MonSpeed < p1MonSpeed) {
                return 1;
            } else {
                return rng % 2;
            }
        }
    }

    function getInitialGlobalEffects() external returns (IEffect[] memory, bytes[] memory) {
        
    }
}
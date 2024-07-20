// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./IHook.sol";
import "./Structs.sol";
import "./IMoveSet.sol";
import "./Constants.sol";

contract DefaultHook is IHook {

    // Validates that e.g. there are 6 mons per team w/ 4 moves each
    function validateGameStart(Battle calldata b, address gameStartCaller) external pure returns (bool) {

        // game can only start if p1 or p2 calls game start
        // later can change so that matchmaking needs to happen beforehand
        // otherwise users can be griefed into matches they didn't want to join
        if (gameStartCaller != b.p1 || gameStartCaller != b.p2) {
            return false;
        }

        // p1 and p2 each have 6 mons, each mon has 4 moves
        // TODO: each mon allows it to learn the move, and each mon is in the same allowed mon list
        if (b.p1Team.length != 6) {
            return false;
        }
        if (b.p2Team.length != 6) {
            return false;
        }
        for (uint i; i < 6; ++i) {
            if (b.p1Team[i].moves.length != 4) {
                return false;
            }
            if (b.p2Team[i].moves.length != 4) {
                return false;
            }
        }
        return true;
    }

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validateMove(Battle calldata b, BattleState calldata state, uint256 moveIdx, address player)
        external
        pure
        returns (bool) {
        
        // Require that the zeroth move has to be a swap for both players
        if (state.turnId == 0) {
            if (moveIdx != SWITCH_MOVE_INDEX) {
                return false;
            }
        }

        if (player == b.p1) {
            IMoveSet p1MoveSet = b.p1Team[state.p1ActiveMon].moves[moveIdx].moveSet;
            int256 p1MonStaminaDelta = state.p1MonStates[state.p1ActiveMon].staminaDelta;
            uint256 p1MonBaseStamina = b.p1Team[state.p1ActiveMon].stamina;
            uint256 p1MonStaminaCurrent = uint256(int256(p1MonBaseStamina) + p1MonStaminaDelta);
            if (p1MoveSet.stamina(b, state) > p1MonStaminaCurrent) {
                return false;
            }
        }
        else {
            IMoveSet p2MoveSet = b.p2Team[state.p2ActiveMon].moves[moveIdx].moveSet;
            int256 p2MonStaminaDelta = state.p2MonStates[state.p2ActiveMon].staminaDelta;
            uint256 p2MonBaseStamina = b.p2Team[state.p2ActiveMon].stamina;
            uint256 p2MonStaminaCurrent = uint256(int256(p2MonBaseStamina) + p2MonStaminaDelta);
            if (p2MoveSet.stamina(b, state) > p2MonStaminaCurrent) {
                return false;
            }
        }
        return true;
    }

    // Returns which player should move first
    function computePriorityPlayer(Battle calldata b, BattleState calldata state, uint256 rng) external pure returns (uint256) {
        RevealedMove memory p1Move = state.p1MoveHistory[state.turnId];
        RevealedMove memory p2Move = state.p2MoveHistory[state.turnId];
        IMoveSet p1MoveSet = b.p1Team[state.p1ActiveMon].moves[p1Move.moveIdx].moveSet;
        uint256 p1Priority = p1MoveSet.priority(b, state);
        IMoveSet p2MoveSet = b.p2Team[state.p2ActiveMon].moves[p2Move.moveIdx].moveSet;
        uint256 p2Priority = p2MoveSet.priority(b, state);

        // Check move priority first, then speed, then use rng to settle ties
        if (p1Priority > p2Priority) {
            return 1;
        }
        else if (p1Priority < p2Priority) {
            return 2;
        }
        else {
            uint256 p1MonSpeed = uint256(int256(b.p1Team[state.p1ActiveMon].speed) + state.p1MonStates[state.p1ActiveMon].speedDelta);
            uint256 p2MonSpeed = uint256(int256(b.p2Team[state.p2ActiveMon].speed) + state.p2MonStates[state.p2ActiveMon].speedDelta);
            if (p1MonSpeed > p2MonSpeed) {
                return 1;
            }
            else if (p1MonSpeed < p2MonSpeed) {
                return 2;
            }
            else {
                return rng % 2;
            }
        }   
    }

    // Validates that the game is over, returns 0 for false, 1 for p1 wins, and 2 for p2 wins
    function validateGameOver(Battle calldata b, BattleState calldata state) external pure returns (uint256) {
        return 0;
    }

    // Clear out temporary battle effects
    function modifyMonStateAfterSwitch(MonState calldata mon) external pure returns (MonState memory updatedMon) {
        return mon;
    }
}
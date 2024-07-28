// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./IValidator.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";
import "./Constants.sol";

import {IEngine} from "./IEngine.sol";

contract DefaultValidator is IValidator {

    struct Args {
        uint256 MONS_PER_TEAM;
        uint256 MOVES_PER_MON;
    }

    uint256 immutable MONS_PER_TEAM;
    uint256 immutable MOVES_PER_MON;
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE, Args memory args) {
        ENGINE = _ENGINE;
        MONS_PER_TEAM = args.MONS_PER_TEAM;
        MOVES_PER_MON = args.MOVES_PER_MON;
    }

    // Validates that e.g. there are 6 mons per team w/ 4 moves each
    function validateGameStart(Battle calldata b, address gameStartCaller) external view returns (bool) {
        // game can only start if p0 or p1 calls game start
        // later can change so that matchmaking needs to happen beforehand
        // otherwise users can be griefed into matches they didn't want to join
        if (gameStartCaller != b.p0 && gameStartCaller != b.p1) {
            return false;
        }
        // p0 and p1 each have 6 mons, each mon has 4 moves
        uint256[2] memory playerIndices = [uint256(0), uint256(1)];
        for (uint256 i; i < playerIndices.length; ++i) {
            if (b.teams[i].length != MONS_PER_TEAM) {
                return false;
            }
            for (uint256 j; j < MONS_PER_TEAM; ++j) {
                if (b.teams[i][j].moves.length != MOVES_PER_MON) {
                    return false;
                }
            }
        }
        // TODO: each mon allows it to learn the move, and each mon is in the same allowed mon list
        return true;
    }

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validateMove(bytes32 battleKey, uint256 moveIndex, address player, bytes calldata extraData)
        external
        view
        returns (bool)
    {
        Battle memory b = ENGINE.getBattle(battleKey);
        BattleState memory state = ENGINE.getBattleState(battleKey);

        // Enforce a switch IF:
        // - if it is the zeroth turn
        // - if the active mon is knocked out,
        // AND:
        // - the new mon has to be not knocked out
        bool isTurnZero = state.turnId == 0;
        uint256 playerIndex;
        if (player == b.p1) {
            playerIndex = 0;
        } else {
            playerIndex = 1;
        }
        {
            bool isActiveMonKnockedOut = state.monStates[playerIndex][state.activeMonIndex[playerIndex]].isKnockedOut;
            if (isTurnZero || isActiveMonKnockedOut) {
                if (moveIndex != SWITCH_MOVE_INDEX) {
                    return false;
                }
                uint256 monToSwitchIndex = abi.decode(extraData, (uint256));
                if (monToSwitchIndex >= MONS_PER_TEAM) {
                    return false;
                }
                bool isNewMonKnockedOut = state.monStates[playerIndex][monToSwitchIndex].isKnockedOut;
                if (isNewMonKnockedOut) {
                    return false;
                }
            }
        }

        // A move cannot be selected if its stamina costs more than the mon's current stamina
        IMoveSet moveSet = b.teams[playerIndex][state.activeMonIndex[playerIndex]].moves[moveIndex];

        // Cannot go past the first 4 moves, or the switch move index or the no op
        if (moveIndex != NO_OP_MOVE_INDEX && moveIndex != SWITCH_MOVE_INDEX) {
            if (moveIndex >= MOVES_PER_MON) {
                return false;
            }
        }

        int256 monStaminaDelta = state.monStates[playerIndex][state.activeMonIndex[playerIndex]].staminaDelta;
        uint256 monBaseStamina = b.teams[playerIndex][state.activeMonIndex[playerIndex]].stamina;
        uint256 monCurrentStamina = uint256(int256(monBaseStamina) + monStaminaDelta);
        if (moveSet.stamina(battleKey) > monCurrentStamina) {
            return false;
        }

        // Lastly, we check the move itself to see if it enforces any other specific conditions
        if (!moveSet.isValidTarget(battleKey)) {
            return false;
        }

        return true;
    }

    // Returns which player should move first
    function computePriorityPlayerIndex(bytes32 battleKey, uint256 rng) external view returns (uint256) {
        Battle memory b = ENGINE.getBattle(battleKey);
        BattleState memory state = ENGINE.getBattleState(battleKey);

        RevealedMove memory p0Move = state.moveHistory[0][state.turnId];
        RevealedMove memory p1Move = state.moveHistory[1][state.turnId];

        IMoveSet p0MoveSet = b.teams[0][state.activeMonIndex[0]].moves[p0Move.moveIndex];
        uint256 p0Priority = p0MoveSet.priority(battleKey);
        IMoveSet p1MoveSet = b.teams[1][state.activeMonIndex[1]].moves[p1Move.moveIndex];
        uint256 p1Priority = p1MoveSet.priority(battleKey);

        // Determine priority based on (in descending order of importance):
        // - the higher priority tier
        // - within same priority, the higher speed
        // - if both are tied, use the rng value
        if (p0Priority > p1Priority) {
            return 0;
        } else if (p0Priority < p1Priority) {
            return 1;
        } else {
            uint256 p0MonSpeed = uint256(
                int256(b.teams[0][state.activeMonIndex[0]].speed)
                    + state.monStates[0][state.activeMonIndex[0]].speedDelta
            );
            uint256 p1MonSpeed = uint256(
                int256(b.teams[1][state.activeMonIndex[1]].speed)
                    + state.monStates[1][state.activeMonIndex[1]].speedDelta
            );
            if (p0MonSpeed > p1MonSpeed) {
                return 0;
            } else if (p0MonSpeed < p1MonSpeed) {
                return 1;
            } else {
                return rng % 2;
            }
        }
    }

    // Validates that the game is over, returns address(0) if no winner, otherwise returns the winner
    function validateGameOver(bytes32 battleKey, uint256 priorityPlayerIndex) external view returns (address) {
        Battle memory b = ENGINE.getBattle(battleKey);
        BattleState memory state = ENGINE.getBattleState(battleKey);

        // A game is over if all of a player's mons are knocked out
        uint256[2] memory playerIndex = [uint256(0), uint256(1)];
        if (priorityPlayerIndex == 1) {
            playerIndex = [uint256(1), uint256(0)];
        }

        for (uint256 i; i < playerIndex.length; ++i) {
            uint256 numMonsKnockedOut;
            for (uint256 j; j < MONS_PER_TEAM; ++j) {
                if (state.monStates[playerIndex[i]][j].isKnockedOut) {
                    numMonsKnockedOut += 1;
                }
            }
            if (numMonsKnockedOut == MONS_PER_TEAM) {
                if (playerIndex[i] == 0) {
                    return b.p1;
                } else {
                    return b.p0;
                }
            }
        }
        return address(0);
    }
}

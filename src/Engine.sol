// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";
import "./Constants.sol";
import "./IMoveSet.sol";

contract Engine {
    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;

    error NotP1OrP2();
    error AlreadyCommited();
    error RevealBeforeOtherCommit();
    error WrongTurnId();
    error WrongPreimage();
    error InvalidMove();
    error OnlyP1Allowed();
    error OnlyP2Allowed();
    error InvalidBattleConfig();

    modifier onlyPlayer(bytes32 battleKey) {
        Battle memory battle = battles[battleKey];
        if (msg.sender != battle.p1 && msg.sender != battle.p2) {
            revert NotP1OrP2();
        }
        _;
    }

    function start(Battle calldata battle) external {
        // validate battle
        if (!battle.hook.validateGameStart(battle, msg.sender)) {
            revert InvalidBattleConfig();
        }

        // store battle
        bytes32 battleKey = sha256(abi.encode(battle.salt, battle.p1, battle.p2));
        battles[battleKey] = battle;

        // Initialize empty mon state delta for each team
        for (uint256 i; i < battle.p1Team.length; ++i) {
            battleStates[battleKey].p1MonStates.push();
        }
        for (uint256 i; i < battle.p2Team.length; ++i) {
            battleStates[battleKey].p2MonStates.push();
        }
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external onlyPlayer(battleKey) {
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];

        // validate no commitment exists for this turn
        uint256 turnId = state.turnId;
        if (commitments[battleKey][msg.sender].turnId == turnId) {
            revert AlreadyCommited();
        }

        // cannot commit if the battle state says it's only for one player
        uint256 pAllowanceFlag = state.pAllowanceFlag;
        if (pAllowanceFlag == 1 && msg.sender != battle.p1) {
            revert OnlyP2Allowed();
        } else if (pAllowanceFlag == 2 && msg.sender != battle.p2) {
            revert OnlyP1Allowed();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIdx, bytes32 salt, bytes calldata extraData)
        external
        onlyPlayer(battleKey)
    {
        // validate preimage
        Commitment memory commitment = commitments[battleKey][msg.sender];
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];
        if (keccak256(abi.encodePacked(moveIdx, salt, extraData)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // ensure reveal happens after caller commits
        if (commitment.turnId != state.turnId) {
            revert WrongTurnId();
        }

        // ensure reveal happens after opponent commits
        // (only if it is a turn where both players need to select an action)
        if (state.pAllowanceFlag == 0) {
            address otherPlayer;
            if (msg.sender == battle.p1) {
                otherPlayer = battle.p2;
            } else {
                otherPlayer = battle.p1;
            }
            if (commitments[battleKey][otherPlayer].turnId != state.turnId) {
                revert RevealBeforeOtherCommit();
            }
        }

        // validate that the commited moves are legal
        // (e.g. there is enough stamina, move is not disabled, etc.)
        if (!battle.hook.validateMove(battle, state, moveIdx, msg.sender, extraData)) {
            revert InvalidMove();
        }

        // store revealed move and extra data as needed
        if (msg.sender == battle.p1) {
            battleStates[battleKey].p1MoveHistory.push(
                RevealedMove({moveIdx: moveIdx, salt: salt, extraData: extraData})
            );
        } else {
            battleStates[battleKey].p2MoveHistory.push(
                RevealedMove({moveIdx: moveIdx, salt: salt, extraData: extraData})
            );
        }

        // store empty move for other player if it's a turn where only a single player has to make a move
        if (state.pAllowanceFlag == 1) {
            battleStates[battleKey].p2MoveHistory.push(
                RevealedMove({moveIdx: NO_OP_MOVE_INDEX, salt: "", extraData: ""})
            );
        } else if (state.pAllowanceFlag == 2) {
            battleStates[battleKey].p1MoveHistory.push(
                RevealedMove({moveIdx: NO_OP_MOVE_INDEX, salt: "", extraData: ""})
            );
        }
    }

    function execute(bytes32 battleKey) external {
        Battle memory battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        uint256 turnId = state.turnId;

        // If only a single player has a move to submit, then we don't trigger any effects
        // (Basically this only handles switching mons for now)
        if (state.pAllowanceFlag == 1 || state.pAllowanceFlag == 2) {

            // Push 0 to rng stream as only single player is switching, to keep in line with turnId
            state.pRNGStream.push(0);

            if (state.pAllowanceFlag == 1) {
                {
                    RevealedMove memory p1Move = battleStates[battleKey].p1MoveHistory[turnId];

                    // If p1 is switching in a mon, update the active mon index
                    // (assume that validateMove validates that this is a valid choice)
                    if (p1Move.moveIdx == SWITCH_MOVE_INDEX) {
                        uint256 monToSwitchIndex = abi.decode(p1Move.extraData, (uint256));
                        MonState memory currentMonState = state.p1MonStates[state.p1ActiveMon];
                        state.p1MonStates[state.p1ActiveMon] = battle.hook.modifyMonStateAfterSwitch(currentMonState);
                        state.p1ActiveMon = monToSwitchIndex;
                    }

                    // No support for any other single-player actions for now
                }
            } else if (state.pAllowanceFlag == 2) {
                {
                    RevealedMove memory p2Move = battleStates[battleKey].p2MoveHistory[turnId];

                    // If p2 is switching in a mon, update the active mon index
                    // (assume that validateMove validates that this is a valid choice)
                    if (p2Move.moveIdx == SWITCH_MOVE_INDEX) {
                        uint256 monToSwitchIndex = abi.decode(p2Move.extraData, (uint256));
                        MonState memory currentMonState = state.p2MonStates[state.p2ActiveMon];
                        state.p2MonStates[state.p2ActiveMon] = battle.hook.modifyMonStateAfterSwitch(currentMonState);
                        state.p2ActiveMon = monToSwitchIndex;
                    }
                    
                    // No support for any other single-player actions for now
                }
            }

            // Progress turn index
            state.turnId += 1;

            // TODO: run end of turn effects
            // TODO: update stamina for active mon for the side that DID NOT switch
        }
        // Otherwise, we need to run priority calculations and update the game state for both players
        else {
            // Validate both moves have been revealed for the current turn
            // (accessing the values will revert if they haven't been set)
            RevealedMove memory p1Move = battleStates[battleKey].p1MoveHistory[turnId];
            RevealedMove memory p2Move = battleStates[battleKey].p2MoveHistory[turnId];
            IMoveSet p1MoveSet = battle.p1Team[state.p1ActiveMon].moves[p1Move.moveIdx].moveSet;
            IMoveSet p2MoveSet = battle.p2Team[state.p2ActiveMon].moves[p2Move.moveIdx].moveSet;

            // Update the PRNG hash to include the newest value
            uint256 rng = uint256(sha256(abi.encode(p1Move.salt, p2Move.salt, blockhash(block.number - 1))));
            state.pRNGStream.push(rng);

            uint256 priorityPlayer = battle.hook.computePriorityPlayer(battle, state, rng);

            // TODO: Before turn effects, e.g. items, battlefield moves, recurring move effects, etc 
            // Execute priority player's move
            // Check for game over
            // If game over, then end execution, let game be endable
            // Check for knockout
            // If knocked out, then transition to a new state where the knocked out player can switch
            // Execute non-prioirty player's move
            // Check for game over
            // If game over, then end execution, let game be endable
            // Check for knockout
            // If knocked out, then transition to a new state where the knocked out player can switch
            // Check for end of turn effects

            if (priorityPlayer == 1) {
                (MonState[] memory p1MonStates, MonState[] memory p2MonStates) = p1MoveSet.move(battle, state, p1Move.extraData, rng);
                for (uint i; i < p1MonStates.length; ++i) {
                    state.p1MonStates[i] = p1MonStates[i];
                }
                for (uint i; i < p2MonStates.length; ++i) {
                    state.p2MonStates[i] = p2MonStates[i];
                }

                // Check for game over

            }
            else {

            }
        }
    }

    function end(bytes32 battleKey) external {}
}

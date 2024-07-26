// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";
import "./Constants.sol";
import "./IMoveSet.sol";

import {IEngine} from "./IEngine.sol";
import {IMonEffect} from "./effects/IMonEffect.sol";

contract Engine is IEngine {
    mapping(bytes32 => uint256) public pairHashNonces;
    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;

    error NotP0OrP1();
    error AlreadyCommited();
    error RevealBeforeOtherCommit();
    error WrongTurnId();
    error WrongPreimage();
    error InvalidMove();
    error OnlyP0Allowed();
    error OnlyP1Allowed();
    error InvalidBattleConfig();
    error GameAlreadyOver();

    modifier onlyPlayer(bytes32 battleKey) {
        Battle memory battle = battles[battleKey];
        if (msg.sender != battle.p0 && msg.sender != battle.p1) {
            revert NotP0OrP1();
        }
        _;
    }

    function getBattle(bytes32 battleKey) external view returns (Battle memory) {
        return battles[battleKey];
    }

    function getBattleState(bytes32 battleKey) external view returns (BattleState memory) {
        return battleStates[battleKey];
    }

    function start(Battle calldata battle) external {
        // validate battle
        if (!battle.validator.validateGameStart(battle, msg.sender)) {
            revert InvalidBattleConfig();
        }

        // Compute unique identifier for the battle
        // pairhash is keccak256(p0, p1) or keccak256(p1, p0), the lower address comes first
        // then compute keccak256(pair hash, nonce)
        bytes32 pairHash = keccak256(abi.encode(battle.p0, battle.p1));
        if (uint256(uint160(battle.p0)) > uint256(uint160(battle.p1))) {
            pairHash = keccak256(abi.encode(battle.p1, battle.p0));
        }
        uint256 pairHashNonce = pairHashNonces[pairHash];
        pairHashNonces[pairHash] += 1;
        bytes32 battleKey = keccak256(abi.encode(pairHash, pairHashNonce));
        battles[battleKey] = battle;

        // Initialize empty mon state, move history, and active mon index for each team
        for (uint256 i; i < battle.validator.numPlayers(); ++i) {
            battleStates[battleKey].monStates.push();
            battleStates[battleKey].moveHistory.push();
            battleStates[battleKey].activeMonIndex.push();

            // Initialize empty mon delta states for each mon on the team
            for (uint256 j; j < battle.teams[i].length; ++j) {
                battleStates[battleKey].monStates[i].push();
            }
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
        uint256 playerSwitchForTurnFlag = state.playerSwitchForTurnFlag;
        if (playerSwitchForTurnFlag == 1 && msg.sender != battle.p0) {
            revert OnlyP0Allowed();
        } else if (playerSwitchForTurnFlag == 2 && msg.sender != battle.p1) {
            revert OnlyP1Allowed();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIndex, bytes32 salt, bytes calldata extraData)
        external
        onlyPlayer(battleKey)
    {
        // validate preimage
        Commitment memory commitment = commitments[battleKey][msg.sender];
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];
        if (keccak256(abi.encodePacked(moveIndex, salt, extraData)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // ensure reveal happens after caller commits
        if (commitment.turnId != state.turnId) {
            revert WrongTurnId();
        }

        // ensure reveal happens after opponent commits
        // (only if it is a turn where both players need to select an action)
        uint256 currentPlayerIndex;
        uint256 otherPlayerIndex;
        if (state.playerSwitchForTurnFlag == 0) {
            address otherPlayer;
            if (msg.sender == battle.p0) {
                otherPlayer = battle.p1;
                otherPlayerIndex = 1;
            } else {
                otherPlayer = battle.p0;
                currentPlayerIndex = 1;
            }
            if (commitments[battleKey][otherPlayer].turnId != state.turnId) {
                revert RevealBeforeOtherCommit();
            }
        }

        // validate that the commited moves are legal
        // (e.g. there is enough stamina, move is not disabled, etc.)
        if (!battle.validator.validateMove(battleKey, moveIndex, msg.sender, extraData)) {
            revert InvalidMove();
        }

        // store revealed move and extra data for the current player
        battleStates[battleKey].moveHistory[currentPlayerIndex].push(
            RevealedMove({moveIndex: moveIndex, salt: salt, extraData: extraData})
        );

        // store empty move for other player if it's a turn where only a single player has to make a move
        if (state.playerSwitchForTurnFlag == 1 || state.playerSwitchForTurnFlag == 2) {
            battleStates[battleKey].moveHistory[otherPlayerIndex].push(
                RevealedMove({moveIndex: NO_OP_MOVE_INDEX, salt: "", extraData: ""})
            );
        }
    }

    function _handlePlayerMove(bytes32 battleKey, uint256 rng, uint256 playerIndex) internal {
        Battle memory battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove memory move = battleStates[battleKey].moveHistory[playerIndex][turnId];
        IMoveSet moveSet = battle.teams[playerIndex][state.activeMonIndex[playerIndex]].moves[move.moveIndex].moveSet;

        // handle a switch, a no-op, or execute the moveset
        if (move.moveIndex == SWITCH_MOVE_INDEX) {
            _handleSwitch(battleKey, playerIndex);
        } else if (move.moveIndex == NO_OP_MOVE_INDEX) {
            // do nothing (e.g. just recover stamina)
        }
        // Execute the move and then copy state deltas over
        else {
            (MonState[][] memory monStates) = moveSet.move(battleKey, move.extraData, rng);
            uint256 numPlayerStates = monStates.length;
            for (uint256 i; i < numPlayerStates; ++i) {
                for (uint256 j; j < monStates[i].length; ++j) {
                    state.monStates[i][j] = monStates[i][j];
                }
            }
        }
    }

    function _handleSwitch(bytes32 battleKey, uint256 playerIndex) internal {
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove memory move = battleStates[battleKey].moveHistory[playerIndex][turnId];
        uint256 monToSwitchIndex = abi.decode(move.extraData, (uint256));
        MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
        IMonEffect[] storage effects = currentMonState.targetedEffects;
        bytes[] storage extraData = currentMonState.extraDataForTargetedEffects;
        uint i = 0;

        // Go through each effect to see if it should be cleared after a switch, 
        // If so, remove the effect and the extra data
        while (i < effects.length) {
            if (effects[i].shouldClearAfterMonSwitch()) {
                
                // effects and extra data should be synced
                effects[i] = effects[effects.length - 1];
                effects.pop();

                extraData[i] = extraData[effects.length - 1];
                extraData.pop();
            }
            else {
                ++i;
            }
        }

        // Clear out deltas on mon stats
        currentMonState.attackDelta = 0;
        currentMonState.specialAttackDelta = 0;
        currentMonState.defenceDelta = 0;
        currentMonState.specialDefenceDelta = 0;
        currentMonState.speedDelta = 0;

        // Update to new active mon (we assume validate already resolved and gives us a valid target)
        state.activeMonIndex[playerIndex] = monToSwitchIndex;
    }

    function _checkForKnockoutAndForceSwitch(bytes32 battleKey, uint256 playerIndex) internal returns (bool) {
        BattleState storage state = battleStates[battleKey];
        if (state.monStates[playerIndex][state.activeMonIndex[playerIndex]].isKnockedOut) {
            state.playerSwitchForTurnFlag = playerIndex;
            return true;
        } else {
            return false;
        }
    }

    function execute(bytes32 battleKey) external {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        uint256 turnId = state.turnId;

        // If only a single player has a move to submit, then we don't trigger any effects
        // (Basically this only handles switching mons for now)
        if (state.playerSwitchForTurnFlag == 1 || state.playerSwitchForTurnFlag == 2) {
            // Push 0 to rng stream as only single player is switching, to keep in line with turnId
            state.pRNGStream.push(0);

            // Get the player index (offset the switchForTurnFlag value by one)
            uint256 playerIndex = state.playerSwitchForTurnFlag - 1;
            RevealedMove memory move = battleStates[battleKey].moveHistory[playerIndex][turnId];

            if (move.moveIndex == SWITCH_MOVE_INDEX) {
                _handleSwitch(battleKey, playerIndex);
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
            RevealedMove memory p0Move = battleStates[battleKey].moveHistory[0][turnId];
            RevealedMove memory p1Move = battleStates[battleKey].moveHistory[1][turnId];

            // Update the PRNG hash to include the newest value
            uint256 rng = uint256(keccak256(abi.encode(p0Move.salt, p1Move.salt, blockhash(block.number - 1))));
            state.pRNGStream.push(rng);

            // Calculate the priority and non-priority player indices
            uint256 priorityPlayerIndex = battle.validator.computePriorityPlayerIndex(battleKey, rng);
            uint256 otherPlayerIndex;
            if (priorityPlayerIndex == 0) {
                otherPlayerIndex = 1;
            }

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

            _handlePlayerMove(battleKey, rng, priorityPlayerIndex);
            address gameResult = battle.validator.validateGameOver(battleKey);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            }
            bool shouldForceSwitch;
            shouldForceSwitch = _checkForKnockoutAndForceSwitch(battleKey, otherPlayerIndex);
            if (shouldForceSwitch) {
                return;
            }
            _handlePlayerMove(battleKey, rng, otherPlayerIndex);
            gameResult = battle.validator.validateGameOver(battleKey);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            }
            shouldForceSwitch = _checkForKnockoutAndForceSwitch(battleKey, priorityPlayerIndex);
            if (shouldForceSwitch) {
                return;
            }

            // TODO: update end of turn effects for both mons

            // Progress turn index
            state.turnId += 1;
        }
    }

    function end(bytes32 battleKey) external {
        // TODO: resolve liveness issues to forcibly end games
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";
import "./Constants.sol";
import "./moves/IMoveSet.sol";
import "./Enums.sol";

import {IEngine} from "./IEngine.sol";

contract Engine is IEngine {
    mapping(bytes32 => uint256) public pairHashNonces;
    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;
    mapping(bytes32 battleKey => mapping(bytes32 => bytes32)) public globalKV;

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

    function getBattle(bytes32 battleKey) external view returns (Battle memory) {
        return battles[battleKey];
    }

    function getBattleState(bytes32 battleKey) external view returns (BattleState memory) {
        return battleStates[battleKey];
    }

    function getGlobalKV(bytes32 battleKey, bytes32 key) external view returns (bytes32) {
        return globalKV[battleKey][key];
    }

    function getCommitment(bytes32 battleKey, address player) external view returns (Commitment memory) {
        return commitments[battleKey][player];
    }

    function start(Battle calldata battle) external returns (bytes32) {
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
        for (uint256 i; i < 2; ++i) {
            battleStates[battleKey].monStates.push();
            battleStates[battleKey].moveHistory.push();
            battleStates[battleKey].activeMonIndex.push();

            // Initialize empty mon delta states for each mon on the team
            for (uint256 j; j < battle.teams[i].length; ++j) {
                battleStates[battleKey].monStates[i].push();
            }
        }

        return battleKey;
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        // only battle participants can commit
        if (msg.sender != battle.p0 && msg.sender != battle.p1) {
            revert NotP0OrP1();
        }

        // validate no commitment already exists for this turn
        uint256 turnId = state.turnId;

        // if it's the zeroth turn, require that no hash is set for the player
        if (turnId == 0) {
            if (commitments[battleKey][msg.sender].moveHash != bytes32(0)) {
                revert AlreadyCommited();
            }
        }
        // otherwise, just check if the turn id (which we overwrite each turn) is in sync
        // (if we already committed this turn, then the turn id should match)
        else if (commitments[battleKey][msg.sender].turnId == turnId) {
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
    {
        // validate preimage
        Commitment storage commitment = commitments[battleKey][msg.sender];
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        if (keccak256(abi.encodePacked(moveIndex, salt, extraData)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // only battle participants can reveal
        if (msg.sender != battle.p0 && msg.sender != battle.p1) {
            revert NotP0OrP1();
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
            // if it's not the zeroth turn, make sure that player cannot reveal until other player has committed
            if (state.turnId != 0) {
                if (commitments[battleKey][otherPlayer].turnId != state.turnId) {
                    revert RevealBeforeOtherCommit();
                }
            }
            // if it is the zeroth turn, do the same check, but check moveHash instead of turnId
            else {
                if (commitments[battleKey][otherPlayer].moveHash == bytes32(0)) {
                    revert RevealBeforeOtherCommit();
                }
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

    function execute(bytes32 battleKey) external {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        if (state.winner != address(0)) {
            revert GameAlreadyOver();
        }

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
        }
        // Otherwise, we need to run priority calculations and update the game state for both players
        /*
            Flow of battle:
            - Grab moves and calculate pseudo RNG
            - Determine priority player
            - Run round start global effects
            - Run round start targeted effects for p0 and p1
            - Execute priority player's move
            - Check for game over 
            - Check for KO, if so:
                - Run end of turn effects
                - Check for game over
                - Return correct player switch flag
            - Execute non priority player's move
            - Check for game over
            - Check for KO, if so:
                - Run end of turn effects
                - Check for game over
                - Return correct player switch flag
            - Run end of turn effects
            - Check for game over
        */
        else {
            // Validate both moves have been revealed for the current turn
            // (accessing the values will revert if they haven't been set)
            RevealedMove storage p0Move = battleStates[battleKey].moveHistory[0][turnId];
            RevealedMove storage p1Move = battleStates[battleKey].moveHistory[1][turnId];

            // Update the PRNG hash to include the newest value
            uint256 rng = uint256(keccak256(abi.encode(p0Move.salt, p1Move.salt, blockhash(block.number - 1))));
            state.pRNGStream.push(rng);

            // Calculate the priority and non-priority player indices
            uint256 priorityPlayerIndex = battle.validator.computePriorityPlayerIndex(battleKey, rng);
            uint256 otherPlayerIndex;
            if (priorityPlayerIndex == 0) {
                otherPlayerIndex = 1;
            }

            // Run beginning of round effects
            _runEffects(battleKey, rng, 2, Round.Start);
            _runEffects(battleKey, rng, priorityPlayerIndex, Round.Start);
            _runEffects(battleKey, rng, otherPlayerIndex, Round.Start);

            // Execute priority player's move
            _handlePlayerMove(battleKey, rng, priorityPlayerIndex);

            // Check for game over
            address gameResult = battle.validator.validateGameOver(battleKey, priorityPlayerIndex);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            }

            // Check for knockout or subsequent game over for either player after handling move (conditional on a KO)
            uint256 playerSwitchForTurnFlag;
            bool executedEndOfRoundEffects;
            (playerSwitchForTurnFlag, gameResult, executedEndOfRoundEffects) =
                _checkForKnockoutAndAdvanceIfNeeded(battleKey, priorityPlayerIndex, rng);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            } else if (executedEndOfRoundEffects) {
                state.playerSwitchForTurnFlag = playerSwitchForTurnFlag;
                state.turnId += 1;
                return;
            }

            // Execute non-priority player's move
            _handlePlayerMove(battleKey, rng, otherPlayerIndex);

            // Check for game over
            gameResult = battle.validator.validateGameOver(battleKey, priorityPlayerIndex);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            }

            // Afterwards, check again for knockout or subsequent game over for either player after handling move
            (playerSwitchForTurnFlag, gameResult, executedEndOfRoundEffects) =
                _checkForKnockoutAndAdvanceIfNeeded(battleKey, priorityPlayerIndex, rng);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            } else if (executedEndOfRoundEffects) {
                state.playerSwitchForTurnFlag = playerSwitchForTurnFlag;
                state.turnId += 1;
                return;
            }

            // If we don't need to force a switch, and it's not game over:
            // Run effects for global, p0 active mon, and p1 active mon
            // Then check for game over / knockout again
            _runEffects(battleKey, rng, 0, Round.End);
            _runEffects(battleKey, rng, 1, Round.End);
            _runEffects(battleKey, rng, 2, Round.End);

            // One last time, check again for knockout or subsequent game over for either player after handling effects
            (playerSwitchForTurnFlag, gameResult, executedEndOfRoundEffects) =
                _checkForKnockoutAndAdvanceIfNeeded(battleKey, priorityPlayerIndex, rng);
            if (gameResult != address(0)) {
                state.winner = gameResult;
                return;
            } else if (executedEndOfRoundEffects) {
                state.playerSwitchForTurnFlag = playerSwitchForTurnFlag;
                state.turnId += 1;
                return;
            }

            // Progress turn index
            state.turnId += 1;
        }
    }

    function _checkForKnockoutAndAdvanceIfNeeded(bytes32 battleKey, uint256 priorityPlayerIndex, uint256 rng)
        internal
        returns (uint256 playerSwitchForTurnFlag, address gameResult, bool executedRoundEndEffects)
    {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 otherPlayerIndex = (priorityPlayerIndex + 1) % 2;

        bool isPriorityPlayerActiveMonKnockedOut =
            state.monStates[priorityPlayerIndex][state.activeMonIndex[priorityPlayerIndex]].isKnockedOut;
        bool isNonPriorityPlayerActiveMonKnockedOut =
            state.monStates[otherPlayerIndex][state.activeMonIndex[otherPlayerIndex]].isKnockedOut;

        // IF there is a knockout, then continue to run end of round effects and then recheck knockout flags
        if (isPriorityPlayerActiveMonKnockedOut || isNonPriorityPlayerActiveMonKnockedOut) {
            if (isPriorityPlayerActiveMonKnockedOut && !isNonPriorityPlayerActiveMonKnockedOut) {
                // Run end of round effects for non priority active mon
                _runEffects(battleKey, rng, 2, Round.End);
                _runEffects(battleKey, rng, otherPlayerIndex, Round.End);
                executedRoundEndEffects = true;
            } else if (!isPriorityPlayerActiveMonKnockedOut && isNonPriorityPlayerActiveMonKnockedOut) {
                // Run end of round effects for non priority active mon
                _runEffects(battleKey, rng, 2, Round.End);
                _runEffects(battleKey, rng, priorityPlayerIndex, Round.End);
                executedRoundEndEffects = true;
            }

            // In both cases, we now recheck the knockout flags after updating end of round effects
            isPriorityPlayerActiveMonKnockedOut =
                state.monStates[priorityPlayerIndex][state.activeMonIndex[priorityPlayerIndex]].isKnockedOut;
            isNonPriorityPlayerActiveMonKnockedOut =
                state.monStates[otherPlayerIndex][state.activeMonIndex[otherPlayerIndex]].isKnockedOut;

            // If a both mons are KO'ed, we have to first check for game over
            // Either way, if both mons are KO'ed, we don't set priorityPlayerIndex and instead rely on validateMove for the next round
            // Otherwise, it's still the case that only one of the active mons is KO'ed, so we set priorityPlayerIndex
            if (isPriorityPlayerActiveMonKnockedOut && isNonPriorityPlayerActiveMonKnockedOut) {
                gameResult = battle.validator.validateGameOver(battleKey, priorityPlayerIndex);
            }
            // If there was still just one knockout, we set the correct playerSwitchForTurnFlag value (shift player index up by 1)
            if (isPriorityPlayerActiveMonKnockedOut) {
                playerSwitchForTurnFlag = priorityPlayerIndex + 1;
            } else if (isNonPriorityPlayerActiveMonKnockedOut) {
                playerSwitchForTurnFlag = otherPlayerIndex + 1;
            }
        }
    }

    function _handleSwitch(bytes32 battleKey, uint256 playerIndex) internal {
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove storage move = state.moveHistory[playerIndex][turnId];
        uint256 monToSwitchIndex = abi.decode(move.extraData, (uint256));
        MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
        IEffect[] storage effects = currentMonState.targetedEffects;
        bytes[] storage extraData = currentMonState.extraDataForTargetedEffects;
        uint256 i = 0;

        // Go through each effect to see if it should be cleared after a switch,
        // If so, remove the effect and the extra data
        while (i < effects.length) {
            if (effects[i].shouldClearAfterMonSwitch()) {
                // effects and extra data should be synced
                effects[i] = effects[effects.length - 1];
                effects.pop();

                extraData[i] = extraData[effects.length - 1];
                extraData.pop();
            } else {
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

    function _handlePlayerMove(bytes32 battleKey, uint256 rng, uint256 playerIndex) internal {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove storage move = battleStates[battleKey].moveHistory[playerIndex][turnId];
        IMoveSet moveSet = battle.teams[playerIndex][state.activeMonIndex[playerIndex]].moves[move.moveIndex];

        // handle a switch, a no-op, or execute the moveset
        if (move.moveIndex == SWITCH_MOVE_INDEX) {
            _handleSwitch(battleKey, playerIndex);
        } else if (move.moveIndex == NO_OP_MOVE_INDEX) {
            // do nothing (e.g. just recover stamina)
        }
        // Execute the move and then set updated state, active mons, and effects/data
        else {
            (
                MonState[][] memory monStates,
                uint256[] memory activeMons,
                IEffect[][] memory newEffects,
                bytes[][] memory extraDataForEffects,
                bytes32 globalK,
                bytes32 globalV
            ) = moveSet.move(battleKey, playerIndex, move.extraData, rng);

            // Assign the new mon states to storage
            state.monStates = monStates;

            // Assign the new active mon IDs to storage
            state.activeMonIndex = activeMons;

            // Assign new effects (if any)
            if (newEffects.length > 0) {
                for (uint256 targetIndex; targetIndex < 3; ++targetIndex) {
                    IEffect[] storage effects;
                    bytes[] storage extraData;

                    // Grab storage reference to the correct effects/extra data array
                    if (targetIndex == 2) {
                        effects = state.globalEffects;
                        extraData = state.extraDataForGlobalEffects;
                    } else {
                        effects = state.monStates[targetIndex][state.activeMonIndex[targetIndex]].targetedEffects;
                        extraData =
                            state.monStates[targetIndex][state.activeMonIndex[targetIndex]].extraDataForTargetedEffects;
                    }

                    // Attach each new effect if it is valid to register
                    if (newEffects[targetIndex].length > 0) {
                        for (uint256 j; j < newEffects[targetIndex].length; ++j) {
                            if (newEffects[targetIndex][j].isValidToRegister(battleKey, targetIndex)) {
                                effects.push(newEffects[targetIndex][j]);
                                extraData.push(extraDataForEffects[targetIndex][j]);
                            }
                        }
                    }
                }
            }

            // Assign the global key value (if any)
            if (globalK != "") {
                globalKV[battleKey][globalK] = globalV;
            }
        }
    }

    // Iterates through all effects and handles them
    // Removes them if necessary, and also updates extra data if needed
    function _runEffects(bytes32 battleKey, uint256 rng, uint256 targetIndex, Round round) internal {
        BattleState storage state = battleStates[battleKey];
        IEffect[] storage effects;
        bytes[] storage extraData;

        // Switch between global or targeted effects array
        if (targetIndex == 2) {
            effects = state.globalEffects;
            extraData = state.extraDataForGlobalEffects;
        } else {
            effects = state.monStates[targetIndex][state.activeMonIndex[targetIndex]].targetedEffects;
            extraData = state.monStates[targetIndex][state.activeMonIndex[targetIndex]].extraDataForTargetedEffects;
        }

        uint256 i;
        while (i < effects.length) {
            if (effects[i].shouldRunAtRound(round)) {
                (MonState[][] memory updatedMonStates, bytes memory updatedExtraData, bool removeAfterHandle) =
                    effects[i].runEffect(battleKey, rng, extraData[i], 0);

                // If we remove the effect after doing it, then we clear and update the array/extra data
                if (removeAfterHandle) {
                    effects[i] = effects[effects.length - 1];
                    effects.pop();

                    extraData[i] = extraData[effects.length - 1];
                    extraData.pop();
                }
                // Otherwise, we update the extra data if e.g. the effect needs to modify state
                else {
                    extraData[i] = updatedExtraData;
                }

                // Either way, in both cases, we then update the mon states
                state.monStates = updatedMonStates;
            } else {
                ++i;
            }
        }
    }

    function end(bytes32 battleKey) external {
        BattleState storage state = battleStates[battleKey];
        Battle storage battle = battles[battleKey];
        if (state.winner != address(0)) {
            revert GameAlreadyOver();
        }
        for (uint i; i < 2; ++i) {
            address afkResult = battle.validator.validateTimeout(battleKey, i);
            if (afkResult != address(0)) {
                state.winner = afkResult;
                return;
            }
        }
    }
}

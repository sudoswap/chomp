// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";

import "./Enums.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";

contract Engine is IEngine {
    uint256 constant SWITCH_PRIORITY = 6;

    bytes32 battleKeyForWrite;
    mapping(bytes32 => uint256) public pairHashNonces;
    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;
    mapping(bytes32 battleKey => mapping(bytes32 => bytes32)) public globalKV;

    error NoWriteAllowed();
    error NotP0OrP1();
    error AlreadyCommited();
    error RevealBeforeOtherCommit();
    error WrongTurnId();
    error WrongPreimage();
    error InvalidMove(address player);
    error OnlyP0Allowed();
    error OnlyP1Allowed();
    error InvalidBattleConfig();
    error GameAlreadyOver();

    /**
     * - Getters to simplify read access for other components
     */
    function getBattle(bytes32 battleKey) external view returns (Battle memory) {
        return battles[battleKey];
    }

    function getTeamsForBattle(bytes32 battleKey) external view returns (Mon[][] memory) {
        return battles[battleKey].teams;
    }

    function getPlayersForBattle(bytes32 battleKey) external view returns (address[] memory) {
        address[] memory players = new address[](2);
        players[0] = battles[battleKey].p0;
        players[1] = battles[battleKey].p1;
        return players;
    }

    function getBattleState(bytes32 battleKey) external view returns (BattleState memory) {
        return battleStates[battleKey];
    }

    function getMoveHistoryForBattleState(bytes32 battleKey) external view returns (RevealedMove[][] memory) {
        return battleStates[battleKey].moveHistory;
    }

    function getMonStatesForBattleState(bytes32 battleKey) external view returns (MonState[][] memory) {
        return battleStates[battleKey].monStates;
    }

    function getTurnIdForBattleState(bytes32 battleKey) external view returns (uint256) {
        return battleStates[battleKey].turnId;
    }

    function getActiveMonIndexForBattleState(bytes32 battleKey) external view returns (uint256[] memory) {
        return battleStates[battleKey].activeMonIndex;
    }

    function getPlayerSwitchForTurnFlagForBattleState(bytes32 battleKey) external view returns (uint256) {
        return battleStates[battleKey].playerSwitchForTurnFlag;
    }

    function getGlobalKV(bytes32 battleKey, bytes32 key) external view returns (bytes32) {
        return globalKV[battleKey][key];
    }

    function getCommitment(bytes32 battleKey, address player) external view returns (Commitment memory) {
        return commitments[battleKey][player];
    }

    /**
     * - Write functions for MonState, Effects, and GlobalKV
     */

    // Set mon state for a specific player for a specific variable in mon state for a specific mon
    function setMonState(uint256 playerIndex, uint256 monIndex, MonStateIndexName stateVarIndex, int256 value)
        external
    {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        BattleState storage state = battleStates[battleKey];
        MonState storage monState = state.monStates[playerIndex][monIndex];
        if (stateVarIndex == MonStateIndexName.HP) {
            monState.hpDelta += value;
        } else if (stateVarIndex == MonStateIndexName.Stamina) {
            monState.staminaDelta += value;
        } else if (stateVarIndex == MonStateIndexName.Speed) {
            monState.speedDelta += value;
        } else if (stateVarIndex == MonStateIndexName.Attack) {
            monState.attackDelta += value;
        } else if (stateVarIndex == MonStateIndexName.Defence) {
            monState.defenceDelta += value;
        } else if (stateVarIndex == MonStateIndexName.SpecialAttack) {
            monState.specialAttackDelta += value;
        } else if (stateVarIndex == MonStateIndexName.SpecialDefence) {
            monState.specialDefenceDelta += value;
        } else if (stateVarIndex == MonStateIndexName.IsKnockedOut) {
            monState.isKnockedOut = (value % 2) == 1;
        } else if (stateVarIndex == MonStateIndexName.ShouldSkipTurn) {
            monState.shouldSkipTurn = (value % 2) == 1;
        }
    }

    /**
     * - Core game functions
     */
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

        // Get the global effects and data to start the game if any
        if (address(battle.ruleset) != address(0)) {
            (IEffect[] memory effects, bytes[] memory data) = battle.ruleset.getInitialGlobalEffects();
            if (effects.length > 0) {
                battleStates[battleKey].globalEffects = effects;
                battleStates[battleKey].extraDataForGlobalEffects = data;
            }
        }

        // Set flag to be 2 which means both players act
        battleStates[battleKey].playerSwitchForTurnFlag = 2;

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
        if (state.playerSwitchForTurnFlag == 0 && msg.sender != battle.p0) {
            revert OnlyP0Allowed();
        } else if (state.playerSwitchForTurnFlag == 1 && msg.sender != battle.p1) {
            revert OnlyP1Allowed();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIndex, bytes32 salt, bytes calldata extraData) external {
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

        uint256 currentPlayerIndex;
        uint256 otherPlayerIndex;
        address otherPlayer;

        // Set current and other player based on the caller
        if (msg.sender == battle.p0) {
            otherPlayer = battle.p1;
            otherPlayerIndex = 1;
        } else {
            otherPlayer = battle.p0;
            currentPlayerIndex = 1;
        }

        // ensure reveal happens after opponent commits
        // (only if it is a turn where both players need to select an action)
        if (state.playerSwitchForTurnFlag == 2) {
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
            revert InvalidMove(msg.sender);
        }

        // store revealed move and extra data for the current player
        battleStates[battleKey].moveHistory[currentPlayerIndex].push(
            RevealedMove({moveIndex: moveIndex, salt: salt, extraData: extraData})
        );

        // store empty move for other player if it's a turn where only a single player has to make a move
        if (state.playerSwitchForTurnFlag == 0 || state.playerSwitchForTurnFlag == 1) {
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
        if (state.playerSwitchForTurnFlag == 0 || state.playerSwitchForTurnFlag == 1) {
            // Push 0 to rng stream as only single player is switching, to keep in line with turnId
            state.pRNGStream.push(0);

            // Get the player index that needs to switch for this turn
            uint256 playerIndex = state.playerSwitchForTurnFlag;
            RevealedMove memory move = battleStates[battleKey].moveHistory[playerIndex][turnId];

            // Handle switching as a privileged move
            if (move.moveIndex == SWITCH_MOVE_INDEX) {
                _handleSwitch(battleKey, playerIndex);
            }

            // Progress turn index
            state.turnId += 1;

            // Return control flow to both players
            state.playerSwitchForTurnFlag = 2;
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
            uint256 rng = battle.rngOracle.getRNG(p0Move.salt, p1Move.salt);
            state.pRNGStream.push(rng);

            // Calculate the priority and non-priority player indices
            uint256 priorityPlayerIndex = _computePriorityPlayerIndex(battleKey, rng);
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

    function end(bytes32 battleKey) external {
        BattleState storage state = battleStates[battleKey];
        Battle storage battle = battles[battleKey];
        if (state.winner != address(0)) {
            revert GameAlreadyOver();
        }
        for (uint256 i; i < 2; ++i) {
            address afkResult = battle.validator.validateTimeout(battleKey, i);
            if (afkResult != address(0)) {
                state.winner = afkResult;
                return;
            }
        }
    }

    /**
     * - Internal helper functions for execute()
     */
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
                playerSwitchForTurnFlag = priorityPlayerIndex;
            } else if (isNonPriorityPlayerActiveMonKnockedOut) {
                playerSwitchForTurnFlag = otherPlayerIndex;
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

        // If the current mon is not knocked out:
        // Go through each effect to see if it should be cleared after a switch,
        // If so, remove the effect and the extra data
        if (!currentMonState.isKnockedOut) {
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
            currentMonState.isKnockedOut = false;
        }

        // Update to new active mon (we assume validate already resolved and gives us a valid target)
        state.activeMonIndex[playerIndex] = monToSwitchIndex;
    }

    function _handlePlayerMove(bytes32 battleKey, uint256 rng, uint256 playerIndex) internal {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove storage move = battleStates[battleKey].moveHistory[playerIndex][turnId];

        {
            // Handle shouldSkipTurn flag first and toggle it off if set
            MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
            if (currentMonState.shouldSkipTurn) {
                currentMonState.shouldSkipTurn = false;
                return;
            }
        }

        // Handle a switch or a no-op
        // otherwise, execute the moveset
        if (move.moveIndex == SWITCH_MOVE_INDEX) {
            _handleSwitch(battleKey, playerIndex);
        } else if (move.moveIndex == NO_OP_MOVE_INDEX) {
            // do nothing (e.g. just recover stamina)
        }
        // Execute the move and then set updated state, active mons, and effects/data
        else {
            // Set the battleKey to allow for writes
            battleKeyForWrite = battleKey;

            // Run the move and allow for writes
            IMoveSet moveSet = battle.teams[playerIndex][state.activeMonIndex[playerIndex]].moves[move.moveIndex];
            moveSet.move(battleKey, playerIndex, move.extraData, rng);

            /*
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
            */

            // Set the battleKey back to 0 to prevent writes
            battleKeyForWrite = bytes32(0);
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
                // We run the effect
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
                    ++i;
                }

                // Either way, in both cases, we then update the mon states
                state.monStates = updatedMonStates;
            } else {
                ++i;
            }
        }
    }

    function _computePriorityPlayerIndex(bytes32 battleKey, uint256 rng) internal view returns (uint256) {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        RevealedMove memory p0Move = state.moveHistory[0][state.turnId];
        RevealedMove memory p1Move = state.moveHistory[1][state.turnId];

        uint256 p0Priority;
        uint256 p1Priority;

        // Call the move for its priority, unless it's the switch or no op move index
        {
            if (p0Move.moveIndex == SWITCH_MOVE_INDEX || p0Move.moveIndex == NO_OP_MOVE_INDEX) {
                p0Priority = SWITCH_PRIORITY;
            } else {
                IMoveSet p0MoveSet = battle.teams[0][state.activeMonIndex[0]].moves[p0Move.moveIndex];
                p0Priority = p0MoveSet.priority(battleKey);
            }

            if (p1Move.moveIndex == SWITCH_MOVE_INDEX || p1Move.moveIndex == NO_OP_MOVE_INDEX) {
                p1Priority = SWITCH_PRIORITY;
            } else {
                IMoveSet p1MoveSet = battle.teams[1][state.activeMonIndex[1]].moves[p1Move.moveIndex];
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
            uint256 p0MonSpeed = uint256(
                int256(battle.teams[0][state.activeMonIndex[0]].speed)
                    + state.monStates[0][state.activeMonIndex[0]].speedDelta
            );
            uint256 p1MonSpeed = uint256(
                int256(battle.teams[1][state.activeMonIndex[1]].speed)
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
}

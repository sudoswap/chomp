// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";

import "./Enums.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";

contract Engine is IEngine {
    uint256 constant SWITCH_PRIORITY = 6;

    bytes32 public battleKeyForWrite;
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
    function updateMonState(uint256 playerIndex, uint256 monIndex, MonStateIndexName stateVarIndex, int32 valueToAdd)
        external
    {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        BattleState storage state = battleStates[battleKey];
        MonState storage monState = state.monStates[playerIndex][monIndex];
        if (stateVarIndex == MonStateIndexName.Hp) {
            monState.hpDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.Stamina) {
            monState.staminaDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.Speed) {
            monState.speedDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.Attack) {
            monState.attackDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.Defence) {
            monState.defenceDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.SpecialAttack) {
            monState.specialAttackDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.SpecialDefence) {
            monState.specialDefenceDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.IsKnockedOut) {
            monState.isKnockedOut = (valueToAdd % 2) == 1;
        } else if (stateVarIndex == MonStateIndexName.ShouldSkipTurn) {
            monState.shouldSkipTurn = (valueToAdd % 2) == 1;
        }
    }

    function addEffect(uint256 targetIndex, uint256 monIndex, IEffect effect, bytes memory extraData) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        if (effect.shouldApply(targetIndex, monIndex, extraData)) {
            BattleState storage state = battleStates[battleKey];
            if (targetIndex == 2) {
                state.globalEffects.push(effect);
                state.extraDataForGlobalEffects.push(extraData);
            } else {
                state.monStates[targetIndex][monIndex].targetedEffects.push(effect);
                state.monStates[targetIndex][monIndex].extraDataForTargetedEffects.push(extraData);
            }
            // Check if we have to run an onApply state update
            if (effect.shouldRunAtStep(EffectStep.OnApply)) {
                // If so, we run the effect first, and get updated extraData if necessary
                extraData = effect.onApply(targetIndex, monIndex, extraData);
            }
        }
    }

    function removeEffect(uint256 targetIndex, uint256 monIndex, uint256 indexToRemove) public {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        BattleState storage state = battleStates[battleKey];

        // Set the appropriate effects/extra data array from storage
        IEffect[] storage effects;
        bytes[] storage extraData;
        if (targetIndex == 2) {
            effects = state.globalEffects;
            extraData = state.extraDataForGlobalEffects;
        } else {
            effects = state.monStates[targetIndex][monIndex].targetedEffects;
            extraData = state.monStates[targetIndex][monIndex].extraDataForTargetedEffects;
        }

        // One last check to see if we should run the final lifecycle hook
        IEffect effect = effects[indexToRemove];
        if (effect.shouldRunAtStep(EffectStep.OnRemove)) {
            effect.onRemove(extraData[indexToRemove]);
        }

        // Remove effects and extra data
        uint256 numEffects = effects.length;
        effects[indexToRemove] = effects[numEffects - 1];
        effects.pop();
        extraData[indexToRemove] = extraData[numEffects - 1];
        extraData.pop();
    }

    function setGlobalKV(bytes32 key, bytes32 value) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        globalKV[battleKey][key] = value;
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
        if (!battle.validator.validatePlayerMove(battleKey, moveIndex, currentPlayerIndex, extraData)) {
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
            uint256 rngForSoloTurn = 0;

            // Push 0 to rng stream as only single player is switching, to keep in line with turnId
            state.pRNGStream.push(rngForSoloTurn);

            // Get the player index that needs to switch for this turn
            uint256 playerIndex = state.playerSwitchForTurnFlag;

            // Run the move (trust that the validator only lets valid single player moves happen as a switch action)
            _handlePlayerMove(battleKey, rngForSoloTurn, playerIndex);

            uint256 playerSwitchForTurnFlag = 2;
            bool isGameOver;

            // Check if either player's mon has been KO'ed, and if we need to force a switch for next turn
            (playerSwitchForTurnFlag,,, isGameOver) = _checkForGameOverOrKO(battleKey, playerIndex);
            if (isGameOver) return;

            // Progress turn index
            state.turnId += 1;

            // Return control flow to both players
            state.playerSwitchForTurnFlag = playerSwitchForTurnFlag;
        }
        // Otherwise, we need to run priority calculations and update the game state for both players
        /*
            Flow of battle:
            - Grab moves and calculate pseudo RNG
            - Determine priority player
            - Run round start global effects
            - Run round start targeted effects for p0 and p1
            - Execute priority player's move
            - Check for game over/KO (for switch flag)
                - If game over, just return
            - If KO, skip non priority player's move
            - Execute non priority player's move
            - Check for game over/KO (for switch flag)
                - If game over, just return
            - Run global end of turn effects
            - Check for game over/KO (for switch flag)
                - If game over, just return
            - If not KOed, run the priority player's targeted effects
            - Check for game over/KO (for switch flag)
                - If game over, just return
            - If not KOed, run the non priority player's targeted effects
            - Check for game over/KO (for switch flag)
                - If game over, just return
            - Progress turn index
            - Set player switch for turn flag
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

            // Run beginning of round effects all at once to start
            // NOTE: We assume these cannot KO
            _runEffects(battleKey, rng, 2, 2, EffectStep.RoundStart);
            _runEffects(battleKey, rng, priorityPlayerIndex, priorityPlayerIndex, EffectStep.RoundStart);
            _runEffects(battleKey, rng, otherPlayerIndex, otherPlayerIndex, EffectStep.RoundStart);

            // Execute priority player's move
            _handlePlayerMove(battleKey, rng, priorityPlayerIndex);

            // Initialize variables for checking game state
            uint256 playerSwitchForTurnFlag;
            bool isPriorityPlayerMonKOed;
            bool isNonPriorityPlayerMonKOed;
            bool isGameOver;

            // Check if either player's mon has been KO'ed, and if we need to force a switch for next turn
            (playerSwitchForTurnFlag, isPriorityPlayerMonKOed, isNonPriorityPlayerMonKOed, isGameOver) =
                _checkForGameOverOrKO(battleKey, priorityPlayerIndex);
            if (isGameOver) return;

            // If both mons are not KO'ed, then run the non priority player's move
            if (!isNonPriorityPlayerMonKOed && !isPriorityPlayerMonKOed) {
                _handlePlayerMove(battleKey, rng, otherPlayerIndex);
            }

            // Check for game over and/or KOs
            (playerSwitchForTurnFlag, isPriorityPlayerMonKOed, isNonPriorityPlayerMonKOed, isGameOver) =
                _checkForGameOverOrKO(battleKey, priorityPlayerIndex);
            if (isGameOver) return;

            // Always run global effects at the end of the round
            _runEffects(battleKey, rng, 2, 2, EffectStep.RoundEnd);

            // Check for game over and/or KOs
            (playerSwitchForTurnFlag, isPriorityPlayerMonKOed, isNonPriorityPlayerMonKOed, isGameOver) =
                _checkForGameOverOrKO(battleKey, priorityPlayerIndex);
            if (isGameOver) return;

            // If priority mon is not KOed, run effects for the priority mon
            if (!isPriorityPlayerMonKOed) {
                _runEffects(battleKey, rng, priorityPlayerIndex, priorityPlayerIndex, EffectStep.RoundEnd);
            }

            // Check for game over and/or KOs
            (playerSwitchForTurnFlag, isPriorityPlayerMonKOed, isNonPriorityPlayerMonKOed, isGameOver) =
                _checkForGameOverOrKO(battleKey, priorityPlayerIndex);
            if (isGameOver) return;

            // If non priority mon is not KOed, run effects for the non priority mon
            if (!isNonPriorityPlayerMonKOed) {
                _runEffects(battleKey, rng, otherPlayerIndex, otherPlayerIndex, EffectStep.RoundEnd);
            }

            // Check for game over and/or KOs
            (playerSwitchForTurnFlag, isPriorityPlayerMonKOed, isNonPriorityPlayerMonKOed, isGameOver) =
                _checkForGameOverOrKO(battleKey, priorityPlayerIndex);
            if (isGameOver) return;

            // Progress turn index and finally set the player switch for turn flag
            state.turnId += 1;
            state.playerSwitchForTurnFlag = playerSwitchForTurnFlag;
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
    function _checkForGameOverOrKO(bytes32 battleKey, uint256 priorityPlayerIndex)
        internal
        returns (
            uint256 playerSwitchForTurnFlag,
            bool isPriorityPlayerActiveMonKnockedOut,
            bool isNonPriorityPlayerActiveMonKnockedOut,
            bool isGameOver
        )
    {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 otherPlayerIndex = (priorityPlayerIndex + 1) % 2;
        address gameResult = battle.validator.validateGameOver(battleKey, priorityPlayerIndex);
        if (gameResult != address(0)) {
            state.winner = gameResult;
            isGameOver = true;
        } else {
            // Always set default switch to be 2 (allow both players to make a move)
            playerSwitchForTurnFlag = 2;

            isPriorityPlayerActiveMonKnockedOut =
                state.monStates[priorityPlayerIndex][state.activeMonIndex[priorityPlayerIndex]].isKnockedOut;

            isNonPriorityPlayerActiveMonKnockedOut =
                state.monStates[otherPlayerIndex][state.activeMonIndex[otherPlayerIndex]].isKnockedOut;

            // If the priority player mon is KO'ed, then next turn we tenatively set it to be just the other player
            if (isPriorityPlayerActiveMonKnockedOut && !isNonPriorityPlayerActiveMonKnockedOut) {
                playerSwitchForTurnFlag = priorityPlayerIndex;
            }

            // If the non priority player mon is KO'ed, then next turn we tenatively set it to be just the priority player
            if (!isPriorityPlayerActiveMonKnockedOut && isNonPriorityPlayerActiveMonKnockedOut) {
                playerSwitchForTurnFlag = otherPlayerIndex;
            }
        }
    }

    function _handleSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monToSwitchIndex) internal {
        BattleState storage state = battleStates[battleKey];
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

        // Run onMonSwitchIn hook for global effects
        _runEffects(battleKey, state.pRNGStream[state.pRNGStream.length - 1], 2, playerIndex, EffectStep.OnMonSwitchIn);

        // Run ability for the newly switched in mon
        Mon memory mon = battles[battleKey].teams[playerIndex][monToSwitchIndex];
        if (address(mon.ability) != address(0)) {
            mon.ability.activateOnSwitch(battleKey, playerIndex, monToSwitchIndex);
        }

        // NOTE: We will check for game over after the switch in the engine for two player turns, so we don't do it here
    }

    function _handlePlayerMove(bytes32 battleKey, uint256 rng, uint256 playerIndex) internal {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        uint256 turnId = state.turnId;
        RevealedMove storage move = battleStates[battleKey].moveHistory[playerIndex][turnId];

        // Handle shouldSkipTurn flag first and toggle it off if set
        MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
        if (currentMonState.shouldSkipTurn) {
            currentMonState.shouldSkipTurn = false;
            return;
        }

        // Handle a switch or a no-op
        // otherwise, execute the moveset
        if (move.moveIndex == SWITCH_MOVE_INDEX) {

            // Set the key to allow for writes
            battleKeyForWrite = battleKey;

            // Handle the switch
            _handleSwitch(battleKey, playerIndex, abi.decode(move.extraData, (uint256)));

            // Set the battleKey back to 0 to prevent writes
            battleKeyForWrite = bytes32(0);
            
        } else if (move.moveIndex == NO_OP_MOVE_INDEX) {
            // do nothing (e.g. just recover stamina)
            return;
        }
        // Execute the move and then set updated state, active mons, and effects/data
        else {
            // Call validateSpecificMoveSelection again from the validator to ensure that it is still valid to execute
            // If not, then we just return early
            // Handles cases where e.g. some condition outside of the player's control leads to an invalid move
            if (!battle.validator.validateSpecificMoveSelection(battleKey, move.moveIndex, playerIndex, move.extraData))
            {
                return;
            }

            IMoveSet moveSet = battle.teams[playerIndex][state.activeMonIndex[playerIndex]].moves[move.moveIndex];

            // Update the mon state directly to account for the stamina cost of the move
            state.monStates[playerIndex][state.activeMonIndex[playerIndex]].staminaDelta -=
                int32(moveSet.stamina(battleKey));

            // Set the key to allow for writes
            battleKeyForWrite = battleKey;

            // Run the move and see if we need to handle a switch
            (bool doSwitch) = moveSet.move(battleKey, playerIndex, move.extraData, rng);

            // If we need to a switch, check to see what we switch
            if (doSwitch) {
                (uint256 switchFlag, uint256 monToSwitchIndex) =
                    moveSet.postMoveSwitch(battleKey, playerIndex, move.extraData);
                _handleSwitch(battleKey, switchFlag, monToSwitchIndex);
            }

            // Set the battleKey back to 0 to prevent writes
            battleKeyForWrite = bytes32(0);
        }
    }

    function _runEffects(bytes32 battleKey, uint256 rng, uint256 effectIndex, uint256 playerIndex, EffectStep round) internal {
        BattleState storage state = battleStates[battleKey];
        IEffect[] storage effects;
        bytes[] storage extraData;
        // Switch between global or targeted effects array
        if (effectIndex == 2) {
            effects = state.globalEffects;
            extraData = state.extraDataForGlobalEffects;
        } else {
            effects = state.monStates[effectIndex][state.activeMonIndex[effectIndex]].targetedEffects;
            extraData = state.monStates[effectIndex][state.activeMonIndex[effectIndex]].extraDataForTargetedEffects;
        }

        uint256 i;
        while (i < effects.length) {
            if (effects[i].shouldRunAtStep(round)) {
                // Set the battleKey to allow for writes
                battleKeyForWrite = battleKey;

                // Run the effects (depending on which round stage we are on)
                bytes memory updatedExtraData;
                bool removeAfterRun;
                if (round == EffectStep.RoundStart) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onRoundStart(battleKey, rng, extraData[i], effectIndex);
                } else if (round == EffectStep.RoundEnd) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onRoundEnd(battleKey, rng, extraData[i], effectIndex);
                } else if (round == EffectStep.OnMonSwitchIn) {
                    // NOTE: We pass in the playerIndex here, not the effectIndex so that we know which active mon to apply effects to
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onMonSwitchIn(battleKey, rng, extraData[i], playerIndex);
                }

                // If we remove the effect after doing it, then we clear and update the array/extra data
                if (removeAfterRun) {
                    uint256 monIndex = 0;
                    if (effectIndex != 2) {
                        monIndex = state.activeMonIndex[effectIndex];
                    }
                    removeEffect(effectIndex, monIndex, i);
                }
                // Otherwise, we update the extra data if e.g. the effect needs to modify its own storage
                else {
                    extraData[i] = updatedExtraData;
                    ++i;
                }

                // Unset the battleKey to lock writes
                battleKeyForWrite = bytes32(0);
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
            uint32 p0MonSpeed = uint32(
                int32(battle.teams[0][state.activeMonIndex[0]].speed)
                    + state.monStates[0][state.activeMonIndex[0]].speedDelta
            );
            uint32 p1MonSpeed = uint32(
                int32(battle.teams[1][state.activeMonIndex[1]].speed)
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

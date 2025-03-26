// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";

import "./Enums.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IFastCommitManager} from "./IFastCommitManager.sol";
import {IEngine} from "./IEngine.sol";

contract Engine is IEngine {

    // Public state variables
    bytes32 public transient battleKeyForWrite; // intended to be used during call stack by other contracts
    IFastCommitManager public commitManager; // technically immutable but circular dependency
    mapping(bytes32 => uint256) public pairHashNonces; // intended to be read by anyone

    // Private state variables (battles and battleStates values are granularly accessible via getters)
    mapping(bytes32 battleKey => Battle) private battles;
    mapping(bytes32 battleKey => BattleState) private battleStates;
    mapping(bytes32 battleKey => mapping(bytes32 => bytes32)) private globalKV;
    uint256 transient private currentStep; // Used to bubble up step data for events
    int32 transient private damageDealt; // Used to provide access to onAfterDamage hook for effects

    // Errors
    error NoWriteAllowed();
    error WrongCaller();
    error CommitManagerAlreadySet();
    error BattleChangedBeforeAcceptance();
    error InvalidP0TeamHash();
    error InvalidBattleConfig();
    error GameAlreadyOver();

    // Events
    event BattleProposal(address indexed p1, address p0, bytes32 battleKey);
    event BattleAcceptance(bytes32 indexed battleKey, uint256 p1TeamIndex);
    event BattleStart(bytes32 indexed battleKey, uint256 p0TeamIndex, address p0, address p1);
    event EngineExecute(
        bytes32 indexed battleKey, uint256 turnId, uint256 playerSwitchForTurnFlag, uint256 priorityPlayerIndex
    );
    event MonSwitch(bytes32 indexed battleKey, uint256 playerIndex, uint256 newMonIndex, address source);
    event MonStateUpdate(
        bytes32 indexed battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        uint256 stateVarIndex,
        int32 valueDelta,
        address source,
        uint256 step
    );
    event MonMove(bytes32 indexed battleKey, uint256 playerIndex, uint256 monIndex, uint256 moveIndex, bytes extraData);
    event DamageDeal(
        bytes32 indexed battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        int32 damageDealt,
        address source,
        uint256 step
    );
    event EffectAdd(
        bytes32 indexed battleKey,
        uint256 effectIndex,
        uint256 monIndex,
        address effectAddress,
        bytes extraData,
        address source,
        uint256 step
    );
    event EffectRemove(
        bytes32 indexed battleKey,
        uint256 effectIndex,
        uint256 monIndex,
        address effectAddress,
        address source,
        uint256 step
    );
    event BattleComplete(bytes32 indexed battleKey, address winner);

    /**
     * - Core game functions
     */
    function proposeBattle(StartBattleArgs memory args) external returns (bytes32) {
        // Caller must be p0
        if (msg.sender != args.p0) {
            revert WrongCaller();
        }

        // Compute the battle key and pair hash
        (bytes32 battleKey, bytes32 pairHash) = _computeBattleKey(args);
        Battle storage existingBattle = battles[battleKey];

        // Update nonce if the previous battle was past being proposed (i.e. accepted/started/ended) and update battle key
        if (existingBattle.status != BattleProposalStatus.Proposed) {
            pairHashNonces[pairHash] += 1;
            (battleKey,) = _computeBattleKey(args);
        }

        // Initialize empty teams to start
        Mon[][] memory teams = new Mon[][](2);

        // Store the battle
        battles[battleKey] = Battle({
            p0: args.p0,
            p1: args.p1,
            validator: args.validator,
            rngOracle: args.rngOracle,
            ruleset: args.ruleset,
            status: BattleProposalStatus.Proposed,
            teams: teams,
            teamRegistry: args.teamRegistry,
            p0TeamHash: args.p0TeamHash,
            p1TeamIndex: 0 // placeholder value until p1 responds
        });
        emit BattleProposal(args.p1, msg.sender, battleKey);
        return battleKey;
    }

    function acceptBattle(bytes32 battleKey, uint256 p1TeamIndex, bytes32 battleIntegrityHash) external {
        Battle storage battle = battles[battleKey];
        if (msg.sender != battle.p1) {
            revert WrongCaller();
        }

        // Set the battle status to be accepted
        battle.status = BattleProposalStatus.Accepted;

        // Set the team for p1
        battle.teams[1] = battle.teamRegistry.getTeam(msg.sender, p1TeamIndex);

        // Store the p1 team index (we likely are not going to go over, this packs things nicely)
        battle.p1TeamIndex = uint96(p1TeamIndex);

        // Validate the integrity hash of the battle parameters
        if (
            battleIntegrityHash
                != keccak256(
                    abi.encodePacked(
                        battle.validator, battle.rngOracle, battle.ruleset, battle.teamRegistry, battle.p0TeamHash
                    )
                )
        ) {
            revert BattleChangedBeforeAcceptance();
        }

        emit BattleAcceptance(battleKey, p1TeamIndex);
    }

    function startBattle(bytes32 battleKey, bytes32 salt, uint256 p0TeamIndex) external {
        Battle storage battle = battles[battleKey];
        if (msg.sender != battle.p0) {
            revert WrongCaller();
        }

        // Set the status to be started
        battle.status = BattleProposalStatus.Started;

        // Calculate the p0 team hash
        uint256[] memory p0TeamIndices = battle.teamRegistry.getMonRegistryIndicesForTeam(msg.sender, p0TeamIndex);
        bytes32 revealedP0TeamHash = keccak256(abi.encodePacked(salt, p0TeamIndex, p0TeamIndices));

        // Validate the team hash
        if (revealedP0TeamHash != battle.p0TeamHash) {
            revert InvalidP0TeamHash();
        }

        // Set the teamHash to be teamIndex after verification
        battle.p0TeamHash = bytes32(p0TeamIndex);

        // Set the team for p0
        battles[battleKey].teams[0] = battle.teamRegistry.getTeam(msg.sender, p0TeamIndex);

        // Initialize empty mon state, move history, and active mon index for each team
        for (uint256 i; i < 2; ++i) {
            battleStates[battleKey].monStates.push();
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

        // Call the CommitManager to initialize the move history
        commitManager.initMoveHistory(battleKey);

        // Validate the battle config
        if (
            !battle.validator.validateGameStart(
                battles[battleKey], battle.teamRegistry, p0TeamIndex, battleKey, msg.sender
            )
        ) {
            revert InvalidBattleConfig();
        }

        // Set flag to be 2 which means both players act
        battleStates[battleKey].playerSwitchForTurnFlag = 2;

        emit BattleStart(battleKey, p0TeamIndex, battle.p0, battle.p1);
    }

    function execute(bytes32 battleKey) external {
        // Load storage vars
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];

        // Check for game over
        if (state.winner != address(0)) {
            revert GameAlreadyOver();
        }

        // Set up turn / player vars
        uint256 turnId = state.turnId;
        uint256 playerSwitchForTurnFlag;
        uint256 priorityPlayerIndex;

        // Set the battle key for the stack frame
        // (gets cleared at the end of the transaction)
        battleKeyForWrite = battleKey;

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

            playerSwitchForTurnFlag = 2;
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
            RevealedMove memory p0Move = commitManager.getMoveForBattleStateForTurn(battleKey, 0, turnId);
            RevealedMove memory p1Move = commitManager.getMoveForBattleStateForTurn(battleKey, 1, turnId);

            // Update the PRNG hash to include the newest value
            uint256 rng = battle.rngOracle.getRNG(p0Move.salt, p1Move.salt);
            state.pRNGStream.push(rng);

            // Calculate the priority and non-priority player indices
            priorityPlayerIndex = battle.validator.computePriorityPlayerIndex(battleKey, rng);
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
        // Emits switch for turn flag for the next turn, but the priority index for this current turn
        emit EngineExecute(battleKey, turnId, playerSwitchForTurnFlag, priorityPlayerIndex);
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
                battle.status = BattleProposalStatus.Ended;
                emit BattleComplete(battleKey, afkResult);
                return;
            }
        }
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
        } else if (stateVarIndex == MonStateIndexName.Defense) {
            monState.defenceDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.SpecialAttack) {
            monState.specialAttackDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.SpecialDefense) {
            monState.specialDefenceDelta += valueToAdd;
        } else if (stateVarIndex == MonStateIndexName.IsKnockedOut) {
            monState.isKnockedOut = (valueToAdd % 2) == 1;
        } else if (stateVarIndex == MonStateIndexName.ShouldSkipTurn) {
            monState.shouldSkipTurn = (valueToAdd % 2) == 1;
        }
        emit MonStateUpdate(
            battleKey, playerIndex, monIndex, uint256(stateVarIndex), valueToAdd, msg.sender, currentStep
        );
    }

    function addEffect(uint256 targetIndex, uint256 monIndex, IEffect effect, bytes memory extraData) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        if (effect.shouldApply(extraData, targetIndex, monIndex)) {
            BattleState storage state = battleStates[battleKey];
            bytes[] storage effectsExtraData;
            if (targetIndex == 2) {
                state.globalEffects.push(effect);
                state.extraDataForGlobalEffects.push(extraData);
                effectsExtraData = state.extraDataForGlobalEffects;
            } else {
                state.monStates[targetIndex][monIndex].targetedEffects.push(effect);
                state.monStates[targetIndex][monIndex].extraDataForTargetedEffects.push(extraData);
                effectsExtraData = state.monStates[targetIndex][monIndex].extraDataForTargetedEffects;
            }
            // Check if we have to run an onApply state update
            if (effect.shouldRunAtStep(EffectStep.OnApply)) {
                uint256 rng = state.pRNGStream[state.pRNGStream.length - 1];
                // If so, we run the effect first, and get updated extraData if necessary
                extraData = effect.onApply(rng, extraData, targetIndex, monIndex);

                // Set the extraData so be the returned value from onApply
                effectsExtraData[effectsExtraData.length - 1] = extraData;
            }
            emit EffectAdd(battleKey, targetIndex, monIndex, address(effect), extraData, msg.sender, currentStep);
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
            effect.onRemove(extraData[indexToRemove], targetIndex, monIndex);
        }

        // Remove effects and extra data
        uint256 numEffects = effects.length;
        effects[indexToRemove] = effects[numEffects - 1];
        effects.pop();
        extraData[indexToRemove] = extraData[numEffects - 1];
        extraData.pop();
        emit EffectRemove(battleKey, targetIndex, monIndex, address(effect), msg.sender, currentStep);
    }

    function setGlobalKV(bytes32 key, bytes32 value) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        globalKV[battleKey][key] = value;
    }

    function dealDamage(uint256 playerIndex, uint256 monIndex, int32 damage) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }
        MonState storage monState = battleStates[battleKey].monStates[playerIndex][monIndex];
        damageDealt = damage;
        monState.hpDelta -= damage;
        // Set KO flag if the total hpDelta is greater than the original mon HP
        uint32 baseHp = battles[battleKey].teams[playerIndex][monIndex].stats.hp;
        if (monState.hpDelta + int32(baseHp) <= 0) {
            monState.isKnockedOut = true;
        }
        uint256[] storage rngValues = battleStates[battleKey].pRNGStream;
        uint256 rngValue = rngValues[rngValues.length - 1];
        _runEffects(battleKey, rngValue, playerIndex, playerIndex, EffectStep.AfterDamage);
        emit DamageDeal(battleKey, playerIndex, monIndex, damage, msg.sender, currentStep);
    }

    function switchActiveMon(uint256 playerIndex, uint256 monToSwitchIndex) external {
        bytes32 battleKey = battleKeyForWrite;
        if (battleKey == bytes32(0)) {
            revert NoWriteAllowed();
        }

        // Use the validator to check if the switch is valid
        if (battles[battleKey].validator.validateSwitch(battleKey, playerIndex, monToSwitchIndex)) {
            // Only call the internal switch function if the switch is valid
            _handleSwitch(battleKey, playerIndex, monToSwitchIndex, msg.sender);

            // Check for game over and/or KOs for the switching player
            (uint256 playerSwitchForTurnFlag,,, bool isGameOver) =
                _checkForGameOverOrKO(battleKey, playerIndex);
            if (isGameOver) return;

            // Set the player switch for turn flag
            battleStates[battleKey].playerSwitchForTurnFlag = playerSwitchForTurnFlag;

            // TODO: consider also checking game over / setting flag for other player
        }
        // If the switch is invalid, we simply do nothing and continue execution
    }

    /**
     * - Internal helper functions
     */
    function _computeBattleKey(StartBattleArgs memory args)
        internal
        view
        returns (bytes32 battleKey, bytes32 pairHash)
    {
        pairHash = keccak256(abi.encode(args.p0, args.p1));
        if (uint256(uint160(args.p0)) > uint256(uint160(args.p1))) {
            pairHash = keccak256(abi.encode(args.p1, args.p0));
        }
        uint256 pairHashNonce = pairHashNonces[pairHash];
        battleKey = keccak256(abi.encode(pairHash, pairHashNonce));
    }

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
            battle.status = BattleProposalStatus.Ended;
            emit BattleComplete(battleKey, gameResult);
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

    function _handleSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monToSwitchIndex, address source) internal {
        BattleState storage state = battleStates[battleKey];
        MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
        uint256 rng = state.pRNGStream[state.pRNGStream.length - 1];

        // If the current mon is not knocked out:
        // Go through each effect to see if it should be cleared after a switch,
        // If so, remove the effect and the extra data
        if (!currentMonState.isKnockedOut) {
            _runEffects(battleKey, rng, playerIndex, playerIndex, EffectStep.OnMonSwitchOut);
        }

        // Update to new active mon (we assume validate already resolved and gives us a valid target)
        state.activeMonIndex[playerIndex] = monToSwitchIndex;

        // Run onMonSwitchIn hook for global effects
        _runEffects(battleKey, rng, 2, playerIndex, EffectStep.OnMonSwitchIn);

        // Run ability for the newly switched in mon
        Mon memory mon = battles[battleKey].teams[playerIndex][monToSwitchIndex];
        if (address(mon.ability) != address(0)) {
            mon.ability.activateOnSwitch(battleKey, playerIndex, monToSwitchIndex);
        }

        emit MonSwitch(battleKey, playerIndex, monToSwitchIndex, source);

        // NOTE: We will check for game over after the switch in the engine for two player turns, so we don't do it here
        // But this also means that the current flow of OnMonSwitchOut effects -> OnMonSwitchIn effects -> ability activateOnSwitch
        // will all resolve before checking for KOs or winners
        // (could break this up even more, but that's for a later version / PR)
    }

    function _handlePlayerMove(bytes32 battleKey, uint256 rng, uint256 playerIndex) internal {
        Battle storage battle = battles[battleKey];
        BattleState storage state = battleStates[battleKey];
        RevealedMove memory move = commitManager.getMoveForBattleStateForTurn(battleKey, playerIndex, state.turnId);

        // Handle shouldSkipTurn flag first and toggle it off if set
        MonState storage currentMonState = state.monStates[playerIndex][state.activeMonIndex[playerIndex]];
        if (currentMonState.shouldSkipTurn) {
            currentMonState.shouldSkipTurn = false;

            // If the move is NOT a switch, then we just return early
            if (move.moveIndex != SWITCH_MOVE_INDEX) {
                return;
            }
        }

        // Emit event
        emit MonMove(battleKey, playerIndex, state.activeMonIndex[playerIndex], move.moveIndex, move.extraData);

        // Handle a switch or a no-op
        // otherwise, execute the moveset
        if (move.moveIndex == SWITCH_MOVE_INDEX) {
            // Handle the switch
            _handleSwitch(battleKey, playerIndex, abi.decode(move.extraData, (uint256)), address(0));
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

            // Run the move (no longer checking for a return value)
            moveSet.move(battleKey, playerIndex, move.extraData, rng);
        }
    }

    /**
     * effect index: the index to grab the relevant effect array
     *    player index: the player to pass into the effects args
     */
    function _runEffects(bytes32 battleKey, uint256 rng, uint256 effectIndex, uint256 playerIndex, EffectStep round)
        internal
    {
        BattleState storage state = battleStates[battleKey];
        IEffect[] storage effects;
        bytes[] storage extraData;
        uint256 monIndex;
        // Switch between global or targeted effects array depending on the args
        if (effectIndex == 2) {
            effects = state.globalEffects;
            extraData = state.extraDataForGlobalEffects;
        } else {
            monIndex = state.activeMonIndex[effectIndex];
            effects = state.monStates[effectIndex][monIndex].targetedEffects;
            extraData = state.monStates[effectIndex][monIndex].extraDataForTargetedEffects;
        }
        // Grab the active mon (global effect won't know which player index to get, so we set it here)
        if (playerIndex != 2) {
            monIndex = state.activeMonIndex[playerIndex];
        }
        uint256 i;
        while (i < effects.length) {
            bool currentStepUpdated;
            if (effects[i].shouldRunAtStep(round)) {
                // Only update the current step if we need to run any effects, and only update it once per step
                if (!currentStepUpdated) {
                    currentStep = uint256(round);
                    currentStepUpdated = true;
                }

                // Run the effects (depending on which round stage we are on)
                bytes memory updatedExtraData;
                bool removeAfterRun;
                if (round == EffectStep.RoundStart) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onRoundStart(rng, extraData[i], playerIndex, monIndex);
                } else if (round == EffectStep.RoundEnd) {
                    (updatedExtraData, removeAfterRun) = effects[i].onRoundEnd(rng, extraData[i], playerIndex, monIndex);
                } else if (round == EffectStep.OnMonSwitchIn) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onMonSwitchIn(rng, extraData[i], playerIndex, monIndex);
                } else if (round == EffectStep.OnMonSwitchOut) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onMonSwitchOut(rng, extraData[i], playerIndex, monIndex);
                } else if (round == EffectStep.AfterDamage) {
                    (updatedExtraData, removeAfterRun) =
                        effects[i].onAfterDamage(rng, extraData[i], playerIndex, monIndex, damageDealt);
                }

                // If we remove the effect after doing it, then we clear and update the array/extra data
                if (removeAfterRun) {
                    removeEffect(effectIndex, monIndex, i);
                }
                // Otherwise, we update the extra data if e.g. the effect needs to modify its own storage
                else {
                    extraData[i] = updatedExtraData;
                    ++i;
                }
            } else {
                ++i;
            }
        }
    }

    /**
     * - Getters to simplify read access for other components
     */

    // getBattle and getBattleState are intended to be consumed by offchain clients
    function getBattle(bytes32 battleKey) external view returns (Battle memory) {
        return battles[battleKey];
    }

    function getBattleState(bytes32 battleKey) external view returns (BattleState memory) {
        return battleStates[battleKey];
    }

    function getBattleStatus(bytes32 battleKey) external view returns (BattleProposalStatus) {
        return battles[battleKey].status;
    }

    function getBattleValidator(bytes32 battleKey) external view returns (IValidator) {
        return battles[battleKey].validator;
    }

    function getMonValueForBattle(
        bytes32 battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        MonStateIndexName stateVarIndex
    ) external view returns (uint32) {
        if (stateVarIndex == MonStateIndexName.Hp) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.hp;
        } else if (stateVarIndex == MonStateIndexName.Stamina) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.stamina;
        } else if (stateVarIndex == MonStateIndexName.Speed) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.speed;
        } else if (stateVarIndex == MonStateIndexName.Attack) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.attack;
        } else if (stateVarIndex == MonStateIndexName.Defense) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.defense;
        } else if (stateVarIndex == MonStateIndexName.SpecialAttack) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.specialAttack;
        } else if (stateVarIndex == MonStateIndexName.SpecialDefense) {
            return battles[battleKey].teams[playerIndex][monIndex].stats.specialDefense;
        } else if (stateVarIndex == MonStateIndexName.Type1) {
            return uint32(battles[battleKey].teams[playerIndex][monIndex].stats.type1);
        } else if (stateVarIndex == MonStateIndexName.Type2) {
            return uint32(battles[battleKey].teams[playerIndex][monIndex].stats.type2);
        } else {
            return 0;
        }
    }

    function getMoveForMonForBattle(bytes32 battleKey, uint256 playerIndex, uint256 monIndex, uint256 moveIndex)
        external
        view
        returns (IMoveSet)
    {
        return battles[battleKey].teams[playerIndex][monIndex].moves[moveIndex];
    }

    function getPlayersForBattle(bytes32 battleKey) external view returns (address[] memory) {
        address[] memory players = new address[](2);
        players[0] = battles[battleKey].p0;
        players[1] = battles[battleKey].p1;
        return players;
    }

    function getMonStateForBattle(
        bytes32 battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        MonStateIndexName stateVarIndex
    ) external view returns (int32) {
        if (stateVarIndex == MonStateIndexName.Hp) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].hpDelta;
        } else if (stateVarIndex == MonStateIndexName.Stamina) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].staminaDelta;
        } else if (stateVarIndex == MonStateIndexName.Speed) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].speedDelta;
        } else if (stateVarIndex == MonStateIndexName.Attack) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].attackDelta;
        } else if (stateVarIndex == MonStateIndexName.Defense) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].defenceDelta;
        } else if (stateVarIndex == MonStateIndexName.SpecialAttack) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].specialAttackDelta;
        } else if (stateVarIndex == MonStateIndexName.SpecialDefense) {
            return battleStates[battleKey].monStates[playerIndex][monIndex].specialDefenceDelta;
        } else if (stateVarIndex == MonStateIndexName.IsKnockedOut) {
            if (battleStates[battleKey].monStates[playerIndex][monIndex].isKnockedOut) {
                return 1;
            } else {
                return 0;
            }
        } else if (stateVarIndex == MonStateIndexName.ShouldSkipTurn) {
            if (battleStates[battleKey].monStates[playerIndex][monIndex].shouldSkipTurn) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
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

    // To be called once (after CommitManager is deployed and set to the Engine)
    function setCommitManager(address a) external {
        if (address(commitManager) != address(0)) {
            revert CommitManagerAlreadySet();
        }
        commitManager = IFastCommitManager(a);
    }
}

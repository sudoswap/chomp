// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";
import {IValidator} from "./IValidator.sol";

import {IMonRegistry} from "./teams/IMonRegistry.sol";
import {ITeamRegistry} from "./teams/ITeamRegistry.sol";

contract DefaultValidator is IValidator {
    struct Args {
        uint256 MONS_PER_TEAM;
        uint256 MOVES_PER_MON;
        uint256 TIMEOUT_DURATION;
    }

    uint256 immutable MONS_PER_TEAM;
    uint256 immutable MOVES_PER_MON;
    uint256 public immutable TIMEOUT_DURATION;
    IEngine immutable ENGINE;

    mapping(address => mapping(bytes32 => uint256)) proposalTimestampForProposer;

    constructor(IEngine _ENGINE, Args memory args) {
        ENGINE = _ENGINE;
        MONS_PER_TEAM = args.MONS_PER_TEAM;
        MOVES_PER_MON = args.MOVES_PER_MON;
        TIMEOUT_DURATION = args.TIMEOUT_DURATION;
    }

    // Validates that there are MONS_PER_TEAM mons per team w/ MOVES_PER_MON moves each
    function validateGameStart(
        Battle calldata b,
        ITeamRegistry teamRegistry,
        uint256 p0TeamIndex,
        bytes32 battleKey,
        address gameStartCaller
    ) external returns (bool) {
        IMonRegistry monRegistry = teamRegistry.getMonRegistry();

        // p0 and p1 each have 6 mons, each mon has 4 moves
        uint256[2] memory playerIndices = [uint256(0), uint256(1)];
        address[2] memory players = [b.p0, b.p1];
        uint256[2] memory teamIndex = [p0TeamIndex, b.p1TeamIndex];

        for (uint256 i; i < playerIndices.length; ++i) {
            if (b.teams[i].length != MONS_PER_TEAM) {
                return false;
            }

            // Should be the same length as teams[i].length
            uint256[] memory teamIndices = teamRegistry.getMonRegistryIndicesForTeam(players[i], teamIndex[i]);

            // Check that each mon is still up to date with the current mon registry values
            for (uint256 j; j < MONS_PER_TEAM; ++j) {
                if (b.teams[i][j].moves.length != MOVES_PER_MON) {
                    return false;
                }
                // Call the IMonRegistry to see if the stats, moves, and ability are still valid
                if (address(monRegistry) != address(0) && !monRegistry.validateMon(b.teams[i][j], teamIndices[j])) {
                    return false;
                }
            }
        }
        uint256 previousProposalTimestamp = proposalTimestampForProposer[gameStartCaller][battleKey];
        // Ensures that proposers cannot quickly modify in-flight proposed matches by rate limiting
        if (previousProposalTimestamp != 0) {
            if (block.timestamp - previousProposalTimestamp < TIMEOUT_DURATION) {
                return false;
            }
        }
        proposalTimestampForProposer[gameStartCaller][battleKey] = block.timestamp;
        return true;
    }

    // A switch is valid if the new mon isn't knocked out and the index is valid (not out of range or the same one)
    function validateSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monToSwitchIndex)
        public
        view
        returns (bool)
    {
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);

        if (monToSwitchIndex >= MONS_PER_TEAM) {
            return false;
        }
        bool isNewMonKnockedOut = monStates[playerIndex][monToSwitchIndex].isKnockedOut;
        if (isNewMonKnockedOut) {
            return false;
        }
        // If it's not the zeroth turn, we cannot switch to the same mon
        // (exception for zeroth turn because we have not initiated a swap yet, so index 0 is fine)
        if (ENGINE.getTurnIdForBattleState(battleKey) != 0) {
            if (monToSwitchIndex == activeMonIndex[playerIndex]) {
                return false;
            }
        }
        return true;
    }

    function validateSpecificMoveSelection(
        bytes32 battleKey,
        uint256 moveIndex,
        uint256 playerIndex,
        bytes calldata extraData
    ) public view returns (bool) {
        Mon[][] memory teams = ENGINE.getTeamsForBattle(battleKey);
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);

        // A move cannot be selected if its stamina costs more than the mon's current stamina
        IMoveSet moveSet = teams[playerIndex][activeMonIndex[playerIndex]].moves[moveIndex];
        int256 monStaminaDelta = monStates[playerIndex][activeMonIndex[playerIndex]].staminaDelta;
        uint256 monBaseStamina = teams[playerIndex][activeMonIndex[playerIndex]].stats.stamina;
        uint256 monCurrentStamina = uint256(int256(monBaseStamina) + monStaminaDelta);
        if (moveSet.stamina(battleKey) > monCurrentStamina) {
            return false;
        } else {
            // Then, we check the move itself to see if it enforces any other specific conditions
            if (!moveSet.isValidTarget(battleKey)) {
                return false;
            }
        }

        // If the move triggers a swap, we need to check to see if it's a valid swap
        (uint256 forceSwitchPlayerIndex, uint256 monIndexToSwitchTo) =
            moveSet.postMoveSwitch(battleKey, playerIndex, extraData);
        if (forceSwitchPlayerIndex != NO_SWITCH_FLAG) {
            bool isValidSwitch = validateSwitch(battleKey, forceSwitchPlayerIndex, monIndexToSwitchTo);
            if (!isValidSwitch) {
                return false;
            }
        }

        return true;
    }

    // Validates that you can't switch to the same mon, you have enough stamina, the move isn't disabled, etc.
    function validatePlayerMove(bytes32 battleKey, uint256 moveIndex, uint256 playerIndex, bytes calldata extraData)
        external
        view
        returns (bool)
    {
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);
        uint256[] memory activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey);

        // Enforce a switch IF:
        // - if it is the zeroth turn
        // - if the active mon is knocked out
        {
            bool isTurnZero = ENGINE.getTurnIdForBattleState(battleKey) == 0;
            bool isActiveMonKnockedOut = monStates[playerIndex][activeMonIndex[playerIndex]].isKnockedOut;
            if (isTurnZero || isActiveMonKnockedOut) {
                if (moveIndex != SWITCH_MOVE_INDEX) {
                    return false;
                }
            }
        }

        // Cannot go past the first 4 moves, or the switch move index or the no op
        if (moveIndex != NO_OP_MOVE_INDEX && moveIndex != SWITCH_MOVE_INDEX) {
            if (moveIndex >= MOVES_PER_MON) {
                return false;
            }
        }
        // If it is no op move, it's valid as long as we don't force a switch
        else if (moveIndex == NO_OP_MOVE_INDEX) {
            return true;
        }
        // If it is a switch move, then it's valid as long as the new mon isn't knocked out
        // AND if the new mon isn't the same index as the existing mon
        else if (moveIndex == SWITCH_MOVE_INDEX) {
            uint256 monToSwitchIndex = abi.decode(extraData, (uint256));
            return validateSwitch(battleKey, playerIndex, monToSwitchIndex);
        }

        // Otherwise, it's not a switch or a no-op, so it's a move
        if (!validateSpecificMoveSelection(battleKey, moveIndex, playerIndex, extraData)) {
            return false;
        }

        return true;
    }

    // Validates that the game is over, returns address(0) if no winner, otherwise returns the winner
    function validateGameOver(bytes32 battleKey, uint256 priorityPlayerIndex) external view returns (address) {
        address[] memory players = ENGINE.getPlayersForBattle(battleKey);
        MonState[][] memory monStates = ENGINE.getMonStatesForBattleState(battleKey);

        // A game is over if all of a player's mons are knocked out
        uint256[2] memory playerIndex = [uint256(0), uint256(1)];
        if (priorityPlayerIndex == 1) {
            playerIndex = [uint256(1), uint256(0)];
        }
        for (uint256 i; i < playerIndex.length; ++i) {
            uint256 numMonsKnockedOut;
            for (uint256 j; j < MONS_PER_TEAM; ++j) {
                if (monStates[playerIndex[i]][j].isKnockedOut) {
                    numMonsKnockedOut += 1;
                }
            }
            if (numMonsKnockedOut == MONS_PER_TEAM) {
                if (playerIndex[i] == 0) {
                    return players[1];
                } else {
                    return players[0];
                }
            }
        }
        return address(0);
    }

    // A timeout is valid if
    // enough time has passed AND:
    // - honest player has both committed and revealed a move
    // - afk player commits to a move but can't reveal it (because it's invalid)
    // - i.e. honest player has more revealed moves
    // -
    // - OR
    // -
    // - honest player has committed to a move but cannot reveal it because afk player has not committed
    // - afk player does not commit to a move
    // - i.e. honest player has a commitment one turn ahead of afk player
    function validateTimeout(bytes32 battleKey, uint256 presumedAFKPlayerIndex) external view returns (address) {
        RevealedMove[][] memory moveHistory = ENGINE.getMoveHistoryForBattleState(battleKey);
        address[] memory players = ENGINE.getPlayersForBattle(battleKey);
        uint256 presumedHonestPlayerIndex = (presumedAFKPlayerIndex + 1) % 2;
        address presumedHonestPlayer;
        address presumedAFKPlayer;
        if (presumedHonestPlayerIndex == 0) {
            presumedHonestPlayer = players[0];
            presumedAFKPlayer = players[1];
        } else {
            presumedHonestPlayer = players[1];
            presumedAFKPlayer = players[0];
        }
        Commitment memory presumedHonestPlayerCommitment = ENGINE.getCommitment(battleKey, presumedHonestPlayer);

        // If it's been enough to check for a TIMEOUT (otherwise we don't bother at all):
        if (presumedHonestPlayerCommitment.timestamp + TIMEOUT_DURATION <= block.timestamp) {
            RevealedMove[] memory movesPresumedAFKPlayerRevealed = moveHistory[presumedAFKPlayerIndex];
            RevealedMove[] memory movesPresumedHonestPlayerRevealed = moveHistory[presumedHonestPlayerIndex];

            Commitment memory presumedAFKPlayerCommitment = ENGINE.getCommitment(battleKey, presumedAFKPlayer);

            // If it's a turn where both players have to make a move:
            uint256 playerSwitchForTurnFlag = ENGINE.getPlayerSwitchForTurnFlagForBattleState(battleKey);
            if (playerSwitchForTurnFlag == 2) {
                // If the honest player has revealed more moves than the afk player, then the honest player wins
                if (movesPresumedHonestPlayerRevealed.length > movesPresumedAFKPlayerRevealed.length) {
                    return presumedHonestPlayer;
                }

                // If the honest player has a commitment that is ahead of the afk player (but the revealed moves are the same)
                // then the honest player wins
                if (presumedHonestPlayerCommitment.turnId > presumedAFKPlayerCommitment.turnId) {
                    return presumedHonestPlayer;
                }
            }
            // Otherwise, if it's a turn where the presumed AFK player has to make a move
            else if (presumedAFKPlayerIndex == playerSwitchForTurnFlag) {
                uint256 globalTurnId = ENGINE.getTurnIdForBattleState(battleKey);

                // If the player who is supposed to reveal has not revealed (i.e. the turn id is behind), then the other player wins
                if (movesPresumedAFKPlayerRevealed.length < (globalTurnId + 1)) {
                    return presumedHonestPlayer;
                }

                if (presumedAFKPlayerCommitment.turnId < globalTurnId) {
                    return presumedHonestPlayer;
                }
            }
        }
        return address(0);
    }
}

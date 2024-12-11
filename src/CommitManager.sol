// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./Enums.sol";
import "./Structs.sol";

import {ICommitManager} from "./ICommitManager.sol";
import {IEngine} from "./IEngine.sol";

contract CommitManager is ICommitManager {
    // State variables
    IEngine private immutable ENGINE;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) private commitments;
    mapping(bytes32 battleKey => RevealedMove[][]) private moveHistory;

    // Errors
    error NotEngine();
    error NotP0OrP1();
    error AlreadyCommited();
    error AlreadyRevealed();
    error BattleNotStarted();
    error RevealBeforeOtherCommit();
    error WrongTurnId();
    error WrongPreimage();
    error PlayerNotAllowed();
    error InvalidMove(address player);

    // Events
    event MoveCommit(bytes32 indexed battleKey, address player);
    event MoveReveal(bytes32 indexed battleKey, address player, uint256 moveIndex);

    constructor(IEngine engine) {
        ENGINE = engine;
    }

    function initMoveHistory(bytes32 battleKey) external returns (bool) {
        if (msg.sender != address(ENGINE)) {
            revert NotEngine();
        }
        // Only if the length is zero
        if (moveHistory[battleKey].length != 0) {
            // No need to revert as someone could be overriding a proposed battle, just don't do anything
            return false;
        } else {
            moveHistory[battleKey].push();
            moveHistory[battleKey].push();
            return true;
        }
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external {
        address[] memory p0AndP1 = ENGINE.getPlayersForBattle(battleKey);

        // only battle participants can commit
        if (msg.sender != p0AndP1[0] && msg.sender != p0AndP1[1]) {
            revert NotP0OrP1();
        }

        // Can only commit moves to battles with a Started status
        // (reveal relies on commit, and execute relies on both of those)
        // (so transitively, it's safe to just check battle proposal status on commit)
        if (ENGINE.getBattleStatus(battleKey) != BattleProposalStatus.Started) {
            revert BattleNotStarted();
        }

        // Validate no commitment already exists for this turn:
        uint256 turnId = ENGINE.getTurnIdForBattleState(battleKey);

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
        uint256 playerSwitchForTurnFlag = ENGINE.getPlayerSwitchForTurnFlagForBattleState(battleKey);
        if (
            (playerSwitchForTurnFlag == 0 && msg.sender != p0AndP1[0])
                || (playerSwitchForTurnFlag == 1 && msg.sender != p0AndP1[1])
        ) {
            revert PlayerNotAllowed();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});

        emit MoveCommit(battleKey, msg.sender);
    }

    function revealMove(bytes32 battleKey, uint256 moveIndex, bytes32 salt, bytes calldata extraData, bool autoExecute)
        external
    {
        // validate preimage
        Commitment storage commitment = commitments[battleKey][msg.sender];
        if (keccak256(abi.encodePacked(moveIndex, salt, extraData)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // only battle participants can reveal
        address[] memory p0AndP1 = ENGINE.getPlayersForBattle(battleKey);
        if (msg.sender != p0AndP1[0] && msg.sender != p0AndP1[1]) {
            revert NotP0OrP1();
        }

        // ensure reveal happens after caller commits
        uint256 turnId = ENGINE.getTurnIdForBattleState(battleKey);
        if (commitment.turnId != turnId) {
            revert WrongTurnId();
        }

        uint256 currentPlayerIndex;
        uint256 otherPlayerIndex;
        address otherPlayer;

        // Set current and other player based on the caller
        if (msg.sender == p0AndP1[0]) {
            otherPlayer = p0AndP1[1];
            otherPlayerIndex = 1;
        } else {
            otherPlayer = p0AndP1[0];
            currentPlayerIndex = 1;
        }

        // ensure reveal happens after opponent commits
        // (only if it is a turn where both players need to select an action)
        uint256 playerSwitchForTurnFlag = ENGINE.getPlayerSwitchForTurnFlagForBattleState(battleKey);
        if (playerSwitchForTurnFlag == 2) {
            // if it's not the zeroth turn, make sure that player cannot reveal until other player has committed
            if (turnId != 0) {
                if (commitments[battleKey][otherPlayer].turnId != turnId) {
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

        // If a reveal already happened, then revert
        RevealedMove[] storage playerMoveHistory = moveHistory[battleKey][currentPlayerIndex];
        if (playerMoveHistory.length > turnId) {
            revert AlreadyRevealed();
        }

        // validate that the commited moves are legal
        // (e.g. there is enough stamina, move is not disabled, etc.)
        if (
            !ENGINE.getBattleValidator(battleKey).validatePlayerMove(battleKey, moveIndex, currentPlayerIndex, extraData)
        ) {
            revert InvalidMove(msg.sender);
        }

        // store revealed move and extra data for the current player
        playerMoveHistory.push(RevealedMove({moveIndex: moveIndex, salt: salt, extraData: extraData}));

        // store empty move for other player if it's a turn where only a single player has to make a move
        if (playerSwitchForTurnFlag == 0 || playerSwitchForTurnFlag == 1) {
            RevealedMove[] storage otherPlayerMoveHistory = moveHistory[battleKey][otherPlayerIndex];
            otherPlayerMoveHistory.push(RevealedMove({moveIndex: NO_OP_MOVE_INDEX, salt: "", extraData: ""}));
        }

        // Emit move reveal event before game engine execution
        emit MoveReveal(battleKey, msg.sender, moveIndex);

        // if we want to auto execute
        if (autoExecute) {
            // check if the other player has revealed already
            // (even for 1 player turns, the above statements guarantee we'll have a move revealed)
            RevealedMove[] storage otherPlayerMoveHistory = moveHistory[battleKey][otherPlayerIndex];
            // if so, we can automatically advance game state
            if (otherPlayerMoveHistory.length > turnId) {
                ENGINE.execute(battleKey);
            }
        }
    }

    function getCommitment(bytes32 battleKey, address player) external view returns (Commitment memory) {
        return commitments[battleKey][player];
    }

    function getMoveForBattleStateForTurn(bytes32 battleKey, uint256 playerIndex, uint256 turn)
        external
        view
        returns (RevealedMove memory)
    {
        return moveHistory[battleKey][playerIndex][turn];
    }

    function getMoveCountForBattleState(bytes32 battleKey, uint256 playerIndex) external view returns (uint256) {
        return moveHistory[battleKey][playerIndex].length;
    }
}

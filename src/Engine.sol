// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";
import "./Constants.sol";

contract Engine {

    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;

    error NotP1OrP2();
    error AlreadyCommited();
    error WrongTurnId();
    error WrongPreimage();
    error InvalidMove();
    error OnlyP1Allowed();
    error OnlyP2Allowed();

    modifier onlyPlayer(bytes32 battleKey) {
        Battle memory battle = battles[battleKey];
        if (msg.sender != battle.p1 && msg.sender != battle.p2) {
            revert NotP1OrP2();
        }
        _;
    }

    function start(Battle calldata battle) external {
        // validate battle
        battle.hook.validateGameStart(battle);

        // store battle
        bytes32 battleKey = sha256(abi.encode(battle.salt, battle.p1, battle.p2));
        battles[battleKey] = battle;

        // Initialize empty mon state delta for each team
        for (uint i; i < battle.p1Team.length; ++i) {
            battleStates[battleKey].p1TeamState.push();
        }
        for (uint i; i < battle.p2Team.length; ++i) {
            battleStates[battleKey].p2TeamState.push();
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
        }
        else if (pAllowanceFlag == 2 && msg.sender != battle.p2) {
            revert OnlyP1Allowed();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIdx, bytes32 salt, bytes calldata extraData) external onlyPlayer(battleKey) {
        // validate preimage
        Commitment memory commitment = commitments[battleKey][msg.sender];
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];
        if (commitment.turnId != state.turnId) {
            revert WrongTurnId();
        }
        if (keccak256(abi.encodePacked(moveIdx, salt, extraData)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // validate that the commited moves are legal
        // (e.g. there is enough stamina, move is not disabled, etc.)
        if (! battle.hook.validateMove(battle, state, moveIdx, msg.sender)) {
            revert InvalidMove();
        }

        // store revealed move and extra data as needed
        if (msg.sender == battle.p1) {
            battleStates[battleKey].p1MoveHistory.push(RevealedMove({moveIdx: moveIdx, extraData: extraData}));
        } else {
            battleStates[battleKey].p2MoveHistory.push(RevealedMove({moveIdx: moveIdx, extraData: extraData}));
        }

        // store empty move for other player if it's a turn where only a single player has to make a move
        if (state.pAllowanceFlag == 1) {
            battleStates[battleKey].p2MoveHistory.push(RevealedMove({moveIdx: NO_OP_MOVE_INDEX, extraData: ""}));
        }
        else if (state.pAllowanceFlag == 2) {
            battleStates[battleKey].p1MoveHistory.push(RevealedMove({moveIdx: NO_OP_MOVE_INDEX, extraData: ""}));
        }
    }

    function execute(bytes32 battleKey) external {
        // validate both moves have been revealed for the current turn
        // (accessing the values will revert if they haven't been set)
        uint256 turnId = battleStates[battleKey].turnId;
        
        // RevealedMove memory p1Move = battleStates[battleKey].p1MoveHistory[turnId];
        // RevealedMove memory p2Move = battleStates[battleKey].p2MoveHistory[turnId];

        // Before turn effects
        // Check priorities, then execute move, check for end of game, execute move, then check for end of game
        // if knocked out, then swapping is an action where the other person can only do a no-op
        // Check for end of turn effects
        // If end of game, call end of game hook

    }

    function end(bytes32 battleKey) external {}
}

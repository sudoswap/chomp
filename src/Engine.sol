// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

contract Engine {

    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;

    error NotPlayer();
    error AlreadyCommited();
    error WrongTurnId();
    error WrongPreimage();
    error InvalidMove();

    modifier onlyPlayer(bytes32 battleKey) {
        Battle memory battle = battles[battleKey];
        if (msg.sender != battle.p1 && msg.sender != battle.p2) {
            revert NotPlayer();
        }
        _;
    }

    function start(Battle calldata battle) external {
        // validate battle
        battle.hook.validateGameStart(battle);

        // store battle
        bytes32 battleKey = sha256(abi.encode(battle.salt, battle.p1, battle.p2));
        battles[battleKey] = battle;

        /*
        // initialize battle state
        BattleState memory battleState = BattleState({
            turnId: 0,
            p1ActiveMon: battle.p1ActiveMon,
            p2ActiveMon: battle.p2ActiveMon,
            p1TeamState: new MonState[](0),
            p2TeamState: new MonState[](0),
            p1MoveHistory: new RevealedMove[](0),
            p2MoveHistory: new RevealedMove[](0),
            extraData: bytes("")
        });

        // let hook modify initial state
        battleState = battle.hook.modifyInitialState(battleState);

        // store initial state
        battleStates[battleKey] = battleState;
        */

        // Initialize empty delta for each team
        for (uint i; i < battle.p1Team.length; ++i) {
            battleStates[battleKey].p1TeamState.push();
        }
        for (uint i; i < battle.p2Team.length; ++i) {
            battleStates[battleKey].p2TeamState.push();
        }

        // Initialize turn order
        battleStates[battleKey].turnId = 1;
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external onlyPlayer(battleKey) {
        // validate no commitment exists for this turn
        uint256 turnId = battleStates[battleKey].turnId;
        if (commitments[battleKey][msg.sender].turnId == turnId) {
            revert AlreadyCommited();
        }

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIdx, bytes32 salt) external onlyPlayer(battleKey) {
        // validate preimage
        Commitment memory commitment = commitments[battleKey][msg.sender];
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];
        if (commitment.turnId != state.turnId) {
            revert WrongTurnId();
        }
        if (keccak256(abi.encodePacked(moveIdx, salt)) != commitment.moveHash) {
            revert WrongPreimage();
        }

        // validate that the commited moves are legal
        // (e.g. there is enough stamina, move is not disabled, etc.)
        if (! battle.hook.validateMove(battle, state, moveIdx, msg.sender)) {
            revert InvalidMove();
        }

        // store revealed move
        if (msg.sender == battle.p1) {
            battleStates[battleKey].p1MoveHistory.push(RevealedMove({moveIdx: moveIdx, salt: salt}));
        } else {
            battleStates[battleKey].p2MoveHistory.push(RevealedMove({moveIdx: moveIdx, salt: salt}));
        }
    }

    function execute(bytes32 battleKey) external {
        // validate both moves have been revealed for the current turn
        // (accessing the values will revert if they haven't been set)
        uint256 turnId = battleStates[battleKey].turnId;
        RevealedMove memory p1Move = battleStates[battleKey].p1MoveHistory[turnId];
        RevealedMove memory p2Move = battleStates[battleKey].p2MoveHistory[turnId];

        // Before turn effects
        // Check priorities, then execute move, check for end of game, execute move, then check for end of game
        // if knocked out, then swapping is an action where the other person can only do a no-op
        // Check for end of turn effects
        // If end of game, call end of game hook

    }

    function end(bytes32 battleKey) external {}
}

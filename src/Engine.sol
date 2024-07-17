// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

contract Engine {
    mapping(bytes32 battleKey => Battle) public battles;
    mapping(bytes32 battleKey => BattleState) public battleStates;
    mapping(bytes32 battleKey => mapping(address player => Commitment)) public commitments;

    /*
        - need to have a mapping of initial game states
        - need to track the move history for games
        - need a way for attacks to take in a reduced view of games to 
        - 
    */

    modifier onlyPlayer(bytes32 battleKey) {
        Battle memory battle = battles[battleKey];
        require(msg.sender == battle.p1 || msg.sender == battle.p2, "not player");
        _;
    }

    /**
     * - validate game state before starting
     *     - if so, update nonces and store the starting state
     *     - (TODO) call external validator to validate battle has started
     */
    function start(Battle calldata battle) external {
        // validate battle
        battle.hook.validateGameStart(battle);

        // store battle
        bytes32 battleKey = sha256(abi.encode(battle.salt, battle.p1, battle.p2));
        battles[battleKey] = battle;

        // initialize battle state
        BattleState memory battleState = BattleState({
            turnId: 0,
            p1ActiveMon: battle.p1ActiveMon,
            p2ActiveMon: battle.p2ActiveMon,
            p1TeamState: new MonState[](battle.p1Team.length),
            p2TeamState: new MonState[](battle.p2Team.length),
            p1MoveHistory: new RevealedMove[](0),
            p2MoveHistory: new RevealedMove[](0),
            extraData: bytes("")
        });

        // let hook modify initial state
        battleState = battle.hook.modifyInitialState(battleState);

        // store initial state
        battleStates[battleKey] = battleState;
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external onlyPlayer(battleKey) {
        // validate no commitment exists for this turn
        uint256 turnId = battleStates[battleKey].turnId;
        require(commitments[battleKey][msg.sender].turnId != turnId, "commitment already exists");

        // store commitment
        commitments[battleKey][msg.sender] =
            Commitment({moveHash: moveHash, turnId: turnId, timestamp: block.timestamp});
    }

    function revealMove(bytes32 battleKey, uint256 moveIdx, bytes32 salt) external onlyPlayer(battleKey) {
        // validate preimage
        Commitment memory commitment = commitments[battleKey][msg.sender];
        Battle memory battle = battles[battleKey];
        BattleState memory state = battleStates[battleKey];
        require(commitment.turnId == state.turnId, "incorrect turnId");
        require(keccak256(abi.encodePacked(moveIdx, salt)) == commitment.moveHash, "incorrect preimage for hash");

        // store revealed move
        if (msg.sender == battle.p1) {
            battleStates[battleKey].p1MoveHistory.push(RevealedMove({moveIdx: moveIdx, salt: salt}));
        } else {
            battleStates[battleKey].p2MoveHistory.push(RevealedMove({moveIdx: moveIdx, salt: salt}));
        }
    }

    /**
     * - how to represent moves that a player takes?
     *     - a move is either a swap or a move on the active monster
     *     - so it's either a sentinel value we can decode, or it's a move index (which we can find assuming the mon records are following the right pattern)
     *     -
     */
    function execute(bytes32 battleKey) external {}

    // TODO: have simulate() function for non-external calls / replays

    function end(bytes32 battleKey) external {}
}

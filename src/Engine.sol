// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";
import {IBattleValidator} from "./IBattleValidator.sol";

contract Engine {
    mapping(bytes32 => Battle) public battles;

    /*
        - need to have a mapping of initial game states
        - need to track the move history for games
        - need a way for attacks to take in a reduced view of games to 
        - 
    */

    /**
     * - validate game state before starting
     *     - if so, update nonces and store the starting state
     *     - (TODO) call external validator to validate battle has started
     */
    function start(Battle calldata battle) external {
        IBattleValidator(battle.battleValidator).validateGameStart(battle);
        bytes32 battleKey = sha256(abi.encode(battle.salt, battle.p1, battle.p2));
        battles[battleKey] = battle;
    }

    function commitMove(bytes32 battleKey, bytes32 moveHash) external {}

    function revealMove(bytes32 battleKey, uint256 moveIdx, bytes32 salt) external {}

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

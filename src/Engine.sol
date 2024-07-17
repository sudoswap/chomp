// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IBattleConsumer} from "./IBattleConsumer.sol";
import {IBattleValidator} from "./IBattleValidator.sol";

contract Engine is IBattleConsumer {

    mapping(address => uint256) public playerNonce;
    mapping(bytes32 => Battle) public initialBattleState;

    /*
        - need to have a mapping of initial game states
        - need to track the move history for games
        - need a way for attacks to take in a reduced view of games to 
        - 
    */

    /**
        - validate game state before starting
        - if so, update nonces and store the starting state
        - (TODO) call external validator to validate battle has started
     */
    function start(Battle memory initialState) external {
        IBattleValidator(initialState.battleValidator).validateGameStart(initialState);
        uint256 p1Nonce = playerNonce[initialState.p1];
        uint256 p2Nonce = playerNonce[initialState.p2];
        bytes32 battleKey = sha256(abi.encode(p1Nonce, p2Nonce, initialState.p1, initialState.p2, address(this)));
        initialBattleState[battleKey] = initialState;
    }

    /**
        - how to represent moves that a player takes?
        - a move is either a swap or a move on the active monster
        - so it's either a sentinel value we can decode, or it's a move index (which we can find assuming the mon records are following the right pattern)
        - 
     */
    function execute(bytes32 battleKey, uint256 p1MoveIndex, bytes memory p1ExtraArgs, uint256 p2MoveIndex, bytes memory p2ExtraArgs) external {

    }

    // TODO: have simulate() function for non-external calls / replays

    function end(bytes32 battleKey) external {

    }
}
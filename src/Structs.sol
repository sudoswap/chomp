// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IMoveSet} from "./IMoveSet.sol";
import {IHook} from "./IHook.sol";

// battle vars are split into immutable and mutable parts
// active mon and team stats are variable, the rest are not
struct Battle {
    address p1;
    uint256 p1ActiveMon;
    address p2;
    uint256 p2ActiveMon;
    IHook hook;
    Mon[] p1Team;
    Mon[] p2Team;
    bytes32 salt;
    bytes extraData;
}

struct BattleState {
    uint256 turnId;
    uint256 p1ActiveMon;
    uint256 p2ActiveMon;
    uint256 pAllowanceFlag; // 0 for both players, 1 for p1, 2 for p2
    MonState[] p1TeamState;
    MonState[] p2TeamState;
    RevealedMove[] p1MoveHistory;
    RevealedMove[] p2MoveHistory;
    bytes extraData;
}

struct Mon {
    uint256 hp;
    uint256 stamina;
    uint256 speed;
    uint256 attack;
    uint256 defence;
    uint256 specialAttack;
    uint256 specialDefence;
    Move[] moves;
    bytes extraData;
}

struct MonState {
    int256 hpDelta;
    int256 staminaDelta;
    int256 speedDelta;
    int256 attackDelta;
    int256 defenceDelta;
    int256 specialAttackDelta;
    int256 specialDefenceDelta;
    bytes extraData;
}

struct Move {
    IMoveSet moveSet;
    uint256 moveId;
}

struct Commitment {
    bytes32 moveHash;
    uint256 turnId;
    uint256 timestamp;
}

struct RevealedMove {
    uint256 moveIdx;
    bytes32 salt;
    bytes extraData;
}

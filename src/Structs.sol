// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IMoveSet} from "./IMoveSet.sol";

// battle vars are split into immutable and mutable parts
// active mon and team stats are variable, the rest are not
struct Battle {
    address p1;
    uint96 p1ActiveMon;
    address p2;
    uint96 p2ActiveMon;
    address battleValidator;
    address externalHook;
    Mon[] p1Team;
    Mon[] p2Team;
    bytes32 salt;
    bytes extraData;
}

struct BattleState {
    uint32 p1ActiveMon;
    uint32 p2ActiveMon;
    MonState[] p1TeamState;
    MonState[] p2TeamState;
    bytes extraData;
}

struct Mon {
    uint32 hp;
    uint32 stamina;
    uint32 speed;
    uint32 attack;
    uint32 defence;
    uint32 specialAttack;
    uint32 specialDefence;
    Move[] moves;
    bytes extraData;
}

struct MonState {
    int32 hpDelta;
    int32 staminaDelta;
    int32 speedDelta;
    int32 attackDelta;
    int32 defenceDelta;
    int32 specialAttackDelta;
    int32 specialDefenceDelta;
    bytes extraData;
}

struct Move {
    IMoveSet moveSet;
    uint256 moveId;
}

// TODO: game state altering effects

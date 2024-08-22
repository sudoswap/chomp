// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Type} from "./Enums.sol";
import {IRuleset} from "./IRuleset.sol";
import {IValidator} from "./IValidator.sol";

import {IAbility} from "./abilities/IAbility.sol";
import {IEffect} from "./effects/IEffect.sol";
import {IMoveSet} from "./moves/IMoveSet.sol";
import {IRandomnessOracle} from "./rng/IRandomnessOracle.sol";

struct Battle {
    address p0;
    address p1;
    IValidator validator;
    IRandomnessOracle rngOracle;
    IRuleset ruleset;
    Mon[][] teams;
}

struct BattleState {
    uint256 turnId;
    uint256 playerSwitchForTurnFlag; // 0 for p0 only move, 1 for p1 only move, 2 for both players
    MonState[][] monStates;
    uint256[] activeMonIndex;
    RevealedMove[][] moveHistory;
    uint256[] pRNGStream;
    address winner;
    IEffect[] globalEffects;
    bytes[] extraDataForGlobalEffects;
}

struct MonStats {
    uint32 hp;
    uint32 stamina;
    uint32 speed;
    uint32 attack;
    uint32 defence;
    uint32 specialAttack;
    uint32 specialDefence;
    Type type1;
    Type type2;
}

struct Mon {
    MonStats stats;
    IMoveSet[] moves;
    IAbility ability;
}

struct MonState {
    int32 hpDelta;
    int32 staminaDelta;
    int32 speedDelta;
    int32 attackDelta;
    int32 defenceDelta;
    int32 specialAttackDelta;
    int32 specialDefenceDelta;
    bool isKnockedOut; // Is either 0 or 1
    bool shouldSkipTurn; // Used for effects to skip turn, or when moves become invalid (outside of user control)
    IEffect[] targetedEffects;
    bytes[] extraDataForTargetedEffects;
}

struct Commitment {
    bytes32 moveHash;
    uint256 turnId;
    uint256 timestamp;
}

struct RevealedMove {
    uint256 moveIndex;
    bytes32 salt;
    bytes extraData;
}

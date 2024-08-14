// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Type} from "./Enums.sol";
import {IRuleset} from "./IRuleset.sol";
import {IValidator} from "./IValidator.sol";
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

struct Mon {
    uint256 hp;
    uint256 stamina;
    uint256 speed;
    uint256 attack;
    uint256 defence;
    uint256 specialAttack;
    uint256 specialDefence;
    Type type1;
    Type type2;
    IMoveSet[] moves;
}

struct MonState {
    int256 hpDelta;
    int256 staminaDelta;
    int256 speedDelta;
    int256 attackDelta;
    int256 defenceDelta;
    int256 specialAttackDelta;
    int256 specialDefenceDelta;
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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

// Error codes
uint256 constant NO_WRITE_ALLOWED = 0;
uint256 constant WRONG_CALLER = 1;
uint256 constant BATTLE_CHANGED_BEFORE_ACCEPTANCE = 2;
uint256 constant INVALID_P0_TEAM_HASH = 3;
uint256 constant BATTLE_NOT_STARTED = 4;
uint256 constant NOT_P0_OR_P1 = 5;
uint256 constant ALREADY_COMMITED = 6;
uint256 constant ALREADY_REVEALED = 7;
uint256 constant REVEAL_BEFORE_OTHER_COMMIT = 8;
uint256 constant WRONG_TURN_ID = 9;
uint256 constant WRONG_PREIMAGE = 10;
uint256 constant INVALID_MOVE_P0 = 11;
uint256 constant INVALID_MOVE_P1 = 12;
uint256 constant PLAYER_NOT_ALLOWED = 13;
uint256 constant INVALID_BATTLE_CONFIG = 14;
uint256 constant GAME_ALREADY_OVER = 15;
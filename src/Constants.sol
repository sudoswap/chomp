// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

uint256 constant NO_OP_MOVE_INDEX = type(uint256).max - 1;
uint256 constant SWITCH_MOVE_INDEX = type(uint256).max - 2;

uint256 constant SWITCH_PRIORITY = 6;
uint32 constant DEFAULT_PRIORITY = 3;

uint32 constant CRIT_NUM = 3;
uint32 constant CRIT_DENOM = 2;
uint256 constant DEFAULT_CRIT_RATE = 5;

uint256 constant DEFAULT_VOL = 10;

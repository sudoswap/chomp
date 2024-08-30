// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IEffect} from "../../src/effects/IEffect.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";

contract InvalidMove is IMoveSet {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "Effect Attack";
    }

    function move(bytes32, uint256, bytes memory, uint256) external pure returns (bool) {
        return false;
    }

    function priority(bytes32) external pure returns (uint32) {
        return 1;
    }

    function stamina(bytes32) external pure returns (uint32) {
        return 1;
    }

    function moveType(bytes32) external pure returns (Type) {
        return Type.Fire;
    }

    function isValidTarget(bytes32) external pure returns (bool) {
        return false;
    }

    function postMoveSwitch(bytes32, uint256, bytes calldata) external pure returns (uint256, uint256) {
        // No-op
        return (NO_SWITCH_FLAG, NO_SWITCH_FLAG);
    }

    function moveClass(bytes32) external pure returns (MoveClass) {
        return MoveClass.Physical;
    }
}
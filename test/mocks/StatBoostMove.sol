// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";

import {StatBoost} from "../../src/effects/StatBoost.sol";

contract StatBoostMove is IMoveSet {

    IEngine immutable ENGINE;
    StatBoost immutable STAT_BOOST;

    constructor(IEngine _ENGINE, StatBoost _STAT_BOOST) {
        ENGINE = _ENGINE;
        STAT_BOOST = _STAT_BOOST;
    }

    function name() external pure returns (string memory) {
        return "";
    }

    function move(bytes32, uint256, bytes memory extraData, uint256) external {
        (uint256 playerIndex, uint256 monIndex, uint256 statIndex, int32 boostAmount) = abi.decode(extraData, (uint256, uint256, uint256, int32));
        ENGINE.addEffect(playerIndex, monIndex, STAT_BOOST, abi.encode(statIndex, boostAmount));
    }

    function priority(bytes32) external pure returns (uint32) {
        return 0;
    }

    function stamina(bytes32) external pure returns (uint32) {
        return 0;
    }

    function moveType(bytes32) external pure returns (Type) {
        return Type.Air;
    }

    function isValidTarget(bytes32, bytes calldata) external pure returns (bool) {
        return true;
    }

    function moveClass(bytes32) external pure returns (MoveClass) {
        return MoveClass.Physical;
    }

    function basePower(bytes32) external pure returns (uint32) {
        return 0;
    }

}
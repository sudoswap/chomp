// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../Enums.sol";
import "../../Constants.sol";
import {IMoveSet} from "../../moves/IMoveSet.sol";
import {IEngine} from "../../IEngine.sol";
import {AttackCalculator} from "../../moves/AttackCalculator.sol";
import {ITypeCalculator} from "../../types/ITypeCalculator.sol";

contract RockPull is IMoveSet {

    IEngine immutable ENGINE;
    ITypeCalculator immutable TYPE_CALCULATOR;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR) {
        ENGINE = _ENGINE;
        TYPE_CALCULATOR = _TYPE_CALCULATOR;
    }

    function name() public pure override returns (string memory) {
        return "Rock Pull";
    }

    function _didOtherPlayerChooseSwitch(bytes32 battleKey, uint256 attackerPlayerIndex) internal view returns (bool) {
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng) external {
    }

    function stamina(bytes32, uint256, uint256) external pure returns (uint32) {
        return 3;
    }

    function priority(bytes32 battleKey, uint256 attackerPlayerIndex) external view returns (uint32) {
        if (_didOtherPlayerChooseSwitch(battleKey, attackerPlayerIndex)) {
            return uint32(SWITCH_PRIORITY) + 1;
        }
        else {
            return DEFAULT_PRIORITY;
        }
    }

    function moveType(bytes32) public pure returns (Type) {
        return Type.Earth;
    }

    function moveClass(bytes32) public pure returns (MoveClass) {
        return MoveClass.Physical;
    }

    function isValidTarget(bytes32, bytes calldata) external pure returns (bool) {
        return true;
    }
}
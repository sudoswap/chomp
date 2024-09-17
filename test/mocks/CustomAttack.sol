// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

import {AttackCalculator} from "../../src/moves/AttackCalculator.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";

contract CustomAttack is AttackCalculator, IMoveSet {
    struct Args {
        Type TYPE;
        uint32 BASE_POWER;
        uint32 ACCURACY;
        uint32 STAMINA_COST;
        uint32 PRIORITY;
    }

    Type immutable TYPE;
    uint32 immutable BASE_POWER;
    uint32 immutable ACCURACY;
    uint32 immutable STAMINA_COST;
    uint32 immutable PRIORITY;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR, Args memory args)
        AttackCalculator(_ENGINE, _TYPE_CALCULATOR)
    {
        TYPE = args.TYPE;
        BASE_POWER = args.BASE_POWER;
        ACCURACY = args.ACCURACY;
        STAMINA_COST = args.STAMINA_COST;
        PRIORITY = args.PRIORITY;
    }

    function name() external pure returns (string memory) {
        return "CustomAttack";
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng)
        external
        returns (bool)
    {
        calculateDamage(
            battleKey, attackerPlayerIndex, BASE_POWER, ACCURACY, STAMINA_COST, TYPE, MoveClass.Physical, rng
        );
        return false;
    }

    function priority(bytes32) external view returns (uint32) {
        return PRIORITY;
    }

    function stamina(bytes32) external view returns (uint32) {
        return STAMINA_COST;
    }

    function moveType(bytes32) external view returns (Type) {
        return TYPE;
    }

    function isValidTarget(bytes32) external pure returns (bool) {
        return true;
    }

    function postMoveSwitch(bytes32, uint256, bytes calldata) external pure returns (uint256, uint256) {
        // No-op
        return (NO_SWITCH_FLAG, NO_SWITCH_FLAG);
    }

    function moveClass(bytes32) external pure returns (MoveClass) {
        return MoveClass.Physical;
    }

    function basePower(bytes32) external view returns (uint32) {
        return BASE_POWER;
    }
}

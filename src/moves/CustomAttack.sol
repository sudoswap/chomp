// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Constants.sol";
import "../Enums.sol";
import "../Structs.sol";

import {IEngine} from "../IEngine.sol";
import {ITypeCalculator} from "../types/ITypeCalculator.sol";

import {AttackCalculator} from "./AttackCalculator.sol";
import {IMoveSet} from "./IMoveSet.sol";

contract CustomAttack is AttackCalculator, IMoveSet {
    struct Args {
        Type TYPE;
        uint256 BASE_POWER;
        uint256 ACCURACY;
        uint256 STAMINA_COST;
        uint256 PRIORITY;
    }

    Type immutable TYPE;
    uint256 immutable BASE_POWER;
    uint256 immutable ACCURACY;
    uint256 immutable STAMINA_COST;
    uint256 immutable PRIORITY;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR, Args memory args)
        AttackCalculator(_ENGINE, _TYPE_CALCULATOR)
    {
        TYPE = args.TYPE;
        BASE_POWER = args.BASE_POWER;
        ACCURACY = args.ACCURACY;
        STAMINA_COST = args.STAMINA_COST;
        PRIORITY = args.PRIORITY;
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng)
        external
        returns (bool)
    {
        calculateDamage(
            battleKey, attackerPlayerIndex, BASE_POWER, ACCURACY, STAMINA_COST, TYPE, AttackSupertype.Physical, rng
        );
        return false;
    }

    function priority(bytes32) external view returns (uint256) {
        return PRIORITY;
    }

    function stamina(bytes32) external view returns (uint256) {
        return STAMINA_COST;
    }

    function moveType(bytes32) external view returns (Type) {
        return TYPE;
    }

    function isValidTarget(bytes32) external pure returns (bool) {
        return true;
    }

    function postMoveSwitch(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata extraData)
        external
        pure
        returns (uint256, uint256)
    {
        // No-op
        return (NO_SWITCH_FLAG, NO_SWITCH_FLAG);
    }
}

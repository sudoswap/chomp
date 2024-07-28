// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEngine} from "../IEngine.sol";
import {ITypeCalculator} from "../types/ITypeCalculator.sol";

import {IMoveSet} from "./IMoveSet.sol";
import {AttackCalculator} from "./AttackCalculator.sol";

contract CustomAttack is AttackCalculator, IMoveSet {

    struct Args {
        uint256 BASE_POWER;
        uint256 ACCURACY;
        uint256 STAMINA_COST;
    }

    Type immutable TYPE;
    uint256 immutable BASE_POWER;
    uint256 immutable ACCURACY;
    uint256 immutable STAMINA_COST;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR, Type _TYPE, Args memory args)
        AttackCalculator(_ENGINE, _TYPE_CALCULATOR)
    {
        TYPE = _TYPE;
        BASE_POWER = args.BASE_POWER;
        ACCURACY = args.ACCURACY;
        STAMINA_COST = args.STAMINA_COST;
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng)
        external
        view
        returns (MonState[][] memory, uint256[] memory, IEffect[][] memory, bytes[][] memory, bytes32, bytes32)
    {
        return calculateDamage(
            battleKey, attackerPlayerIndex, BASE_POWER, ACCURACY, STAMINA_COST, TYPE, AttackSupertype.Physical, rng
        );
    }

    function priority(bytes32) external pure returns (uint256) {
        return 1;
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
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";
import "../../src/Enums.sol";

contract TestTypeCalculator is ITypeCalculator {
    function getTypeEffectiveness(Type attackerType, Type defenderType) external pure returns (uint32) {
        return 1;
    }
}
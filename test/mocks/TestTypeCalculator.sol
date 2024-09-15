// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import {ITypeCalculator} from "../../src/types/ITypeCalculator.sol";

contract TestTypeCalculator is ITypeCalculator {
    function getTypeEffectiveness(Type, Type, uint32 basePower) external pure returns (uint32) {
        return basePower;
    }
}

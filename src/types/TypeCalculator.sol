
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ITypeCalculator} from "./ITypeCalculator.sol";
import "../Enums.sol";

contract TypeCalculator is ITypeCalculator {
    uint256 private constant MULTIPLIERS_1 = 98387940970013939441334902218489111171706662712193966632938886332804419114328; // First 128 type combinations
    uint256 private constant MULTIPLIERS_2 = 8859915444081173009646859022170283285020904064171667527525; // Remaining 97 type combinations

    function getTypeEffectiveness(Type attackerType, Type defenderType) external pure returns (uint32) {
        uint256 index = uint256(attackerType) * 15 + uint256(defenderType);
        uint256 shift;
        uint256 multipliers;
        
        if (index < 128) {
            shift = index * 2;
            multipliers = MULTIPLIERS_1;
        } else {
            shift = (index - 128) * 2;
            multipliers = MULTIPLIERS_2;
        }
        
        // Return the last 2 bits of the multipliers for the correct shift
        return uint32((multipliers >> shift) & 3);
    }
}

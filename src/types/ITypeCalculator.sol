// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";

interface ITypeCalculator {
    function getTypeEffectiveness(Type attackerType, Type defenderType) external view returns (uint256);
}

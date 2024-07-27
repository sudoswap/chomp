// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEffect} from "../effects/IEffect.sol";

interface IMoveSet {
    function move(bytes32 battleKey, bytes calldata extraData, uint256 rng)
        external
        pure
        returns (
            MonState[][] memory monStates, // Convention is index 0 is p0 effects, 1 is p1 effects, and 2 is global effects
            uint256[] memory activeMons,
            IEffect[][] memory effects,
            bytes[][] memory extraDataForEffects
        );
    function priority(bytes32 battleKey) external pure returns (uint256);
    function stamina(bytes32 battleKey) external pure returns (uint256);
    function moveType(bytes32 battleKey) external pure returns (Type);
    function isValidTarget(bytes32 battleKey) external pure returns (bool);
}

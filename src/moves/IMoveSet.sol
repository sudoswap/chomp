// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEffect} from "../effects/IEffect.sol";

interface IMoveSet {
    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata extraData, uint256 rng)
        external
        returns (
            MonState[][] memory monStates,
            uint256[] memory activeMons,
            IEffect[][] memory newEffects,
            bytes[][] memory extraDataForEffects,
            bytes32 globalK,
            bytes32 globalV
        );
    function priority(bytes32 battleKey) external view returns (uint256);
    function stamina(bytes32 battleKey) external view returns (uint256);
    function moveType(bytes32 battleKey) external view returns (Type);
    function isValidTarget(bytes32 battleKey) external view returns (bool);
}

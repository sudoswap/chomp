// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IMoveSet {
    function move(bytes32 battleKey, bytes calldata extraData, uint256 rng)
        external
        pure
        returns (MonState[][] memory monStates);
    function priority(bytes32 battleKey) external pure returns (uint256);
    function stamina(bytes32 battleKey) external pure returns (uint256);
    function moveType(bytes32 battleKey) external pure returns (uint256);
    function isValidTarget(bytes32 battleKey) external pure returns (bool);
}

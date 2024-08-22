// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IAbility {
    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external;
}

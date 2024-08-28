// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

import "../abilities/IAbility.sol";
import "../moves/IMoveSet.sol";

interface IMonRegistry {
    function getMonData(uint256 monId)
        external
        returns (MonStats memory mon, address[] memory moves, address[] memory abilities);
    function getMonStats(uint256 monId) external view returns (MonStats memory);
    function getMonCount() external view returns (uint256);
    function isValidMove(uint256 monId, IMoveSet move) external view returns (bool);
    function isValidAbility(uint256 monId, IAbility ability) external view returns (bool);
}

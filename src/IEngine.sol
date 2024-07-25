// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IEngine {
    function getBattle(bytes32 battleKey) external view returns (Battle memory);
    function getBattleState(bytes32 battleKey) external view returns (BattleState memory);
}
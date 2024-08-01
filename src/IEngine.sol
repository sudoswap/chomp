// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IEngine {
    function getBattle(bytes32 battleKey) external view returns (Battle memory);
    function getTeamsForBattle(bytes32 battleKey) external view returns (Mon[][] memory);
    function getPlayersForBattle(bytes32 battleKey) external view returns (address[] memory);

    function getBattleState(bytes32 battleKey) external view returns (BattleState memory);
    function getMoveHistoryForBattleState(bytes32 battleKey) external view returns (RevealedMove[][] memory);
    function getMonStatesForBattleState(bytes32 battleKey) external view returns (MonState[][] memory);
    function getTurnIdForBattleState(bytes32 battleKey) external view returns (uint256);
    function getActiveMonIndexForBattleState(bytes32 battleKey) external view returns (uint256[] memory);
    function getPlayerSwitchForTurnFlagForBattleState(bytes32 battleKey) external view returns (uint256);

    function getGlobalKV(bytes32 battleKey, bytes32 key) external view returns (bytes32);
    function getCommitment(bytes32 battleKey, address player) external view returns (Commitment memory);
}

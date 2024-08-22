// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Enums.sol";
import "./Structs.sol";

interface IEngine {
    // Global battle key to determine which battle to apply state mutations
    function battleKeyForWrite() external view returns (bytes32);

    // Getters
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

    // State mutating effects
    function updateMonState(uint256 playerIndex, uint256 monIndex, MonStateIndexName stateVarIndex, int32 valueToAdd)
        external;
    function addEffect(uint256 targetIndex, uint256 monIndex, IEffect effect, bytes memory extraData) external;
    function removeEffect(uint256 targetIndex, uint256 monIndex, uint256 effectIndex) external;
    function setGlobalKV(bytes32 key, bytes32 value) external;
}

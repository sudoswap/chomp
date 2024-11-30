// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Enums.sol";

import "./ICommitManager.sol";
import "./IValidator.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

interface IEngine {
    // Global battle key to determine which battle to apply state mutations
    function battleKeyForWrite() external view returns (bytes32);

    // Getters
    function commitManager() external view returns (ICommitManager);
    function getBattle(bytes32 battleKey) external view returns (Battle memory);
    function getBattleState(bytes32 battleKey) external view returns (BattleState memory);

    function getMonValueForBattle(
        bytes32 battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        MonStateIndexName stateVarIndex
    ) external view returns (uint32);
    function getMonStateForBattle(
        bytes32 battleKey,
        uint256 playerIndex,
        uint256 monIndex,
        MonStateIndexName stateVarIndex
    ) external view returns (int32);
    function getMoveForMonForBattle(bytes32 battleKey, uint256 playerIndex, uint256 monIndex, uint256 moveIndex)
        external
        view
        returns (IMoveSet);
    function getPlayersForBattle(bytes32 battleKey) external view returns (address[] memory);
    function getTurnIdForBattleState(bytes32 battleKey) external view returns (uint256);
    function getActiveMonIndexForBattleState(bytes32 battleKey) external view returns (uint256[] memory);
    function getPlayerSwitchForTurnFlagForBattleState(bytes32 battleKey) external view returns (uint256);
    function getGlobalKV(bytes32 battleKey, bytes32 key) external view returns (bytes32);
    function getBattleStatus(bytes32 battleKey) external view returns (BattleProposalStatus);
    function getBattleValidator(bytes32 battleKey) external view returns (IValidator);

    // State mutating effects
    function updateMonState(uint256 playerIndex, uint256 monIndex, MonStateIndexName stateVarIndex, int32 valueToAdd)
        external;
    function addEffect(uint256 targetIndex, uint256 monIndex, IEffect effect, bytes memory extraData) external;
    function removeEffect(uint256 targetIndex, uint256 monIndex, uint256 effectIndex) external;
    function setGlobalKV(bytes32 key, bytes32 value) external;
    function dealDamage(uint256 playerIndex, uint256 monIndex, uint32 damage) external;
    function execute(bytes32 battleKey) external;
}

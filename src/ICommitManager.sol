// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface ICommitManager {
    function initMoveHistory(bytes32 battleKey) external returns (bool);
    function commitMove(bytes32 battleKey, bytes32 moveHash) external;
    function revealMove(bytes32 battleKey, uint256 moveIndex, bytes32 salt, bytes calldata extraData) external;
    function getCommitment(bytes32 battleKey, address player) external view returns (Commitment memory);
    function getMoveForBattleStateForTurn(bytes32 battleKey, uint256 playerIndex, uint256 turn) external view returns (RevealedMove memory);
    function getMoveCountForBattleState(bytes32 battleKey, uint256 playerIndex) external view returns (uint256);
}

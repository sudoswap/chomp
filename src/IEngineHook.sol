// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IEngineHook {
    function onBattleStart(bytes32 battleKey) external;
    function onRoundStart(bytes32 battleKey) external;
    function onRoundEnd(bytes32 battleKey) external;
    function onBattleEnd(bytes32 battleKey) external;
}

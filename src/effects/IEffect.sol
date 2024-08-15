// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

interface IEffect {
    function name() external returns (string memory);

    // Whether to run the effect at the start of the round
    function shouldRunAtStep(EffectStep r) external returns (bool);

    // Whether or not the effect should clear itself when the mon is being switched out
    // (not valid for global effects, can disregard)
    function shouldClearAfterMonSwitch() external returns (bool);

    // Lifecycle hooks during normal battle flow (either before or after start of round)
    function onRoundStart(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);
    function onRoundEnd(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);

    // Lifecycle hooks when being applied or removed
    function onApply(bytes memory extraData) external returns (bytes memory updatedExtraData);
    function onRemove(bytes memory extraData) external;
}

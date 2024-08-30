// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";
import {IMoveSet} from "../moves/IMoveSet.sol";

interface IEffect {
    function name() external returns (string memory);

    // Whether or not to add the effect
    function shouldApply(uint256 targetIndex, uint256 monIndex, bytes memory extraData) external returns (bool);

    // Whether to run the effect at the start of the round
    function shouldRunAtStep(EffectStep r) external returns (bool);

    // Lifecycle hooks during normal battle flow
    function onRoundStart(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);
    function onRoundEnd(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);
    function onMonSwitchIn(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);
    function onMonSwitchOut(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);
    function onAfterDamage(bytes32 battleKey, uint256 rng, bytes memory extraData, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun);

    // Lifecycle hooks when being applied or removed
    function onApply(uint256 targetIndex, uint256 monIndex, bytes memory extraData)
        external
        returns (bytes memory updatedExtraData);
    function onRemove(bytes memory extraData) external;
}

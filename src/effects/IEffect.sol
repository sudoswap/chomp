// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

interface IEffect {
    // Identifier (32 ASCII words)
    function name() external returns (string memory);

    // Whether or not an effect can be registered
    function isValidToRegister(bytes32 battleKey, uint256 targetIndex) external returns (bool);

    // Whether to run the effect at the start of the round
    function shouldRunAtRound(Round r) external returns (bool);

    // Whether or not the effect should clear itself when the mon is being switched out
    // (not valid for global effects, can disregard)
    function shouldClearAfterMonSwitch() external returns (bool);

    // Perform the effect, return updated state
    function runEffect(
        bytes32 battleKey,
        uint256 rng,
        bytes memory extraData,
        uint256 targetIndex // 0 for p0, and 1 for p1, and 2 for global effect (different from playerSwitchForTurnFlag, sorry!)
    ) external returns (bytes memory updatedExtraData, bool removeAfterHandle);
}

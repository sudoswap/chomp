// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {BasicEffect} from "../../src/effects/BasicEffect.sol";

contract InstantDeathEffect is BasicEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external override pure returns (string memory) {
        return "Instant Death";
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep r) external override pure returns (bool) {
        return r == EffectStep.RoundEnd;
    }

    function onRoundEnd(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.IsKnockedOut, 1);
        return ("", true);
    }
}

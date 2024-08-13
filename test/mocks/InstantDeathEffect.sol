// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

contract InstantDeathEffect is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "Instant Death";
    }

    // Irrelevant, as it will be registered at the beginning of the battle
    function isValidToRegister(bytes32, uint256) external pure returns (bool) {
        return true;
    }

    // Should run at end of round
    function shouldRunAtRound(Round r) external pure returns (bool) {
        if (r == Round.End) {
            return true;
        } else {
            return false;
        }
    }

    function shouldClearAfterMonSwitch() external pure returns (bool) {
        return false;
    }

    function runEffect(bytes32 battleKey, uint256, bytes memory, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterHandle)
    {
        uint256 activeMonIndex = ENGINE.getActiveMonIndexForBattleState(battleKey)[targetIndex];
        ENGINE.updateMonState(targetIndex, activeMonIndex, MonStateIndexName.IsKnockedOut, 1);
        return ("", true);
    }
}

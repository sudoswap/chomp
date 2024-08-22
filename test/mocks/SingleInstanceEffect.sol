// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IEffect} from "../../src/effects/IEffect.sol";

contract SingleInstanceEffect is IEffect {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function name() external pure returns (string memory) {
        return "Instant Death";
    }

    function shouldRunAtStep(EffectStep r) external pure returns (bool) {
        if (r == EffectStep.OnApply) {
            return true;
        }
        return false;
    }

    function shouldClearAfterMonSwitch() external pure returns (bool) {
        return false;
    }

    function onApply(uint256 targetIndex, uint256 monIndex, bytes memory)
        external
        returns (bytes memory)
    {
        bytes32 indexHash = keccak256(abi.encode(targetIndex, monIndex));
        ENGINE.setGlobalKV(indexHash, bytes32("true"));
        return "";
    }

    function shouldApply(uint256 targetIndex, uint256 monIndex, bytes memory) external view returns (bool) {
        bytes32 indexHash = keccak256(abi.encode(targetIndex, monIndex));
        bytes32 value = ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), indexHash);
        return value == bytes32(0);
    }

    // Everything below is an NoOp
    function onRemove(bytes memory) external {}
    function onRoundStart(bytes32, uint256, bytes memory, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}
    function onRoundEnd(bytes32 battleKey, uint256, bytes memory, uint256 targetIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}
    function onMonSwitchIn(bytes32, uint256, bytes memory, uint256)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}
}

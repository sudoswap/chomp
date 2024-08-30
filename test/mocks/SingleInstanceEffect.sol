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
        return r == EffectStep.OnApply;
    }

    function onApply(uint256, bytes memory, uint256 targetIndex, uint256 monIndex) external returns (bytes memory) {
        bytes32 indexHash = keccak256(abi.encode(targetIndex, monIndex));
        ENGINE.setGlobalKV(indexHash, bytes32("true"));
        return "";
    }

    function shouldApply(bytes memory, uint256 targetIndex, uint256 monIndex) external view returns (bool) {
        bytes32 indexHash = keccak256(abi.encode(targetIndex, monIndex));
        bytes32 value = ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), indexHash);
        return value == bytes32(0);
    }

    // Everything below is an NoOp
    // Lifecycle hooks during normal battle flow
    function onRoundStart(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    function onRoundEnd(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: ONLY RUN ON GLOBAL EFFECTS (mons have their Ability as their own hook to apply an effect on switch in)
    function onMonSwitchIn(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onMonSwitchOut(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    // NOTE: CURRENTLY ONLY RUN LOCALLY ON MONS (global effects do not have this hook)
    function onAfterDamage(uint256 rng, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {}

    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external {}
}

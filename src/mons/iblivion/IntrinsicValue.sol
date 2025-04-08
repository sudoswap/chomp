// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {BasicEffect} from "../../effects/BasicEffect.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {StatBoost} from "../../effects/StatBoost.sol";
import {Baselight} from "../iblivion/Baselight.sol";

contract IntrinsicValue is IAbility, BasicEffect {

    IEngine immutable ENGINE;
    Baselight immutable BASELIGHT;
    IEffect immutable STAT_BOOST;

    constructor(IEngine _ENGINE, Baselight _BASELIGHT, IEffect _STAT_BOOST) {
        ENGINE = _ENGINE;
        BASELIGHT = _BASELIGHT;
        STAT_BOOST = _STAT_BOOST;
    }

    function name() public pure override(IAbility, BasicEffect) returns (string memory) {
        return "Intrinsic Value";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external {
        // Check if the effect has already been set for this mon
        bytes32 monEffectId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monEffectId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon when it switches in
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monEffectId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), abi.encode(0));
        }
    }

    // Should run at end of round
    function shouldRunAtStep(EffectStep step) external pure override returns (bool) {
        return (step == EffectStep.RoundEnd);
    }

    function onRoundEnd(uint256, bytes memory, uint256 targetIndex, uint256 monIndex)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        bool statsReset = false;

        // Check for negative stat boosts in ATK/DEF/SpATK/SpDEF/SPD:
        uint256[] memory statIndexNames = new uint256[](5);
        statIndexNames[0] = uint256(MonStateIndexName.Attack);
        statIndexNames[1] = uint256(MonStateIndexName.Defense);
        statIndexNames[2] = uint256(MonStateIndexName.SpecialAttack);
        statIndexNames[3] = uint256(MonStateIndexName.SpecialDefense);
        statIndexNames[4] = uint256(MonStateIndexName.Speed);
        for (uint256 i = 0; i < statIndexNames.length; i++) {
            bytes32 statKey = StatBoost(address(STAT_BOOST)).getKeyForMonIndex(targetIndex, monIndex, uint256(statIndexNames[i]));
            int32 existingBoostAmount = int32(int256(uint256(ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), statKey))));
            // Reset the stat debuff
            if (existingBoostAmount < 0) {
                int32 resetBoostAmount = existingBoostAmount * -1;
                bytes memory boostData = abi.encode(targetIndex, monIndex, statIndexNames[i], resetBoostAmount);
                ENGINE.addEffect(targetIndex, monIndex, STAT_BOOST, boostData);
                statsReset = true;
            }
        }
        if (statsReset) {
            BASELIGHT.increaseBaselightLevel(targetIndex, monIndex);
        }
        return ("", false);
    }
}
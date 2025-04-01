// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep, MonStateIndexName} from "../../Enums.sol";
import {IEngine} from "../../IEngine.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {BasicEffect} from "../../effects/BasicEffect.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {StatBoost} from "../../effects/StatBoost.sol";

contract Interweaving is IAbility, BasicEffect {
    int32 constant DECREASE_DENOM = 10;
    IEngine immutable ENGINE;
    IEffect immutable STAT_BOOST;

    constructor(IEngine _ENGINE, IEffect _STAT_BOOST) {
        ENGINE = _ENGINE;
        STAT_BOOST = _STAT_BOOST;
    }

    function name() public pure override(IAbility, BasicEffect) returns (string memory) {
        return "Interweaving";
    }

    function activateOnSwitch(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) external {
        // Lower opposing mon Attack stat
        uint256 otherPlayerIndex = (playerIndex + 1) % 2;
        uint256 otherPlayerActiveMonIndex =
            ENGINE.getActiveMonIndexForBattleState(ENGINE.battleKeyForWrite())[otherPlayerIndex];
        // Decrease by 1/DECREASE_DENOM of base Attack stat
        int32 decreaseAmount = -1
            * int32(
                ENGINE.getMonValueForBattle(
                    ENGINE.battleKeyForWrite(), otherPlayerIndex, otherPlayerActiveMonIndex, MonStateIndexName.Attack
                )
            ) / DECREASE_DENOM;
        bytes memory statBoostArgs = abi.encode(uint256(MonStateIndexName.Attack), decreaseAmount);
        ENGINE.addEffect(otherPlayerIndex, otherPlayerActiveMonIndex, STAT_BOOST, statBoostArgs);

        // Check if the effect has already been set for this mon
        bytes32 monEffectId = keccak256(abi.encode(playerIndex, monIndex, name()));
        if (ENGINE.getGlobalKV(battleKey, monEffectId) != bytes32(0)) {
            return;
        }
        // Otherwise, add this effect to the mon when it switches in
        // This way we can trigger on switch out
        else {
            uint256 value = 1;
            ENGINE.setGlobalKV(monEffectId, bytes32(value));
            ENGINE.addEffect(playerIndex, monIndex, IEffect(address(this)), abi.encode(0));
        }
    }

    function shouldRunAtStep(EffectStep step) external pure override returns (bool) {
        return (step == EffectStep.OnMonSwitchOut || step == EffectStep.OnApply);
    }

    function onMonSwitchOut(uint256, bytes memory, uint256 targetIndex, uint256)
        external
        override
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        uint256 otherPlayerIndex = (targetIndex + 1) % 2;
        uint256 otherPlayerActiveMonIndex =
            ENGINE.getActiveMonIndexForBattleState(ENGINE.battleKeyForWrite())[otherPlayerIndex];
        // Decrease by 1/DECREASE_DENOM of base Special Attack stat
        int32 decreaseAmount = -1
            * int32(
                ENGINE.getMonValueForBattle(
                    ENGINE.battleKeyForWrite(), otherPlayerIndex, otherPlayerActiveMonIndex, MonStateIndexName.SpecialAttack
                )
            ) / DECREASE_DENOM;
        bytes memory statBoostArgs = abi.encode(uint256(MonStateIndexName.SpecialAttack), decreaseAmount);
        ENGINE.addEffect(otherPlayerIndex, otherPlayerActiveMonIndex, STAT_BOOST, statBoostArgs);
        return ("", false);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import {EffectStep} from "../../Enums.sol";
import {IAbility} from "../../abilities/IAbility.sol";
import {IEffect} from "../../effects/IEffect.sol";
import {IEngine} from "../../IEngine.sol";
import {MonStateIndexName} from "../../Enums.sol";

contract Angery is IAbility, IEffect {
    uint256 constant public CHARGE_COUNT = 3; // After 3 charges, consume all charges to heal
    int32 constant public HP_THRESHOLD_DENOM = 3; // If more than 1/3 damage dealt in 1 hit, gain 2 charges
    int32 constant public MAX_HP_DENOM = 8; // Heal for 1/8 of HP

    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    // IAbility implementation
    function name() public pure override(IAbility, IEffect) returns (string memory)  {
        return "Angery";
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

    // IEffect implementation
    function shouldRunAtStep(EffectStep step) external pure returns (bool) {
        return (step == EffectStep.RoundEnd || step == EffectStep.AfterDamage);
    }

    function shouldApply(bytes memory, uint256, uint256) external pure returns (bool) {
        return true;
    }

    // Regain stamina on round end, this can overheal stamina
    function onRoundEnd(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        uint256 numCharges = abi.decode(extraData, (uint256));
        if (numCharges == CHARGE_COUNT) {
            // Heal for 1/8 of max HP
            int32 healAmount = int32(ENGINE.getMonValueForBattle(ENGINE.battleKeyForWrite(), targetIndex, monIndex, MonStateIndexName.Hp)) / MAX_HP_DENOM;
            ENGINE.updateMonState(targetIndex, monIndex, MonStateIndexName.Hp, healAmount);
            // Reset the damage counter
            return (abi.encode(numCharges - CHARGE_COUNT), false);
        }
        else {
            return (extraData, false);
        }
    }

    function onAfterDamage(uint256, bytes memory extraData, uint256 targetIndex, uint256 monIndex, int32 damageDealt)
        external
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        uint256 numCharges = abi.decode(extraData, (uint256));
        uint32 maxHp = ENGINE.getMonValueForBattle(ENGINE.battleKeyForWrite(), targetIndex, monIndex, MonStateIndexName.Hp);
        // Damage is negative, so we invert to compare magnitude
        damageDealt = damageDealt * -1;
        if (damageDealt >= (int32(maxHp) / HP_THRESHOLD_DENOM)) {
            return (abi.encode(numCharges + 2), false);
        }
        else {
            return (abi.encode(numCharges + 1), false);
        }
    }

    function onRoundStart(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for round start
        return (extraData, false);
    }

    function onMonSwitchIn(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for when a mon switches in
        return (extraData, false);
    }

    function onMonSwitchOut(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData, bool removeAfterRun)
    {
        // Logic for when a mon switches out
        return (extraData, false);
    }

    function onApply(uint256, bytes memory extraData, uint256, uint256)
        external
        pure
        returns (bytes memory updatedExtraData)
    {
        // Logic for when the effect is applied
        return extraData;
    }

    function onRemove(bytes memory extraData, uint256 targetIndex, uint256 monIndex) external pure {
        // Logic for when the effect is removed
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../Enums.sol";
import "../../Constants.sol";
import {IMoveSet} from "../../moves/IMoveSet.sol";
import {IEngine} from "../../IEngine.sol";
import {AttackCalculator} from "../../moves/AttackCalculator.sol";
import {ITypeCalculator} from "../../types/ITypeCalculator.sol";

contract Baselight is IMoveSet, AttackCalculator {

    uint32 constant ACCURACY = 100;
    uint32 constant public BASE_POWER = 80;
    uint32 constant public BASELIGHT_LEVEL_BOOST = 20;
    uint256 constant public MAX_BASELIGHT_LEVEL = 5;

    constructor(IEngine _ENGINE, ITypeCalculator _TYPE_CALCULATOR) AttackCalculator(_ENGINE, _TYPE_CALCULATOR) {}

    function name() public pure override returns (string memory) {
        return "Baselight";
    }

    function _baselightKey(uint256 playerIndex, uint256 monIndex) internal pure returns (bytes32) {
        return keccak256(abi.encode(playerIndex, monIndex, name()));
    }

    function getBaselightLevel(bytes32 battleKey, uint256 playerIndex, uint256 monIndex) public view returns (uint256) {
        return uint256(ENGINE.getGlobalKV(battleKey, _baselightKey(playerIndex, monIndex)));
    }

    function increaseBaselightLevel(uint256 playerIndex, uint256 monIndex) public {
        uint256 currentLevel = uint256(ENGINE.getGlobalKV(ENGINE.battleKeyForWrite(), _baselightKey(playerIndex, monIndex)));
        uint256 newLevel = currentLevel + 1;
        if (newLevel > MAX_BASELIGHT_LEVEL) {
            return;
        }
        ENGINE.setGlobalKV(_baselightKey(playerIndex, monIndex), bytes32(newLevel));
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata, uint256 rng) external {
        
        uint32 baselightLevel = uint32(getBaselightLevel(battleKey, attackerPlayerIndex, ENGINE.getActiveMonIndexForBattleState(battleKey)[attackerPlayerIndex]));
        uint32 basePower = (baselightLevel * BASELIGHT_LEVEL_BOOST) + BASE_POWER;

        calculateDamage(
            battleKey, 
            attackerPlayerIndex, 
            basePower, 
            ACCURACY, 
            DEFAULT_VOL, 
            moveType(battleKey), 
            moveClass(battleKey), 
            rng, 
            DEFAULT_CRIT_RATE);

        // Finally, increase Baselight level of the attacking mon
        increaseBaselightLevel(attackerPlayerIndex, ENGINE.getActiveMonIndexForBattleState(battleKey)[attackerPlayerIndex]);
    }

    function stamina(bytes32 battleKey, uint256 attackerPlayerIndex, uint256 monIndex) external view returns (uint32) {
        return uint32(getBaselightLevel(battleKey, attackerPlayerIndex, monIndex));
    }

    function priority(bytes32) external pure returns (uint32) {
        return DEFAULT_PRIORITY;
    }

    function moveType(bytes32) public pure returns (Type) {
        return Type.Yin;
    }

    function isValidTarget(bytes32, bytes calldata) external pure returns (bool) {
        return true;
    }

    function moveClass(bytes32) public pure returns (MoveClass) {
        return MoveClass.Special;
    }
}
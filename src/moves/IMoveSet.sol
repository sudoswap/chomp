// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

import {IEffect} from "../effects/IEffect.sol";

interface IMoveSet {

    // A move can force up to one switch by returning which player index, which mon index to switch
    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata extraData, uint256 rng)
        external
        returns (bool hasPostMoveSwitch, int32 damage);

    // A move can force up to one switch after its normal move execution has ended
    function postMoveSwitch(bytes32 battleKey, uint256 attackerPlayerIndex, bytes calldata extraData)
        external
        pure
        returns (uint256 forceSwitchPlayerIndex, uint256 monIndexToSwitchTo);

    function priority(bytes32 battleKey) external view returns (uint32);
    function stamina(bytes32 battleKey) external view returns (uint32);
    function moveType(bytes32 battleKey) external view returns (Type);
    function isValidTarget(bytes32 battleKey) external view returns (bool);
}

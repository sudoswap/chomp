// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Enums.sol";
import "../../src/Structs.sol";

import {IEngine} from "../../src/IEngine.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";

contract ForceSwitchMove is IMoveSet {

    struct Args {
        Type TYPE;
        uint256 STAMINA_COST;
        uint256 PRIORITY;
    }

    IEngine immutable ENGINE;
    Type immutable TYPE;
    uint256 immutable STAMINA_COST;
    uint256 immutable PRIORITY;

    constructor(IEngine _ENGINE, Args memory args) {
        ENGINE = _ENGINE;
        TYPE = args.TYPE;
        STAMINA_COST = args.STAMINA_COST;
        PRIORITY = args.PRIORITY;
    }

    function name() external pure returns (string memory) {
        return "Force Switch";
    }

    function move(bytes32 battleKey, uint256 attackerPlayerIndex, bytes memory data, uint256)
        external
        returns (uint256, uint256)
    {
        // Decode data as (uint256 playerIndex, uint256 monToSwitchIndex)
        (uint256 playerIndex, uint256 monToSwitchIndex) = abi.decode(data, (uint256, uint256));
        return (playerIndex, monToSwitchIndex);
    }

    function priority(bytes32) external view returns (uint256) {
        return PRIORITY;
    }

    function stamina(bytes32) external view returns (uint256) {
        return STAMINA_COST;
    }

    function moveType(bytes32) external view returns (Type) {
        return TYPE;
    }

    function isValidTarget(bytes32) external pure returns (bool) {
        return true;
    }
}

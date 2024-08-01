// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IRandomnessOracle} from "./IRandomnessOracle.sol";

contract DefaultRandomnessOracle is IRandomnessOracle {
    function getRNG(bytes32 source0, bytes32 source1) external view returns (uint256) {
        return uint256(keccak256(abi.encode(source0, source1, blockhash(block.number - 1))));
    }
}

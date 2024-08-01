// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IRandomnessOracle {
    function getRNG(bytes32 source0, bytes32 source1) external returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Enums.sol";
import "../Structs.sol";

contract DefaultMonRegistry {
    mapping(uint256 => Mon) public monRegistry;

    function addMon(Mon calldata m, uint256 id) external {
        monRegistry[id] = m;
    }
}

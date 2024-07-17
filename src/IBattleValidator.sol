// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IBattleValidator {
    function validateGameStart(Battle memory b) external;
}

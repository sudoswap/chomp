// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./Structs.sol";
import "./moves/IMoveSet.sol";

import {IEngine} from "./IEngine.sol";
import {IRuleset} from "./IRuleset.sol";

contract DefaultRuleset is IRuleset {
    IEngine immutable ENGINE;

    constructor(IEngine _ENGINE) {
        ENGINE = _ENGINE;
    }

    function getInitialGlobalEffects()
        external
        pure
        returns (IEffect[] memory emptyEffects, bytes[] memory emptyData)
    {}
}

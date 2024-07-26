// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IEffect} from "./IEffect.sol";

interface IMonEffect is IEffect {

    // Whether or not the effect should clear itself when the mon is being switched out
    // (not valid for global effects, please disregard)
    function shouldClearAfterMonSwitch() external returns (bool);

}
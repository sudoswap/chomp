// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Structs.sol";
import "../src/Enums.sol";

import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";

contract GameTest is Test {

    Engine engine;
    DefaultValidator validator;

    function setUp() public {
        engine = new Engine();
        validator = new DefaultValidator(engine);
    }

}

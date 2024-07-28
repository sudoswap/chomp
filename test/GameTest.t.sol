// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../src/Structs.sol";
import "../src/Enums.sol";

import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";

import {TypeCalculator} from "../src/types/TypeCalculator.sol";

import {CustomAttack} from "../src/moves/CustomAttack.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

contract GameTest is Test {
    Engine engine;
    DefaultValidator validator;
    TypeCalculator typeCalc;

    IMoveSet fireAttack;

    Mon testMon1;
    Mon testMon2;

    function setUp() public {
        engine = new Engine();
        validator = new DefaultValidator(engine, DefaultValidator.Args({
            MONS_PER_TEAM: 1,
            MOVES_PER_MON: 1
        }));
        typeCalc = new TypeCalculator();
        fireAttack = new CustomAttack(
            engine,
            typeCalc,
            Type.Fire,
            CustomAttack.Args({BASE_POWER: 100, ACCURACY: 100, STAMINA_COST: 2})
        );
    }

    function test_foo() public {
        
    }
}

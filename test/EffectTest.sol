// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {Engine} from "../src/Engine.sol";
import {IValidator} from "../src/IValidator.sol";
import {IAbility} from "../src/abilities/IAbility.sol";
import {IEffect} from "../src/effects/IEffect.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";
import {DefaultValidator} from "../src/DefaultValidator.sol";
import {TestTeamRegistry} from "./mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "./mocks/TestTypeCalculator.sol";
import {ITypeCalculator} from "../src/types/ITypeCalculator.sol";

// Import effects
import {FrostbiteStatus} from "../src/effects/status/FrostbiteStatus.sol";
import {SleepStatus} from "../src/effects/status/SleepStatus.sol";
import {FrightStatus} from "../src/effects/status/FrightStatus.sol";

contract EngineTest is Test {

    Engine engine;
    DefaultValidator validator;
    ITypeCalculator typeCalc;
    DefaultRandomnessOracle defaultOracle;
    TestTeamRegistry defaultRegistry;

    address constant ALICE = address(1);
    address constant BOB = address(2);
    uint256 constant TIMEOUT_DURATION = 100;

    Mon dummyMon;
    IMoveSet dummyAttack;

    function setUp() public {
        defaultOracle = new DefaultRandomnessOracle();
        engine = new Engine();
        validator = new DefaultValidator(
            engine, DefaultValidator.Args({MONS_PER_TEAM: 1, MOVES_PER_MON: 1, TIMEOUT_DURATION: TIMEOUT_DURATION})
        );
        typeCalc = new TestTypeCalculator();
        defaultRegistry = new TestTeamRegistry();
    }

    function _commitRevealExecuteForAliceAndBob(
        bytes32 battleKey,
        uint256 aliceMoveIndex,
        uint256 bobMoveIndex,
        bytes memory aliceExtraData,
        bytes memory bobExtraData
    ) internal {
        bytes32 salt = "";
        bytes32 aliceMoveHash = keccak256(abi.encodePacked(aliceMoveIndex, salt, aliceExtraData));
        bytes32 bobMoveHash = keccak256(abi.encodePacked(bobMoveIndex, salt, bobExtraData));
        vm.startPrank(ALICE);
        engine.commitMove(battleKey, aliceMoveHash);
        vm.startPrank(BOB);
        engine.commitMove(battleKey, bobMoveHash);
        vm.startPrank(ALICE);
        engine.revealMove(battleKey, aliceMoveIndex, salt, aliceExtraData);
        vm.startPrank(BOB);
        engine.revealMove(battleKey, bobMoveIndex, salt, bobExtraData);
        engine.execute(battleKey);
    }
}
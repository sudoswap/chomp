// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.0;

import "../../src/Constants.sol";
import "../../src/Structs.sol";
import {Test} from "forge-std/Test.sol";

import {Engine} from "../../src/Engine.sol";

import {MonStateIndexName, Type} from "../../src/Enums.sol";
import {FastCommitManager} from "../../src/FastCommitManager.sol";

import {FastValidator} from "../../src/FastValidator.sol";
import {IEngine} from "../../src/IEngine.sol";
import {IFastCommitManager} from "../../src/IFastCommitManager.sol";
import {IRuleset} from "../../src/IRuleset.sol";
import {IValidator} from "../../src/IValidator.sol";
import {IAbility} from "../../src/abilities/IAbility.sol";
import {IEffect} from "../../src/effects/IEffect.sol";
import {Angery} from "../../src/mons/gorillax/Angery.sol";
import {IMoveSet} from "../../src/moves/IMoveSet.sol";
import {ITeamRegistry} from "../../src/teams/ITeamRegistry.sol";

import {BattleHelper} from "../abstract/BattleHelper.sol";
import {CustomAttack} from "../mocks/CustomAttack.sol";

import {MockRandomnessOracle} from "../mocks/MockRandomnessOracle.sol";
import {TestTeamRegistry} from "../mocks/TestTeamRegistry.sol";
import {TestTypeCalculator} from "../mocks/TestTypeCalculator.sol";

import {CustomEffectAttackFactory} from "../../src/moves/CustomEffectAttackFactory.sol";
import {CustomEffectAttack} from "../../src/moves/CustomEffectAttack.sol";

contract GorillaxTest is Test, BattleHelper {

    Engine engine;
    FastCommitManager commitManager;
    TestTypeCalculator typeCalc;
    MockRandomnessOracle mockOracle;
    TestTeamRegistry defaultRegistry;
    FastValidator validator;
    Angery angery;
    CustomEffectAttackFactory attackFactory;

    function setUp() public {
        typeCalc = new TestTypeCalculator();
        mockOracle = new MockRandomnessOracle();
        defaultRegistry = new TestTeamRegistry();
        engine = new Engine();
        validator = new FastValidator(
            IEngine(address(engine)), FastValidator.Args({MONS_PER_TEAM: 2, MOVES_PER_MON: 2, TIMEOUT_DURATION: 10})
        );
        commitManager = new FastCommitManager(IEngine(address(engine)));
        engine.setCommitManager(address(commitManager));
        angery = new Angery(IEngine(address(engine)));
        attackFactory = new CustomEffectAttackFactory(
            new CustomEffectAttack(IEngine(address(engine)), ITypeCalculator(address(typeCalc)))
        );
    }

    /*
    - Assume we'll write a base functionality test for abilities that activate on switch, so dw abt those
    - Normal attack yields one charge
    - Strong attack yields 2 charges
    - Consuming 3 charges correctly heals
    - Consuming only 3 charges (and not more)
    */

    function test_angery() public {
        // Create a team with a mon that has Angery ability
        IMoveSet[] memory moves = new IMoveSet[](2);
        uint256 hpScale = 100;

        // Strong attack is exactly max hp / threshold
        moves[0] = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: angery.MAX_HP_DENOM * hpScale,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Fire,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: "Strong"
            })
        );
        moves[1] = attackFactory.createAttack(
            CustomEffectAttackFactory.ATTACK_PARAMS({
                BASE_POWER: angery.MAX_HP_DENOM * hpScale / 2,
                STAMINA_COST: 1,
                ACCURACY: 100,
                PRIORITY: 1,
                MOVE_TYPE: Type.Fire,
                EFFECT: IEffect(address(0)),
                EFFECT_ACCURACY: 0,
                MOVE_CLASS: MoveClass.Physical,
                NAME: "Weak"
            })
        );
        Mon memory angeryMon = Mon({
            stats: MonStats({
                hp: angery.MAX_HP_DENOM * angery.HP_THRESHOLD_DENOM * hpScale,
                stamina: 5,
                speed: 5,
                attack: 5,
                defense: 5,
                specialAttack: 5,
                specialDefense: 5,
                type1: Type.Fire,
                type2: Type.None
            }),
            moves: moves,
            ability: IAbility(address(angery))
        });
    }
}

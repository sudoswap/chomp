// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/Constants.sol";
import "../src/Enums.sol";
import "../src/Structs.sol";

import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {DefaultTeamRegistry} from "../src/teams/DefaultTeamRegistry.sol";

import {EffectAbility} from "./mocks/EffectAbility.sol";
import {EffectAttack} from "./mocks/EffectAttack.sol";

import {IAbility} from "../src/abilities/IAbility.sol";
import {IEffect} from "../src/effects/IEffect.sol";

import {IEngine} from "../src/IEngine.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";

contract TeamsTest is Test {
    address constant ALICE = address(1);
    address constant BOB = address(2);

    DefaultMonRegistry monRegistry;
    DefaultTeamRegistry teamRegistry;

    function setUp() public {
        monRegistry = new DefaultMonRegistry();
        teamRegistry = new DefaultTeamRegistry(
            DefaultTeamRegistry.Args({REGISTRY: monRegistry, MONS_PER_TEAM: 6, MOVES_PER_MON: 4})
        );  

        // Make Alice the mon registry owner
        monRegistry.transferOwnership(ALICE);
    }

    function test_createMon() public {
        IAbility ability = new EffectAbility(IEngine(address(0)), IEffect(address(0)));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = ability;

        IMoveSet move = new EffectAttack(IEngine(address(0)), IEffect(address(0)), EffectAttack.Args({
            TYPE: Type.Fire,
            STAMINA_COST: 1,
            PRIORITY: 1
        }));
        IMoveSet[] memory moves = new IMoveSet[](1);
        moves[0] = move;

        MonStats memory stats = MonStats({
            hp: 1,
            stamina: 1,
            speed: 1,
            attack: 1,
            defence: 1,
            specialAttack: 1,
            specialDefence: 1,
            type1: Type.Fire,
            type2: Type.None
        });

        // Create a mon in the mon registry
        vm.startPrank(ALICE);
        monRegistry.createMon(stats, moves, abilities);

        // Assert that Bob cannot create a mon
        vm.startPrank(BOB);
        vm.expectRevert();
        monRegistry.createMon(stats, moves, abilities);
    }
}

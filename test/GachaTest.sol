/**
    - First roll only works for new accounts
    - Points assigning works
    - Points can be spent for rolls
    - Rolls work
    - Battle cooldown works
    - Rolls fail when all mons are owned
 */

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import {BattleHelper} from "./abstract/BattleHelper.sol";

import "../src/gacha/GachaRegistry.sol";
import "../src/rng/DefaultRandomnessOracle.sol";
import "../src/Engine.sol";
import "../src/FastCommitManager.sol";
import "../src/teams/DefaultMonRegistry.sol";

import "./mocks/TestTeamRegistry.sol";

contract GachaTest is Test, BattleHelper {

    DefaultRandomnessOracle defaultOracle;
    Engine engine;
    FastCommitManager commitManager;
    TestTeamRegistry defaultRegistry;
    DefaultMonRegistry monRegistry;
    GachaRegistry gachaRegistry;

    function setUp() public {
        defaultOracle = new DefaultRandomnessOracle();
        engine = new Engine();
        commitManager = new FastCommitManager(engine);
        engine.setCommitManager(address(commitManager));
        defaultRegistry = new TestTeamRegistry();
        monRegistry = new DefaultMonRegistry();
        gachaRegistry = new GachaRegistry(monRegistry, engine);
    }

    function test_firstRoll() public {

        // Set up mon IDs 0 to INITIAL ROLLS
        for (uint256 i = 0; i < gachaRegistry.INITIAL_ROLLS(); i++) {
            monRegistry.createMon(i, MonStats({
                hp: 10,
                stamina: 2,
                speed: 2,
                attack: 1,
                defense: 1,
                specialAttack: 1,
                specialDefense: 1,
                type1: Type.Fire,
                type2: Type.None
            }), new IMoveSet[](0), new IAbility[](0), new bytes32[](0), new bytes32[](0));
        }

        vm.prank(ALICE);
        uint256[] memory monIds = gachaRegistry.firstRoll();
        assertEq(monIds.length, gachaRegistry.INITIAL_ROLLS());

        // Alice rolls again, it should fail
        vm.expectRevert(GachaRegistry.AlreadyFirstRolled.selector);
        vm.prank(ALICE);
        gachaRegistry.firstRoll();
    }
}

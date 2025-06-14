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

import "../src/gacha/GachaRegistry.sol";
import "../src/rng/DefaultRandomnessOracle.sol";
import "../src/Engine.sol";
import "../src/FastCommitManager.sol";
import "../src/teams/DefaultMonRegistry.sol";

import "./mocks/TestTeamRegistry.sol";

contract GachaTest is Test {

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
}

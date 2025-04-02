// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {FastCommitManager} from "../src/FastCommitManager.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {FastValidator} from "../src/FastValidator.sol";
import {Engine} from "../src/Engine.sol";
import {DefaultStaminaRegen} from "../src/effects/DefaultStaminaRegen.sol";

import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {LazyTeamRegistry} from "../src/teams/LazyTeamRegistry.sol";
import {TypeCalculator} from "../src/types/TypeCalculator.sol";

contract dCommitAndFactories is Script {
    function run()
        external
        returns (
            FastCommitManager commitManager,
            DefaultStaminaRegen defaultStaminaRegen,
            DefaultRuleset defaultRuleset,
            FastValidator validator,
            DefaultMonRegistry defaultMonRegistry,
            LazyTeamRegistry teamRegistry
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        
        // Create validator
        validator = new FastValidator(Engine(vm.envAddress("ENGINE")), FastValidator.Args({
            MONS_PER_TEAM: 6,
            MOVES_PER_MON: 4,
            TIMEOUT_DURATION: 150
        }));
        
        // Create Commit Manager and set it on the engine
        commitManager = new FastCommitManager(Engine(vm.envAddress("ENGINE")));
        Engine(vm.envAddress("ENGINE")).setCommitManager(address(commitManager));

        // Create default stamina regen/rulesets
        defaultStaminaRegen = new DefaultStaminaRegen(Engine(vm.envAddress("ENGINE")));
        defaultRuleset = new DefaultRuleset(Engine(vm.envAddress("ENGINE")), defaultStaminaRegen);

        // Create Mon/Team registry
        defaultMonRegistry = new DefaultMonRegistry();
        teamRegistry = new LazyTeamRegistry(
            LazyTeamRegistry.Args({REGISTRY: defaultMonRegistry, MONS_PER_TEAM: 6, MOVES_PER_MON: 4})
        );

        vm.stopBroadcast();
    }
}

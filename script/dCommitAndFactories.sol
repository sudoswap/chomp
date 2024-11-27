// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {CommitManager} from "../src/CommitManager.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {DefaultValidator} from "../src/DefaultValidator.sol";
import {Engine} from "../src/Engine.sol";
import {DefaultStaminaRegen} from "../src/effects/DefaultStaminaRegen.sol";

import {CustomEffectAttack} from "../src/moves/CustomEffectAttack.sol";
import {CustomEffectAttackFactory} from "../src/moves/CustomEffectAttackFactory.sol";
import {DefaultRandomnessOracle} from "../src/rng/DefaultRandomnessOracle.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {DefaultTeamRegistry} from "../src/teams/DefaultTeamRegistry.sol";
import {TypeCalculator} from "../src/types/TypeCalculator.sol";

contract dCommitAndFactories is Script {
    function run()
        external
        returns (
            CommitManager commitManager,
            DefaultStaminaRegen defaultStaminaRegen,
            DefaultRuleset defaultRuleset,
            DefaultValidator defaultValidator,
            DefaultMonRegistry defaultMonRegistry,
            DefaultTeamRegistry defaultTeamRegistry,
            CustomEffectAttack customEffectAttack,
            CustomEffectAttackFactory customEffectAttackFactory
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        // Create Commit Manager and set it on the engine
        commitManager = new CommitManager(Engine(vm.envAddress("ENGINE")));
        Engine(vm.envAddress("ENGINE")).setCommitManager(address(commitManager));

        // Create default stamina regen/rulesets
        defaultStaminaRegen = new DefaultStaminaRegen(Engine(vm.envAddress("ENGINE")));
        defaultRuleset = new DefaultRuleset(Engine(vm.envAddress("ENGINE")), defaultStaminaRegen);
        defaultValidator = new DefaultValidator(Engine(vm.envAddress("ENGINE")), DefaultValidator.Args({
            MONS_PER_TEAM: 6,
            MOVES_PER_MON: 4,
            TIMEOUT_DURATION: 150
        }));

        // Effect Attack factory
        customEffectAttack =
            new CustomEffectAttack(Engine(vm.envAddress("ENGINE")), TypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        customEffectAttackFactory = new CustomEffectAttackFactory(customEffectAttack);

        // Create Mon/Team registry
        defaultMonRegistry = new DefaultMonRegistry();
        defaultTeamRegistry = new DefaultTeamRegistry(
            DefaultTeamRegistry.Args({REGISTRY: defaultMonRegistry, MONS_PER_TEAM: 6, MOVES_PER_MON: 4})
        );

        vm.stopBroadcast();
    }
}

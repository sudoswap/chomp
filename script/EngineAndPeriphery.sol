// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Fundamental entities
import {IEffect} from "../src/effects/IEffect.sol";
import {Engine} from "../src/Engine.sol";
import {FastCommitManager} from "../src/FastCommitManager.sol";
import {DefaultRuleset} from "../src/DefaultRuleset.sol";
import {StaminaRegen} from "../src/effects/StaminaRegen.sol";
import {TypeCalculator} from "../src/types/TypeCalculator.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {FastValidator} from "../src/FastValidator.sol";

// Important effects
import {StatBoosts} from "../src/effects/StatBoosts.sol";
import {Storm} from "../src/effects/weather/Storm.sol";
import {SleepStatus} from "../src/effects/status/SleepStatus.sol";
import {PanicStatus} from "../src/effects/status/PanicStatus.sol";
import {FrostbiteStatus} from "../src/effects/status/FrostbiteStatus.sol";
import {BurnStatus} from "../src/effects/status/BurnStatus.sol";
import {ZapStatus} from "../src/effects/status/ZapStatus.sol";

contract EngineAndPeriphery is Script {
    function run()
        external
        returns (
            Engine engine,
            FastCommitManager commitManager,
            TypeCalculator typeCalc,
            DefaultMonRegistry monRegistry,
            FastValidator validator,
            StaminaRegen staminaRegen,
            DefaultRuleset ruleset,
            StatBoosts statBoosts,
            Storm storm,
            SleepStatus sleepStatus,
            PanicStatus panicStatus,
            FrostbiteStatus frostbiteStatus,
            BurnStatus burnStatus,
            ZapStatus zapStatus
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        engine = new Engine();
        commitManager = new FastCommitManager(engine);
        engine.setCommitManager(address(commitManager));
        typeCalc = new TypeCalculator();
        monRegistry = new DefaultMonRegistry();
        staminaRegen = new StaminaRegen(engine);
        IEffect[] memory effects = new IEffect[](1);
        effects[0] = staminaRegen;
        ruleset = new DefaultRuleset(engine, effects);
        validator = new FastValidator(
            engine, FastValidator.Args({MONS_PER_TEAM: 4, MOVES_PER_MON: 4, TIMEOUT_DURATION: 30})
        );
        statBoosts = new StatBoosts(engine);
        storm = new Storm(engine, statBoosts);
        sleepStatus = new SleepStatus(engine);
        panicStatus = new PanicStatus(engine);
        frostbiteStatus = new FrostbiteStatus(engine, statBoosts);
        burnStatus = new BurnStatus(engine, statBoosts);
        zapStatus = new ZapStatus(engine);
        vm.stopBroadcast();
    }
}
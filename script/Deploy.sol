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

// Mon-specific moves and abilities

// // Embursa
// import {SplitThePot} from "../src/mons/embursa/SplitThePot.sol";
// import {Q5} from "../src/mons/embursa/Q5.sol";
// import {HeatBeacon} from "../src/mons/embursa/HeatBeacon.sol";
// import {SetAblaze} from "../src/mons/embursa/SetAblaze.sol";
// import {HoneyBribe} from "../src/mons/embursa/HoneyBribe.sol";

// // Ghouliath
// import {RiseFromTheGrave} from "../src/mons/ghouliath/RiseFromTheGrave.sol";
// import {Osteoporosis} from "../src/mons/ghouliath/Osteoporosis.sol";
// import {WitherAway} from "../src/mons/ghouliath/WitherAway.sol";
// import {EternalGrudge} from "../src/mons/ghouliath/EternalGrudge.sol";
// import {InfernalFlame} from "../src/mons/ghouliath/InfernalFlame.sol";

// // Gorillax
// import {Angery} from "../src/mons/gorillax/Angery.sol";
// import {Blow} from "../src/mons/gorillax/Blow.sol";
// import {PoundGround} from "../src/mons/gorillax/PoundGround.sol";
// import {RockPull} from "../src/mons/gorillax/RockPull.sol";
// import {ThrowPebble} from "../src/mons/gorillax/ThrowPebble.sol";

// // Iblivion
// import {Baselight} from "../src/mons/iblivion/Baselight.sol";
// import {Loop} from "../src/mons/iblivion/Loop.sol";
// import {FirstResort} from "../src/mons/iblivion/FirstResort.sol";
// import {Brightback} from "../src/mons/iblivion/Brightback.sol";
// import {IntrinsicValue} from "../src/mons/iblivion/IntrinsicValue.sol";

// // Inutia
// import {Interweaving} from "../src/mons/inutia/Interweaving.sol";
// import {ShrineStrike} from "../src/mons/inutia/ShrineStrike.sol";
// import {Initialize} from "../src/mons/inutia/Initialize.sol";
// import {ChainExpansion} from "../src/mons/inutia/ChainExpansion.sol";
// import {BigBite} from "../src/mons/inutia/BigBite.sol";

contract Deploy is Script {
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

        // statBoosts = new StatBoosts(engine);
        // storm = new Storm(engine, statBoosts);
        // sleepStatus = new SleepStatus(engine);
        // panicStatus = new PanicStatus(engine);
        // frostbiteStatus = new FrostbiteStatus(engine, statBoosts);
        // burnStatus = new BurnStatus(engine, statBoosts);
        // zapStatus = new ZapStatus(engine);
        vm.stopBroadcast();
    }
}
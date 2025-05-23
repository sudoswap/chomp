// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {MonStats} from "../src/Structs.sol";
import {Type} from "../src/Enums.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {IAbility} from "../src/abilities/IAbility.sol";

import {IEngine} from "../src/IEngine.sol";
import {IEffect} from "../src/effects/IEffect.sol";
import {StatBoosts} from "../src/effects/StatBoosts.sol";
import {Storm} from "../src/effects/weather/Storm.sol";
import {HeatBeacon} from "../src/mons/embursa/HeatBeacon.sol";
import {HoneyBribe} from "../src/mons/embursa/HoneyBribe.sol";
import {Q5} from "../src/mons/embursa/Q5.sol";
import {SetAblaze} from "../src/mons/embursa/SetAblaze.sol";
import {SplitThePot} from "../src/mons/embursa/SplitThePot.sol";
import {EternalGrudge} from "../src/mons/ghouliath/EternalGrudge.sol";
import {InfernalFlame} from "../src/mons/ghouliath/InfernalFlame.sol";
import {Osteoporosis} from "../src/mons/ghouliath/Osteoporosis.sol";
import {RiseFromTheGrave} from "../src/mons/ghouliath/RiseFromTheGrave.sol";
import {WitherAway} from "../src/mons/ghouliath/WitherAway.sol";
import {Angery} from "../src/mons/gorillax/Angery.sol";
import {Blow} from "../src/mons/gorillax/Blow.sol";
import {PoundGround} from "../src/mons/gorillax/PoundGround.sol";
import {RockPull} from "../src/mons/gorillax/RockPull.sol";
import {ThrowPebble} from "../src/mons/gorillax/ThrowPebble.sol";
import {Baselight} from "../src/mons/iblivion/Baselight.sol";
import {Brightback} from "../src/mons/iblivion/Brightback.sol";
import {FirstResort} from "../src/mons/iblivion/FirstResort.sol";
import {IntrinsicValue} from "../src/mons/iblivion/IntrinsicValue.sol";
import {Loop} from "../src/mons/iblivion/Loop.sol";
import {BigBite} from "../src/mons/inutia/BigBite.sol";
import {ChainExpansion} from "../src/mons/inutia/ChainExpansion.sol";
import {Initialize} from "../src/mons/inutia/Initialize.sol";
import {Interweaving} from "../src/mons/inutia/Interweaving.sol";
import {ShrineStrike} from "../src/mons/inutia/ShrineStrike.sol";
import {ActusReus} from "../src/mons/malalien/ActusReus.sol";
import {FederalInvestigation} from "../src/mons/malalien/FederalInvestigation.sol";
import {InfiniteLove} from "../src/mons/malalien/InfiniteLove.sol";
import {NegativeThoughts} from "../src/mons/malalien/NegativeThoughts.sol";
import {TripleThink} from "../src/mons/malalien/TripleThink.sol";
import {ChillOut} from "../src/mons/pengym/ChillOut.sol";
import {Deadlift} from "../src/mons/pengym/Deadlift.sol";
import {DeepFreeze} from "../src/mons/pengym/DeepFreeze.sol";
import {PistolSquat} from "../src/mons/pengym/PistolSquat.sol";
import {PostWorkout} from "../src/mons/pengym/PostWorkout.sol";
import {CarrotHarvest} from "../src/mons/sofabbi/CarrotHarvest.sol";
import {Gachachacha} from "../src/mons/sofabbi/Gachachacha.sol";
import {GuestFeature} from "../src/mons/sofabbi/GuestFeature.sol";
import {SnackBreak} from "../src/mons/sofabbi/SnackBreak.sol";
import {UnexpectedCarrot} from "../src/mons/sofabbi/UnexpectedCarrot.sol";
import {DualShock} from "../src/mons/volthare/DualShock.sol";
import {Electrocute} from "../src/mons/volthare/Electrocute.sol";
import {MegaStarBlast} from "../src/mons/volthare/MegaStarBlast.sol";
import {Overclock} from "../src/mons/volthare/Overclock.sol";
import {RoundTrip} from "../src/mons/volthare/RoundTrip.sol";
import {ITypeCalculator} from "../src/types/ITypeCalculator.sol";

contract SetupMons is Script {
    function run() external {
        vm.startBroadcast();

        // Get the DefaultMonRegistry address
        DefaultMonRegistry registry = DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY"));

        // Deploy all mons
        deployGhouliath(registry);
        deployInutia(registry);
        deployMalalien(registry);
        deployIblivion(registry);
        deployGorillax(registry);
        deploySofabbi(registry);
        deployPengym(registry);
        deployEmbursa(registry);
        deployVolthare(registry);

        vm.stopBroadcast();
    }

    function deployGhouliath(DefaultMonRegistry registry) internal {
        // Deploy contracts for Ghouliath
        EternalGrudge eternalgrudge = new EternalGrudge(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        InfernalFlame infernalflame = new InfernalFlame(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("BURN_STATUS")));
        WitherAway witheraway = new WitherAway(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("PANIC_STATUS")));
        Osteoporosis osteoporosis = new Osteoporosis(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        RiseFromTheGrave risefromthegrave = new RiseFromTheGrave(IEngine(vm.envAddress("ENGINE")));

        // Create Ghouliath
        MonStats memory stats = MonStats({
            hp: 303,
            stamina: 5,
            speed: 181,
            attack: 157,
            defense: 202,
            specialAttack: 151,
            specialDefense: 202,
            type1: Type.Yang,
            type2: Type.Fire
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(eternalgrudge));
        moves[1] = IMoveSet(address(infernalflame));
        moves[2] = IMoveSet(address(witheraway));
        moves[3] = IMoveSet(address(osteoporosis));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(risefromthegrave));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(0, stats, moves, abilities, keys, values);
    }

    function deployInutia(DefaultMonRegistry registry) internal {
        // Deploy contracts for Inutia
        ChainExpansion chainexpansion = new ChainExpansion(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALC")));
        Initialize initialize = new Initialize(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        BigBite bigbite = new BigBite(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        ShrineStrike shrinestrike = new ShrineStrike(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        Interweaving interweaving = new Interweaving(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOST")));

        // Create Inutia
        MonStats memory stats = MonStats({
            hp: 351,
            stamina: 5,
            speed: 259,
            attack: 171,
            defense: 189,
            specialAttack: 175,
            specialDefense: 192,
            type1: Type.Wild,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(chainexpansion));
        moves[1] = IMoveSet(address(initialize));
        moves[2] = IMoveSet(address(bigbite));
        moves[3] = IMoveSet(address(shrinestrike));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(interweaving));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(1, stats, moves, abilities, keys, values);
    }

    function deployMalalien(DefaultMonRegistry registry) internal {
        // Deploy contracts for Malalien
        TripleThink triplethink = new TripleThink(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        FederalInvestigation federalinvestigation = new FederalInvestigation(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        NegativeThoughts negativethoughts = new NegativeThoughts(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FATIGUE_STATUS")));
        InfiniteLove infinitelove = new InfiniteLove(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("SLEEP_STATUS")));
        ActusReus actusreus = new ActusReus(IEngine(vm.envAddress("ENGINE")));

        // Create Malalien
        MonStats memory stats = MonStats({
            hp: 258,
            stamina: 5,
            speed: 308,
            attack: 121,
            defense: 125,
            specialAttack: 322,
            specialDefense: 151,
            type1: Type.Cyber,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(triplethink));
        moves[1] = IMoveSet(address(federalinvestigation));
        moves[2] = IMoveSet(address(negativethoughts));
        moves[3] = IMoveSet(address(infinitelove));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(actusreus));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(2, stats, moves, abilities, keys, values);
    }

    function deployIblivion(DefaultMonRegistry registry) internal {
        // Deploy contracts for Iblivion
        Baselight baselight = new Baselight(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        Loop loop = new Loop(IEngine(vm.envAddress("ENGINE")));
        FirstResort firstresort = new FirstResort(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), Baselight(vm.envAddress("BASELIGHT")));
        Brightback brightback = new Brightback(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), Baselight(vm.envAddress("BASELIGHT")));
        IntrinsicValue intrinsicvalue = new IntrinsicValue(IEngine(vm.envAddress("ENGINE")), Baselight(vm.envAddress("BASELIGHT")), StatBoosts(vm.envAddress("STAT_BOOST")));

        // Create Iblivion
        MonStats memory stats = MonStats({
            hp: 277,
            stamina: 5,
            speed: 256,
            attack: 188,
            defense: 164,
            specialAttack: 240,
            specialDefense: 168,
            type1: Type.Cosmic,
            type2: Type.Air
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(baselight));
        moves[1] = IMoveSet(address(loop));
        moves[2] = IMoveSet(address(firstresort));
        moves[3] = IMoveSet(address(brightback));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(intrinsicvalue));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(3, stats, moves, abilities, keys, values);
    }

    function deployGorillax(DefaultMonRegistry registry) internal {
        // Deploy contracts for Gorillax
        RockPull rockpull = new RockPull(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        PoundGround poundground = new PoundGround(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        Blow blow = new Blow(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        ThrowPebble throwpebble = new ThrowPebble(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        Angery angery = new Angery(IEngine(vm.envAddress("ENGINE")));

        // Create Gorillax
        MonStats memory stats = MonStats({
            hp: 407,
            stamina: 5,
            speed: 129,
            attack: 302,
            defense: 175,
            specialAttack: 112,
            specialDefense: 176,
            type1: Type.Earth,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(rockpull));
        moves[1] = IMoveSet(address(poundground));
        moves[2] = IMoveSet(address(blow));
        moves[3] = IMoveSet(address(throwpebble));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(angery));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(4, stats, moves, abilities, keys, values);
    }

    function deploySofabbi(DefaultMonRegistry registry) internal {
        // Deploy contracts for Sofabbi
        Gachachacha gachachacha = new Gachachacha(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        GuestFeature guestfeature = new GuestFeature(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        UnexpectedCarrot unexpectedcarrot = new UnexpectedCarrot(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        SnackBreak snackbreak = new SnackBreak(IEngine(vm.envAddress("ENGINE")));
        CarrotHarvest carrotharvest = new CarrotHarvest(IEngine(vm.envAddress("ENGINE")));

        // Create Sofabbi
        MonStats memory stats = MonStats({
            hp: 333,
            stamina: 5,
            speed: 205,
            attack: 180,
            defense: 201,
            specialAttack: 120,
            specialDefense: 269,
            type1: Type.Nature,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(gachachacha));
        moves[1] = IMoveSet(address(guestfeature));
        moves[2] = IMoveSet(address(unexpectedcarrot));
        moves[3] = IMoveSet(address(snackbreak));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(carrotharvest));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(5, stats, moves, abilities, keys, values);
    }

    function deployPengym(DefaultMonRegistry registry) internal {
        // Deploy contracts for Pengym
        ChillOut chillout = new ChillOut(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FROSTBITE_STATUS")));
        Deadlift deadlift = new Deadlift(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        DeepFreeze deepfreeze = new DeepFreeze(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FROSTBITE")));
        PistolSquat pistolsquat = new PistolSquat(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        PostWorkout postworkout = new PostWorkout(IEngine(vm.envAddress("ENGINE")));

        // Create Pengym
        MonStats memory stats = MonStats({
            hp: 371,
            stamina: 5,
            speed: 149,
            attack: 212,
            defense: 191,
            specialAttack: 233,
            specialDefense: 172,
            type1: Type.Ice,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(chillout));
        moves[1] = IMoveSet(address(deadlift));
        moves[2] = IMoveSet(address(deepfreeze));
        moves[3] = IMoveSet(address(pistolsquat));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(postworkout));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(6, stats, moves, abilities, keys, values);
    }

    function deployEmbursa(DefaultMonRegistry registry) internal {
        // Deploy contracts for Embursa
        HoneyBribe honeybribe = new HoneyBribe(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        SetAblaze setablaze = new SetAblaze(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("BURN_STATUS")));
        HeatBeacon heatbeacon = new HeatBeacon(IEngine(vm.envAddress("ENGINE")), IEffect(vm.envAddress("BURN_STATUS")));
        Q5 q5 = new Q5(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        SplitThePot splitthepot = new SplitThePot(IEngine(vm.envAddress("ENGINE")));

        // Create Embursa
        MonStats memory stats = MonStats({
            hp: 420,
            stamina: 5,
            speed: 111,
            attack: 141,
            defense: 230,
            specialAttack: 180,
            specialDefense: 161,
            type1: Type.Fire,
            type2: Type.None
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(honeybribe));
        moves[1] = IMoveSet(address(setablaze));
        moves[2] = IMoveSet(address(heatbeacon));
        moves[3] = IMoveSet(address(q5));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(splitthepot));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(7, stats, moves, abilities, keys, values);
    }

    function deployVolthare(DefaultMonRegistry registry) internal {
        // Deploy contracts for Volthare
        Electrocute electrocute = new Electrocute(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")));
        RoundTrip roundtrip = new RoundTrip(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        MegaStarBlast megastarblast = new MegaStarBlast(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")), IEffect(vm.envAddress("STORM")));
        DualShock dualshock = new DualShock(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")));
        Overclock overclock = new Overclock(IEngine(vm.envAddress("ENGINE")), Storm(vm.envAddress("STORM")));

        // Create Volthare
        MonStats memory stats = MonStats({
            hp: 303,
            stamina: 5,
            speed: 311,
            attack: 120,
            defense: 184,
            specialAttack: 255,
            specialDefense: 176,
            type1: Type.Lightning,
            type2: Type.Cyber
        });
        IMoveSet[] memory moves = new IMoveSet[](4);
        moves[0] = IMoveSet(address(electrocute));
        moves[1] = IMoveSet(address(roundtrip));
        moves[2] = IMoveSet(address(megastarblast));
        moves[3] = IMoveSet(address(dualshock));
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(overclock));
        bytes32[] memory keys = new bytes32[](0);
        string[] memory values = new string[](0);
        registry.createMon(8, stats, moves, abilities, keys, values);
    }

}
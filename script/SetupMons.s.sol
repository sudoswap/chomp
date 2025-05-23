// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {MonStats} from "../src/Structs.sol";
import {Type} from "../src/Enums.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {IAbility} from "../src/abilities/IAbility.sol";

import {EternalGrudge} from "../src/mons/ghouliath/EternalGrudge.sol";
import {InfernalFlame} from "../src/mons/ghouliath/InfernalFlame.sol";
import {WitherAway} from "../src/mons/ghouliath/WitherAway.sol";
import {Osteoporosis} from "../src/mons/ghouliath/Osteoporosis.sol";
import {RiseFromTheGrave} from "../src/mons/ghouliath/RiseFromTheGrave.sol";
import {ChainExpansion} from "../src/mons/inutia/ChainExpansion.sol";
import {Initialize} from "../src/mons/inutia/Initialize.sol";
import {BigBite} from "../src/mons/inutia/BigBite.sol";
import {ShrineStrike} from "../src/mons/inutia/ShrineStrike.sol";
import {Interweaving} from "../src/mons/inutia/Interweaving.sol";
import {TripleThink} from "../src/mons/malalien/TripleThink.sol";
import {FederalInvestigation} from "../src/mons/malalien/FederalInvestigation.sol";
import {NegativeThoughts} from "../src/mons/malalien/NegativeThoughts.sol";
import {InfiniteLove} from "../src/mons/malalien/InfiniteLove.sol";
import {ActusReus} from "../src/mons/malalien/ActusReus.sol";
import {Baselight} from "../src/mons/iblivion/Baselight.sol";
import {Loop} from "../src/mons/iblivion/Loop.sol";
import {FirstResort} from "../src/mons/iblivion/FirstResort.sol";
import {Brightback} from "../src/mons/iblivion/Brightback.sol";
import {IntrinsicValue} from "../src/mons/iblivion/IntrinsicValue.sol";
import {RockPull} from "../src/mons/gorillax/RockPull.sol";
import {PoundGround} from "../src/mons/gorillax/PoundGround.sol";
import {Blow} from "../src/mons/gorillax/Blow.sol";
import {ThrowPebble} from "../src/mons/gorillax/ThrowPebble.sol";
import {Angery} from "../src/mons/gorillax/Angery.sol";
import {Gachachacha} from "../src/mons/sofabbi/Gachachacha.sol";
import {GuestFeature} from "../src/mons/sofabbi/GuestFeature.sol";
import {UnexpectedCarrot} from "../src/mons/sofabbi/UnexpectedCarrot.sol";
import {SnackBreak} from "../src/mons/sofabbi/SnackBreak.sol";
import {CarrotHarvest} from "../src/mons/sofabbi/CarrotHarvest.sol";
import {ChillOut} from "../src/mons/pengym/ChillOut.sol";
import {Deadlift} from "../src/mons/pengym/Deadlift.sol";
import {DeepFreeze} from "../src/mons/pengym/DeepFreeze.sol";
import {PistolSquat} from "../src/mons/pengym/PistolSquat.sol";
import {PostWorkout} from "../src/mons/pengym/PostWorkout.sol";
import {HoneyBribe} from "../src/mons/embursa/HoneyBribe.sol";
import {SetAblaze} from "../src/mons/embursa/SetAblaze.sol";
import {HeatBeacon} from "../src/mons/embursa/HeatBeacon.sol";
import {Q5} from "../src/mons/embursa/Q5.sol";
import {SplitThePot} from "../src/mons/embursa/SplitThePot.sol";
import {Electrocute} from "../src/mons/volthare/Electrocute.sol";
import {RoundTrip} from "../src/mons/volthare/RoundTrip.sol";
import {MegaStarBlast} from "../src/mons/volthare/MegaStarBlast.sol";
import {DualShock} from "../src/mons/volthare/DualShock.sol";
import {Overclock} from "../src/mons/volthare/Overclock.sol";

contract SetupMons is Script {
    function run() external {
        vm.startBroadcast();

        // Get the DefaultMonRegistry address
        DefaultMonRegistry registry = DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY"));

        // Deploy all required contracts
        EternalGrudge eternalgrudge = new EternalGrudge(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOSTS"));
        InfernalFlame infernalflame = new InfernalFlame();
        WitherAway witheraway = new WitherAway();
        Osteoporosis osteoporosis = new Osteoporosis(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        RiseFromTheGrave risefromthegrave = new RiseFromTheGrave(vm.envAddress("ENGINE"));
        ChainExpansion chainexpansion = new ChainExpansion(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALC"));
        Initialize initialize = new Initialize(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOSTS"));
        BigBite bigbite = new BigBite(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        ShrineStrike shrinestrike = new ShrineStrike();
        Interweaving interweaving = new Interweaving(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOST"));
        TripleThink triplethink = new TripleThink(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOSTS"));
        FederalInvestigation federalinvestigation = new FederalInvestigation(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        NegativeThoughts negativethoughts = new NegativeThoughts(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("FATIGUE_STATUS"));
        InfiniteLove infinitelove = new InfiniteLove(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("SLEEP_STATUS"));
        ActusReus actusreus = new ActusReus(vm.envAddress("ENGINE"));
        Baselight baselight = new Baselight(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        Loop loop = new Loop(vm.envAddress("ENGINE"));
        FirstResort firstresort = new FirstResort(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("BASELIGHT"));
        Brightback brightback = new Brightback(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("BASELIGHT"));
        IntrinsicValue intrinsicvalue = new IntrinsicValue(vm.envAddress("ENGINE"), vm.envAddress("BASELIGHT"), vm.envAddress("STAT_BOOST"));
        RockPull rockpull = new RockPull(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        PoundGround poundground = new PoundGround(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        Blow blow = new Blow(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        ThrowPebble throwpebble = new ThrowPebble(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        Angery angery = new Angery(vm.envAddress("ENGINE"));
        Gachachacha gachachacha = new Gachachacha(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        GuestFeature guestfeature = new GuestFeature(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        UnexpectedCarrot unexpectedcarrot = new UnexpectedCarrot(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        SnackBreak snackbreak = new SnackBreak(vm.envAddress("ENGINE"));
        CarrotHarvest carrotharvest = new CarrotHarvest(vm.envAddress("ENGINE"));
        ChillOut chillout = new ChillOut();
        Deadlift deadlift = new Deadlift(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOSTS"));
        DeepFreeze deepfreeze = new DeepFreeze(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("FROSTBITE"));
        PistolSquat pistolsquat = new PistolSquat();
        PostWorkout postworkout = new PostWorkout(vm.envAddress("ENGINE"));
        HoneyBribe honeybribe = new HoneyBribe(vm.envAddress("ENGINE"), vm.envAddress("STAT_BOOSTS"));
        SetAblaze setablaze = new SetAblaze();
        HeatBeacon heatbeacon = new HeatBeacon(vm.envAddress("ENGINE"), vm.envAddress("BURN_STATUS"));
        Q5 q5 = new Q5(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"));
        SplitThePot splitthepot = new SplitThePot(vm.envAddress("ENGINE"));
        Electrocute electrocute = new Electrocute();
        RoundTrip roundtrip = new RoundTrip();
        MegaStarBlast megastarblast = new MegaStarBlast(vm.envAddress("ENGINE"), vm.envAddress("TYPE_CALCULATOR"), vm.envAddress("ZAP_STATUS"), vm.envAddress("STORM"));
        DualShock dualshock = new DualShock();
        Overclock overclock = new Overclock(vm.envAddress("ENGINE"), vm.envAddress("STORM"));

        // Create all mons in the registry
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

        vm.stopBroadcast();
    }
}
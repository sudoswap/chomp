// SPDX-License-Identifier: AGPL-3.0
// Created by mon_stats_to_sol.py
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

struct DeployData {
    string name;
    address contractAddress;
}
contract SetupMons is Script {
    function run() external returns (DeployData[] memory deployedContracts) {
        vm.startBroadcast();

        // Get the DefaultMonRegistry address
        DefaultMonRegistry registry = DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY"));

        // Deploy all mons and collect deployment data
        DeployData[][] memory allDeployData = new DeployData[][](9);

        allDeployData[0] = deployGhouliath(registry);
        allDeployData[1] = deployInutia(registry);
        allDeployData[2] = deployMalalien(registry);
        allDeployData[3] = deployIblivion(registry);
        allDeployData[4] = deployGorillax(registry);
        allDeployData[5] = deploySofabbi(registry);
        allDeployData[6] = deployPengym(registry);
        allDeployData[7] = deployEmbursa(registry);
        allDeployData[8] = deployVolthare(registry);

        // Calculate total length for flattened array
        uint256 totalLength = 0;
        for (uint256 i = 0; i < allDeployData.length; i++) {
            totalLength += allDeployData[i].length;
        }

        // Create flattened array and copy all entries
        deployedContracts = new DeployData[](totalLength);
        uint256 currentIndex = 0;

        // Copy all deployment data using nested loops
        for (uint256 i = 0; i < allDeployData.length; i++) {
            for (uint256 j = 0; j < allDeployData[i].length; j++) {
                deployedContracts[currentIndex] = allDeployData[i][j];
                currentIndex++;
            }
        }

        vm.stopBroadcast();
    }

    function deployGhouliath(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        EternalGrudge eternalgrudge = new EternalGrudge(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Eternal Grudge",
            contractAddress: address(eternalgrudge)
        });
        contractIndex++;

        InfernalFlame infernalflame = new InfernalFlame(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("BURN_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Infernal Flame",
            contractAddress: address(infernalflame)
        });
        contractIndex++;

        WitherAway witheraway = new WitherAway(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("PANIC_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Wither Away",
            contractAddress: address(witheraway)
        });
        contractIndex++;

        Osteoporosis osteoporosis = new Osteoporosis(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Osteoporosis",
            contractAddress: address(osteoporosis)
        });
        contractIndex++;

        RiseFromTheGrave risefromthegrave = new RiseFromTheGrave(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Rise From The Grave",
            contractAddress: address(risefromthegrave)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(0));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(48255219590785108371987631190908935610337927939868134998016));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(2892280330033744102432785750558213072620761253007893988233969664));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(828405385377681311210070770240235358134040002018573781295712698368));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(1255413818446673262097414784854875682986240481068487207377281482752));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(51775430304604153034055402234222690418528944407452180206686568448));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(4825421080176981678874725096418838744594202757163913668907237376));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(31593686658396204147939200950977445511458574055774509517550649344));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(80675948588196537805944960798041125777662951426919741234794725376));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(18612621507090220947202109469806573301883264901802934890494416650240));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(23153538101844932917518533148753000265009346629554614210650368376832));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(323510921648826474582825209421745328137126377011366960980584085585920));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(346672953062115569266905787866038041094893893628154788043431492124672));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(8085309652670717874987722835909996993194237716229828687842770944000));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(224667829169011211549097168817371447327201689587476139728691003392));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(0));
        registry.createMon(0, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployInutia(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        ChainExpansion chainexpansion = new ChainExpansion(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALC")));
        deployedContracts[contractIndex] = DeployData({
            name: "Chain Expansion",
            contractAddress: address(chainexpansion)
        });
        contractIndex++;

        Initialize initialize = new Initialize(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Initialize",
            contractAddress: address(initialize)
        });
        contractIndex++;

        BigBite bigbite = new BigBite(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Big Bite",
            contractAddress: address(bigbite)
        });
        contractIndex++;

        ShrineStrike shrinestrike = new ShrineStrike(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Shrine Strike",
            contractAddress: address(shrinestrike)
        });
        contractIndex++;

        Interweaving interweaving = new Interweaving(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOST")));
        deployedContracts[contractIndex] = DeployData({
            name: "Interweaving",
            contractAddress: address(interweaving)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(61755780926568637559237858671300217521743991821674967487710711470887002474632));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(61755729594830182601384295261995246286758773669688979806557023744507471497352));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(61755744140514542992952428386180154693308505715273707801601062183658315917448));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(61755730337127381760437408505794772656115321410458455501981619387475088803976));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(61754956397150596629557344360901057560505777869456822602414977325896978434168));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(61742809460749564793162852055798284755705024100109545895031400626635219806344));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(61742825509322787386692722894970891242424830001713348648720033955599212696200));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(61754971208272770778150765892754552905034578703055369677963911368812355097896));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(61755723444387426264588618137097103086292511094869505712167002314481419506216));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(61755777333706410002895348159085356575407472326984518063329110867065696495752));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(61755777251029241936863890018094461725048729884228724664949566747483418167432));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(61755777245645151024916381034232333846790433770502647623665382047216234956936));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(61755777704851584412843756848183621427624242989637591837497630893441286178952));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(61754860635308994203765467802083890582841756543347354728504385410716078737544));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(61755780926523002210852139880175668860941811756492474674246152273171686393992));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(61755780926565565997599885377575411282577112460682908954325782773806876100744));
        registry.createMon(1, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployMalalien(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        TripleThink triplethink = new TripleThink(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Triple Think",
            contractAddress: address(triplethink)
        });
        contractIndex++;

        FederalInvestigation federalinvestigation = new FederalInvestigation(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Federal Investigation",
            contractAddress: address(federalinvestigation)
        });
        contractIndex++;

        NegativeThoughts negativethoughts = new NegativeThoughts(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FATIGUE_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Negative Thoughts",
            contractAddress: address(negativethoughts)
        });
        contractIndex++;

        InfiniteLove infinitelove = new InfiniteLove(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("SLEEP_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Infinite Love",
            contractAddress: address(infinitelove)
        });
        contractIndex++;

        ActusReus actusreus = new ActusReus(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Actus Reus",
            contractAddress: address(actusreus)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(0));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(944472395854003568640));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(5148504888604777434799852553259637860223020357815628550111232));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(1318212288097215847461740160516027340023851920011324561941331968));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(1369861065807708069415169137010895627238191228805001924269047808));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(21589962430941291040927227836089617178061596970057671620501176320));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(21599698560659608958717197309407617519122213844987668482867855360));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(939628983657362645744949943769248562137539876626470445292453888));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(886380352114647828731064701213060757496644124046724484971888640));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(168192845347951841203010442673063552020686152260195739347451904));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(2665374564593927188529330675812883209192680784299473308229828608));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(889707993385610361741648971191365101750235351786764004914888704));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(4178027459669206743889885211442994818008204159506555120648192));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(4057542468684387953609644673375059116383201037649500061040640));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(3430635322809133602987845504896519236593810136443676019130368));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(0));
        registry.createMon(2, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployIblivion(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        Baselight baselight = new Baselight(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Baselight",
            contractAddress: address(baselight)
        });
        contractIndex++;

        Loop loop = new Loop(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Loop",
            contractAddress: address(loop)
        });
        contractIndex++;

        FirstResort firstresort = new FirstResort(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), Baselight(vm.envAddress("BASELIGHT")));
        deployedContracts[contractIndex] = DeployData({
            name: "First Resort",
            contractAddress: address(firstresort)
        });
        contractIndex++;

        Brightback brightback = new Brightback(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), Baselight(vm.envAddress("BASELIGHT")));
        deployedContracts[contractIndex] = DeployData({
            name: "Brightback",
            contractAddress: address(brightback)
        });
        contractIndex++;

        IntrinsicValue intrinsicvalue = new IntrinsicValue(IEngine(vm.envAddress("ENGINE")), Baselight(vm.envAddress("BASELIGHT")), StatBoosts(vm.envAddress("STAT_BOOST")));
        deployedContracts[contractIndex] = DeployData({
            name: "Intrinsic Value",
            contractAddress: address(intrinsicvalue)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(77194726158210796949047323339125271902179989777093708956663117634932237314730));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(77194726158208712636578866721608344321370119211190093851703441042351233608362));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(77194726157670627712533133974430190288657791656588637424303500311765260610218));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(77194726149666481969108529181447143178809590229714409783480088724336412371626));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(77194726149560941705070667933584742841316042482916136545939756739670577949354));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(77194726141136138348818689505239140878512884974656845424734074411655210117802));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(77043955335289336262700777274803597681365712406484001289695411768034528504490));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(74899349757745422198640775726605676914799628652866098415945953322192886300842));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(76893184447889773656559226640914688051061236862970380700877615515653582094506));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(77194726157114671506986840504249320996426434902409146676689653363533757612202));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(77194726157101510703233793857955668931735784444821913887953697656408910768810));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(77194726140455634596850876536568672964565321767598155182949067708556127152810));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(77194726141923013278782071347720043970031434498756197122311204771051399195306));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(77194726158206873342777158143557151332560459606128143792847721482456188758698));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(77194726158206426077307025247320660411959904974092914518337218867131704847018));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(77194726158210796949046305666305165647859986187270992357446142519660428044970));
        registry.createMon(3, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployGorillax(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        RockPull rockpull = new RockPull(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Rock Pull",
            contractAddress: address(rockpull)
        });
        contractIndex++;

        PoundGround poundground = new PoundGround(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Pound Ground",
            contractAddress: address(poundground)
        });
        contractIndex++;

        Blow blow = new Blow(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Blow",
            contractAddress: address(blow)
        });
        contractIndex++;

        ThrowPebble throwpebble = new ThrowPebble(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Throw Pebble",
            contractAddress: address(throwpebble)
        });
        contractIndex++;

        Angery angery = new Angery(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Angery",
            contractAddress: address(angery)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(69475253542389717254142591005212744711961990799384326863321400339856394656153));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(69475253541378796447410743104158092993202765487718553800118314022365656881561));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(69475253528992245806166660694757369683265506530988634755332209424737133762969));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(69475253289525826922942325252936615727053856320152613266732988726010304895385));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(69474216359599066479463734179441914335537058614732215268578252544564539267481));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(69474231453292306448195517567151874490027520250687761778526300047413457033625));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(69475188728880599625393297819331868702947213905443301646448020191959240513945));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(69475249630966578094957658540217178826204529399647658366353150323346774792601));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(69475253528797410762689723489322365544964110389201487052500478728321766103449));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(69475253526326082379190162783955748367588048641419582920793214982164053006745));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(69475253526761371357230832608445907554939081703290159492634824848440124705177));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(69475253526550748474988389470770066926076882535489172416367315584217099835801));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(69475253526221592725978756148364577212040676564965030743629293603626410875289));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(69475253292265998096282774868653289963876162671312405178231910266516736612761));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(69475253527091347967673112741173245172597405684230293795646906850871623653785));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(69475253542389717193882417937287033283565424113966585712629087244312964077977));
        registry.createMon(4, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deploySofabbi(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        Gachachacha gachachacha = new Gachachacha(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Gachachacha",
            contractAddress: address(gachachacha)
        });
        contractIndex++;

        GuestFeature guestfeature = new GuestFeature(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Guest Feature",
            contractAddress: address(guestfeature)
        });
        contractIndex++;

        UnexpectedCarrot unexpectedcarrot = new UnexpectedCarrot(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Unexpected Carrot",
            contractAddress: address(unexpectedcarrot)
        });
        contractIndex++;

        SnackBreak snackbreak = new SnackBreak(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Snack Break",
            contractAddress: address(snackbreak)
        });
        contractIndex++;

        CarrotHarvest carrotharvest = new CarrotHarvest(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Carrot Harvest",
            contractAddress: address(carrotharvest)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(84914198774031876643952055673037799092397985985620344097035100702919185644475));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(84900181582425883867648114453824292453454231845406820976468918239694678705083));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(84689926986609141025586835920595216898068766112145868903351157182069118649275));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(84894108250532792352104666845943000617747348498250090864718768890933668023227));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(84914120295424457643202921222025617175024789719805669028034870125656723405755));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(84901827409719743652188193937849203359455585916701305372178864180371996261307));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(84712502582796911641884946443679948186400702834206796257320446639327932038075));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(84893839065993953226773856721321818053184988156067769051976816209650639420347));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(84893473147589101318338302088045332212414153451322032816695833240084835711931));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(84899166125247176562216964660968858045862498493044188850913604458833243782075));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(84893803183946457910700429943314927173004270002546995857445891250602406296507));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(84914118253043947853856516841859934828968932418714362497525185169781962816443));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(84914117799944394967878625181031598996481620148628829068385782014255138847675));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(84914198773196387878735623444161314090680332385645345998253594443645770775483));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(84914198772880461341331871226574185479561586253387630353741077752025133595579));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(84914198774031876643664355451205150272310356250344494846801069204672096222139));
        registry.createMon(5, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployPengym(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        ChillOut chillout = new ChillOut(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FROSTBITE_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Chill Out",
            contractAddress: address(chillout)
        });
        contractIndex++;

        Deadlift deadlift = new Deadlift(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Deadlift",
            contractAddress: address(deadlift)
        });
        contractIndex++;

        DeepFreeze deepfreeze = new DeepFreeze(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("FROSTBITE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Deep Freeze",
            contractAddress: address(deepfreeze)
        });
        contractIndex++;

        PistolSquat pistolsquat = new PistolSquat(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Pistol Squat",
            contractAddress: address(pistolsquat)
        });
        contractIndex++;

        PostWorkout postworkout = new PostWorkout(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Post-Workout",
            contractAddress: address(postworkout)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(84914198774031876643952055673037799092397988754803080295592383403684196498363));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(84914198774031876592055626677155338792950925027385010099023492138083104308155));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(84914198774031657671861094545476897147340668018542940852665207695230180768699));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(84914198773977602387250391256855578283451157538089378402605332931883243912123));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(84914198773959630423531014677989989401403503857723846112842320675599575399355));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(84914198772984046811258012750146377613883500036125833194197743060652567673787));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(84912947706066389257497711486946053729283542588822161975985447481951915543483));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(84912947522050551669617358754810016726403141939875256353717313790768894643131));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(84914147246384613733215438022557330154455584317715335343780878924942970436539));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(84913381619793068940035419486838516081700917432212162543415290932851870776251));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(84914150921923679396810925705058623672256869873607921934201535106653276060603));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(84914195594555307765981035416788021596207281937883200541223883407072081722299));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(84914198758192907977183322390276240480437939856204173170924101162229659581371));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(84914198773968771544178831930476619954496746505236361125513755822617129630651));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(84914198774031875680626176577593854034886647225243236322736623573037018233787));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(84914198774031876643951136400199931053109661982672780415313128848147556842427));
        registry.createMon(6, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployEmbursa(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        HoneyBribe honeybribe = new HoneyBribe(IEngine(vm.envAddress("ENGINE")), StatBoosts(vm.envAddress("STAT_BOOSTS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Honey Bribe",
            contractAddress: address(honeybribe)
        });
        contractIndex++;

        SetAblaze setablaze = new SetAblaze(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("BURN_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Set Ablaze",
            contractAddress: address(setablaze)
        });
        contractIndex++;

        HeatBeacon heatbeacon = new HeatBeacon(IEngine(vm.envAddress("ENGINE")), IEffect(vm.envAddress("BURN_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Heat Beacon",
            contractAddress: address(heatbeacon)
        });
        contractIndex++;

        Q5 q5 = new Q5(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Q5",
            contractAddress: address(q5)
        });
        contractIndex++;

        SplitThePot splitthepot = new SplitThePot(IEngine(vm.envAddress("ENGINE")));
        deployedContracts[contractIndex] = DeployData({
            name: "Split The Pot",
            contractAddress: address(splitthepot)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(100353144005674036033761520340862853472833986709548382786158659270644107959773));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(100353143776514134229652133254684120369688643919058406844705920891599183535581));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(100353085111664866366533274379309085897791182747922131266318529816758423248349));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(100352437266621322730013193445170875824882209351148173698709690200841583549917));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(100352202553549476589669751265267947460547574295216780808275366457183634316765));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(100353085168238165521398724266068148433873051204240476426341209011916610854365));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(100353143775582420784917816327191119867041780054686094603143857552546084543965));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(100353140381484912115745633521407629814487134984401973056049292782026996178397));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(100353143982758093371416801087756575325903732475329745254275935949110072171997));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(100353143982758077093862164227362228205550400353634268655617637699030162988509));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(100353143982546551862942986751519103858791417909648464856037906369551852756445));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(100353143639017472375665720803497967118002199645403422813004924239990537182685));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(100353138189937742393722168688668992177429140164303763102604636402264976514525));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(100353051001040332662126936996524727743858669059050272778407745877702037331421));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(100351614636170027724104945374573898265917285233840959677240757097894069001693));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(100351612738218251293328639581536235320099332707337975251204665840494308089309));
        registry.createMon(7, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

    function deployVolthare(DefaultMonRegistry registry) internal returns (DeployData[] memory) {
        DeployData[] memory deployedContracts = new DeployData[](5);
        uint256 contractIndex = 0;

        Electrocute electrocute = new Electrocute(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Electrocute",
            contractAddress: address(electrocute)
        });
        contractIndex++;

        RoundTrip roundtrip = new RoundTrip(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")));
        deployedContracts[contractIndex] = DeployData({
            name: "Round Trip",
            contractAddress: address(roundtrip)
        });
        contractIndex++;

        MegaStarBlast megastarblast = new MegaStarBlast(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")), IEffect(vm.envAddress("STORM")));
        deployedContracts[contractIndex] = DeployData({
            name: "Mega Star Blast",
            contractAddress: address(megastarblast)
        });
        contractIndex++;

        DualShock dualshock = new DualShock(IEngine(vm.envAddress("ENGINE")), ITypeCalculator(vm.envAddress("TYPE_CALCULATOR")), IEffect(vm.envAddress("ZAP_STATUS")));
        deployedContracts[contractIndex] = DeployData({
            name: "Dual Shock",
            contractAddress: address(dualshock)
        });
        contractIndex++;

        Overclock overclock = new Overclock(IEngine(vm.envAddress("ENGINE")), Storm(vm.envAddress("STORM")));
        deployedContracts[contractIndex] = DeployData({
            name: "Overclock",
            contractAddress: address(overclock)
        });
        contractIndex++;

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
        bytes32[] memory keys = new bytes32[](16);
        bytes32[] memory values = new bytes32[](16);
        keys[0] = bytes32("0");
        values[0] = bytes32(uint256(657655645879928420248322048));
        keys[1] = bytes32("1");
        values[1] = bytes32(uint256(257521463280727633633630578653495681467817068650501681341131653120));
        keys[2] = bytes32("2");
        values[2] = bytes32(uint256(259686029349524776810769192726862615090355167941586762978285322240));
        keys[3] = bytes32("3");
        values[3] = bytes32(uint256(239945097556726610137150281444742383305145940675064312521771974656));
        keys[4] = bytes32("4");
        values[4] = bytes32(uint256(986982595461238524764114907497099792545169611907603509349974016));
        keys[5] = bytes32("5");
        values[5] = bytes32(uint256(22375447183698067155793713593932165040114498552704087023172583424));
        keys[6] = bytes32("6");
        values[6] = bytes32(uint256(17668470978694638648127740067291482659524194617531245106524544478912446464));
        keys[7] = bytes32("7");
        values[7] = bytes32(uint256(73606047655616303425079044080572619708065835275009198183630917813141504));
        keys[8] = bytes32("8");
        values[8] = bytes32(uint256(4589341094142710556685588758806763644595894174602775962796932726784000));
        keys[9] = bytes32("9");
        values[9] = bytes32(uint256(358061791596469657521819587148574359844974124416015972507674738688));
        keys[10] = bytes32("10");
        values[10] = bytes32(uint256(134190903397428668392089643453912796228188958621629972266295033856));
        keys[11] = bytes32("11");
        values[11] = bytes32(uint256(147437208335775353026600486328835141069766451520388334426729283584));
        keys[12] = bytes32("12");
        values[12] = bytes32(uint256(7903362371142111071484088416485748829322624413066021747277496320));
        keys[13] = bytes32("13");
        values[13] = bytes32(uint256(8336901706182899240835731798465164748085113452038548948325105664));
        keys[14] = bytes32("14");
        values[14] = bytes32(uint256(247380278154454765121425990867254795228280736541990792750705016832));
        keys[15] = bytes32("15");
        values[15] = bytes32(uint256(52309131242299785470478637174288263418392557781369487360));
        registry.createMon(8, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

}
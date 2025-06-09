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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(0));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(1316416984696955268279297021427812262655140743943051853527252992));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(1434493747685580111045532606320136845277311015627862964910868492451840));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(369932848568410621789866233108200926097096809252375831829698976050839552));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(38529637531276119803370051637638247382535817219857705257831390269931520));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(143517883498403635338336791878066216019781754801216627529096565358592));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(891328359668769417120504153477751291112084644760348123316879360));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(942880625898817150822776730703922260796816998269994353406509056));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(942750377112350649015001552430122308646326489354230218866294784));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(892928113197691807164981879635965022775540921685030282498932736));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(3186343883358603970361389328878640874959710425843878393332891648));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(51775135354112126630860035232909577191550219182434902187769331712));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(304903936234468122930308475197227496480906798738561194113630208));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(4705905087723616359691191539446523437397843056353431930340900864));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(49320303991686901128546682374778400456612865804577921826816));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(0));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(77534885628756607217741220092772573786172552056529189536988533714504413937664));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089226877936065130171846411512460713799090268742047050322032599463100416));
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
        bytes32[] memory keys = new bytes32[](17);
        bytes32[] memory values = new bytes32[](17);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(61755780926568637559237858671300217521743991821674967487710173449061206100104));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(61755780926568637556444200489640659139275637069205859888386256305453229705352));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(61754882850305234718817755961029381887821100099127176024055893017252569581704));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(61754867981002977147728883444717990625426121538816096870884204136750857619592));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(61754868023121338411415474835196991169951106251360614366411436150247387596936));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(61754860720669126598776640324718196986475747683868945790552502069635393816712));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(61744791045802427970090328687707358274162513515707092274540336665527627319432));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(58866604079136681198554183385549193710772364725064661440476499060195009792136));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(58958701011033638123278360132472901032883106329264471557562358536760902912136));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(61580524464604873583334779136466960816259265650466407870802376056237506893960));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(61744496110633239446704326279117070912737079491987906259376158919799824652424));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(61303425286823437057648623515753621038436058212707824337657589100125822748808));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(61755097131330913636673018557515518903040490856809947486419981740136665221256));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(61744807149877239727070403091639171225770676569552004639881229811246729562248));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(61755780926568637556369024235435415487980209112430770513901955646335082858632));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(61755780926568637559237858671300217521743991821674967487710711470887002474632));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(115792089237316113469577266424075652262411534080840135588393552808949523152896));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(0));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(213421459003147145970416840389060658159436034236937507176448));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(4057570245166066147845202418414926215576298518973342348738560));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(9857578342199517515838480667030834283597062813440069685215232));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(1006914071745270426945829548600572241397488634845667872131252224));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(2660553754938910626170223797551654941344820915260374923322851328));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(2687871699667940442054943269820199646303310494515154546562433024));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(14077841886805698011098642361039337745145375153396223842367569920));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(3707129792106437522324931612710483334997945360162551257534853808128));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(3709185969774207772618059802228287598736019493628866171991060643840));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(3742069741022245262406021567242374378227162495314538199444671692800));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(238324124303990287782913777162777243265147231192592420035664805888));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(238298198650980371407719966924351721903073771144391291135158386688));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(14919235042489210165205740551443852231196987591155423801017106432));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(5142196837643038110889931948781233447081662000139746085437440));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(0));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(105124666505249111687505096639801943365749745048223202540970973911124667334656));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792088957668866548921972667108976412082856408218288934526812156304583294976));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(77194726158210796949047323339125271902179989777093696514801555933173771840170));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(77194726158210549480588447591515773366234239615122160066693111613702535817898));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(77194726158141054772911655162405022939539327220794552295446015283322356935338));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(77194726157101558797947610894388774973590235935592786406183485376347354344106));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(77194726140357675765879304597943682593143153891278082300997621379773477071530));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(77194654894053113829490288614689618665056977316593797280822050308768903375530));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(76893787931905983897988309095521063427538601026801992479479690350239586888362));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(76894126577534188801321959807507075906393315898119903024623460581203043680426));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(76893187279511811834282867975071666731808067992212230237639321695927406197082));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(77194656008361611398932458457032985461608846601537407076472886950105946871210));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(77194726157136630964413768095481313505101009698637832206664453466737305365162));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(77194726157137049571773537300988365749175238360275288889781735718850673683114));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(77194726157137050375661696968217832309571807033800623878561546411899466984106));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(77194726158143687788209093347659030865174345536490693518834997479740348738218));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(77194726158206602626495238198146966824773104882109235192785654170786739169962));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(77194726158210788378711119218167570384400046423122894872663747887445343644330));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(113520689840229009551015606687688448709144355859207619324267609928769648721920));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089237315784047431654707177369110974345328014318355491175612947292487680));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(69475253542389717254142591005212744711961990799384326817987373857210564712857));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(69475253542328806127674049065418094833238310081241906950493341378924192045465));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(69474252098998303029876290856188348161922082299713441391887748766919338596761));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(69474201254326983547849944930437562356658532733978326653560067894151436933529));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(69474230183929055909958080146133331113263358946772324997929223871194214275481));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(69458658983466500828235514006397188678829001850105243016940686887018212989337));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(69474215519943202530568103371110328129939016533287880646147065726532725610905));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(69475249890538569866668551761784594305560659673117410622616348193315544996249));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(69475253528130487311457505488340951397330426481148416297940245687851424520601));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(69475253542327769183212910558044820209499154246757573374630245245580026157465));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(69475253542327905940369803144115527765242426407158394783259257160772394981785));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(69475253542327849409496808701482142823647438226666315363268021749774795446681));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(69475253542389470449461129042123932490836568224953380528637599404818574186905));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(69475253542389705456539211947840833902039172762207837930180679046164968479129));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(69475253542389717207299713257780464891493497869130763946617409863611928123801));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(69475253542389717254141675099674649083073987568543893121701528267694385240473));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(115792088152242840581173346070641227065609302968365721066482650245147463254016));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792082335569848633007197573932045576244532214531591869071028845388905840640));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(84914198774031876643952055673037799092397988754802853340144801083217422302139));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(84914198773957033535638501656055187207038513718170143841286212794214262750139));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(84914198774028613056210856486477354044061130763178258831396439916942253079483));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(84914198754661435796382103786483128355314687444331001813978705229089835039675));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(84914198560086511855143092238287512343912923440107031188972277520967756659643));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(84914198759397609288491860559160784783853308233054089134436552946557204499387));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(84914198774038576979690424072738883298477586211627172255636272413645714176955));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(84914195026524439922687530144313941357245079663997766612234460636325869521851));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(84914193815198909992522855430830476512574154524408944129779840699706629098427));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(84914198760664235512879383859452310695254594265036266656292195731436000089275));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(84914198548354656417506932938921353448787899714741638959835157161814963997627));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(84914193868444667507983291519954872478440396139561214060683358463705408584635));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(84894108106634061620733306736896777406083932615301358641168862346079910562747));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(84689876345041559145606691032932547060753429509517431574745105289970751161275));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(84689926986559330767044879098466032073955488918570441548097702970938025065403));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(84913256469975966394789952470747021936087641449288267232447263207727170304955));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(111048325370512565932641453769904247915815322289479083067273671026627911352320));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089237316179036167067778295896547124886179782377032866903544443653062656));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(84914198774031876643952055673037799092397988754802894649931053700976987585467));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(84914198773034916858454814261016929065774918654927443275154668121735391067067));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(84914198762300087352069938557741742434922544322002657488287719147993418152891));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(84914198773983360934264141309151515944642742223394370145936439191167032867771));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(84914198774028470943400765316699774493390097997804311475344884106660664818619));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(84914198773977547779408196113574418797136421730136284681499343670887494433723));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(84914198754284152454597984258701654466274753167812203102564984452342521052091));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(84914120554345706014115874525097738019425421460776317469184661943973812353979));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(84894292189762074449888907665715023000942701907962564733801821911521492515771));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(84894292115567103140314732591521259148552499230212076490992181171325327424443));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(84913021162369726251970700516233524456261671655454546867625370300855476796347));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(84914198772867277727603382747611203826911451199115244561702301425591287266235));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(84914198773161365369043319823058259768086657542272124350686136673679739435963));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(84914198773977059259012080887237920542003060176747666872976587307767027186619));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(84914198774031610968563496870236976350658677782450612356913486614795120262075));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(84914198774031859720885777070546459791109703786934422483651949997432581635003));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(113327737661950993808597574019948415079866233208297454575401846024741377277952));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089237316195228539472495931428183153308602383616095402368362339182313472));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(100353144005674036033761520340862853472833986428972409062376891246636928392669));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(100353051008234913953538945795082135790069819892527288090556742861300984503773));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(100353051008208587494253880981024627179917762373381572413194047069306808557021));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(100353138053446430373068821952130688477546165236572802168367460623274796244445));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(100353138193108629675313837070524927011672951427041805704207253646888492981725));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(100353143639017882151144108581404911082171536082088362600273933801119375285725));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(100353143639018704802987620895319643471288531563577812157025326400960232021469));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(100353144004241786390885835024275250222993198815640900471421198912125568671197));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(100353143990761760643152229117229374504365876719979276816758838480221501251037));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(100352202603844244791718415829006372518189198346805442801575987021412665515485));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(100353143779162216779712952082897011578519707801235876138451100371398915120605));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(100352201744495203027022916001690608005929701992973355234127971115933088734685));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(100338302486746333448343875406821171875658843868924726957068165358177100488157));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(100352201903817372904631305479356611308247840142277798704723754276508506381789));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(100353143775666315538721873700344351742680829176328667028874379612702252064221));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(100353143789994462696556401971103968859364266516393345709116920624287070412253));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(88869030127366547075833938555732651412136217004732547747209991754447430090752));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089237316195216450830456267147456258828628991868348900423603157876080640));
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
        bytes32[] memory keys = new bytes32[](18);
        bytes32[] memory values = new bytes32[](18);
        keys[0] = bytes32("IMG_0");
        values[0] = bytes32(uint256(41264628623125318582927360));
        keys[1] = bytes32("IMG_1");
        values[1] = bytes32(uint256(235579400980535753362039854247111494878577829077085641580641353184837632));
        keys[2] = bytes32("IMG_2");
        values[2] = bytes32(uint256(287099955701013965973542662144203394380803976877506393794196035772350464));
        keys[3] = bytes32("IMG_3");
        values[3] = bytes32(uint256(140795064686580986672344247398795300868383413015112505326053837850542080));
        keys[4] = bytes32("IMG_4");
        values[4] = bytes32(uint256(139873595740526877691663489203172652115215519942770187684786641855053824));
        keys[5] = bytes32("IMG_5");
        values[5] = bytes32(uint256(132542287960991595121200860284113183683287403377029426480780847439937536));
        keys[6] = bytes32("IMG_6");
        values[6] = bytes32(uint256(15643959260433356109693104159099655391224561821195012336918743197155328));
        keys[7] = bytes32("IMG_7");
        values[7] = bytes32(uint256(86608772852224915409599474405489198307080120717861331339024919429120));
        keys[8] = bytes32("IMG_8");
        values[8] = bytes32(uint256(65882315551763010056937778708733481764700074961759210636159483904));
        keys[9] = bytes32("IMG_9");
        values[9] = bytes32(uint256(286519428720579576690438257128529720845900422605046998441274202169344));
        keys[10] = bytes32("IMG_10");
        values[10] = bytes32(uint256(1104279415544997263534028967111653890134430476353127421055044465788452864));
        keys[11] = bytes32("IMG_11");
        values[11] = bytes32(uint256(3855817608293889215636675680764224023528684750604041554231296));
        keys[12] = bytes32("IMG_12");
        values[12] = bytes32(uint256(58290426833952726214435861440718923615399206678039355547713536));
        keys[13] = bytes32("IMG_13");
        values[13] = bytes32(uint256(63412541869904679985426145297626493135894307764322869350236160));
        keys[14] = bytes32("IMG_14");
        values[14] = bytes32(uint256(63392450757582956878375013720703863385601189118268482047180800));
        keys[15] = bytes32("IMG_15");
        values[15] = bytes32(uint256(54635893505600726259134722327102333034752559751307783703625728));
        keys[16] = bytes32("PAL_0");
        values[16] = bytes32(uint256(109862025427936745852694612445492921947549015473557656942137005592234850058240));
        keys[17] = bytes32("PAL_1");
        values[17] = bytes32(uint256(115792089101929839713132776081324585904590135842428496590656350381111299276800));
        registry.createMon(8, stats, moves, abilities, keys, values);

        return deployedContracts;
    }

}
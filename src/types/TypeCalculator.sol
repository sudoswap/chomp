// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "../Enums.sol";

import {IEngine} from "../IEngine.sol";

contract TypeCalculator {

    uint256[16][16] public typeChart;

    constructor() {
        typeChart[uint256(Type.Yin)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Yin)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Yang)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Yang)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Earth)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Earth)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Water)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Water)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Fire)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Fire)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Metal)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Metal)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Ice)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Ice)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Nature)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Nature)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Lightning)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Lightning)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Mythic)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Mythic)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Air)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Air)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Mind)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Mind)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Cyber)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Cyber)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Wild)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Wild)][uint256(Type.Cosmic)] = 1;

        typeChart[uint256(Type.Cosmic)][uint256(Type.Yin)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Yang)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Earth)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Water)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Fire)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Metal)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Ice)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Nature)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Lightning)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Mythic)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Air)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Mind)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Cyber)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Wild)] = 1;
        typeChart[uint256(Type.Cosmic)][uint256(Type.Cosmic)] = 1;
    }

    function getTypeEffectiveness(Type attackerType, Type defenderType) public view returns (uint256) {
        return typeChart[uint256(attackerType)][uint256(defenderType)];
    }
}
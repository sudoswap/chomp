// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IBattleConsumer {

    // battle vars are split into immutable and mutable parts
    // active mon and team stats are variable, the rest are not

    struct Battle {
        address p1;
        uint96 p1ActiveMon;

        address p2;
        uint96 p2ActiveMon;

        address teamRecords;
        uint48 p1TeamIndex;
        uint48 p2TeamIndex;

        address battleValidator;
        address rngOracle;
        address externalHook;

        // TODO: game state altering effects
    }
}
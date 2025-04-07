// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import "forge-std/Script.sol";

// import "../src/Enums.sol";

// import {Engine} from "../src/Engine.sol";
// import {AnguishStatus} from "../src/effects/status/AnguishStatus.sol";

// import {FrostbiteStatus} from "../src/effects/status/FrostbiteStatus.sol";
// import {SleepStatus} from "../src/effects/status/SleepStatus.sol";

// contract dEffects is Script {
//     function run()
//         external
//         returns (AnguishStatus AnguishStatus, SleepStatus sleepStatus, FrostbiteStatus frostbiteStatus)
//     {
//         uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
//         vm.startBroadcast(deployerPrivateKey);
//         AnguishStatus = new AnguishStatus(Engine(vm.envAddress("ENGINE")));
//         sleepStatus = new SleepStatus(Engine(vm.envAddress("ENGINE")));
//         frostbiteStatus = new FrostbiteStatus(Engine(vm.envAddress("ENGINE")));
//     }
// }

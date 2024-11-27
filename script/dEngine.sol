// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {Engine} from "../src/Engine.sol";

contract dEngine is Script {
    function run()
        external
        returns (
            Engine engine
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        engine = new Engine();
        vm.stopBroadcast();
    }
}
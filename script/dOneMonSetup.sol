// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {FastValidator} from "../src/FastValidator.sol";
import {LazyTeamRegistry} from "../src/teams/LazyTeamRegistry.sol";
import {DefaultMonRegistry} from "../src/teams/DefaultMonRegistry.sol";
import {IMoveSet} from "../src/moves/IMoveSet.sol";
import {IAbility} from "../src/abilities/IAbility.sol";
import {Engine} from "../src/Engine.sol";

contract dCommitAndFactories is Script {
    function run()
        external
        returns (
            FastValidator validator,
            LazyTeamRegistry registry
        )
    {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        
        // Create validator
        validator = new FastValidator(Engine(vm.envAddress("ENGINE")), FastValidator.Args({
            MONS_PER_TEAM: 1,
            MOVES_PER_MON: 4,
            TIMEOUT_DURATION: 150
        }));
        
        // Create registry
        registry = new LazyTeamRegistry(
            LazyTeamRegistry.Args({
                REGISTRY: DefaultMonRegistry(vm.envAddress("DEFAULT_MON_REGISTRY")), 
                MONS_PER_TEAM: 1,
                MOVES_PER_MON: 4
            })
        );

        // Initial mon creation values
        IAbility[] memory abilities = new IAbility[](1);
        abilities[0] = IAbility(address(0));

        IMoveSet[][] memory moves = new IMoveSet[][](1);
        moves[0] = new IMoveSet[](4);
        moves[0][0] = (IMoveSet(vm.envAddress("BLOW")));
        moves[0][1] = (IMoveSet(vm.envAddress("PHILOSOPHIZE")));
        moves[0][2] = (IMoveSet(vm.envAddress("SPOOK")));
        moves[0][3] = (IMoveSet(vm.envAddress("CHILL_OUT")));

        uint256[] memory monIndices = new uint256[](1);
        monIndices[0] = 1;

        registry.createTeam(monIndices, moves, abilities);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";
import "./IMonRegistry.sol";

import {EnumerableSetLib} from "../lib/EnumerableSetLib.sol";
import {Ownable} from "../lib/Ownable.sol";

contract DefaultMonRegistry is IMonRegistry, Ownable {
    using EnumerableSetLib for *;

    mapping(uint256 monId => MonStats) public monStats;
    mapping(uint256 monId => EnumerableSetLib.AddressSet) monMoves;
    mapping(uint256 monId => EnumerableSetLib.AddressSet) monAbilities;

    error MonAlreadyCreated();
    error MonNotyetCreated();

    constructor() {
        _initializeOwner(msg.sender);
    }

    function createMon(
        uint256 monId,
        MonStats memory _monStats,
        IMoveSet[] memory allowedMoves,
        IAbility[] memory allowedAbilities
    ) external onlyOwner {
        MonStats storage existingMon = monStats[monId];
        if (existingMon.hp != 0 && existingMon.stamina != 0) {
            revert MonAlreadyCreated();
        }
        monStats[monId] = _monStats;
        EnumerableSetLib.AddressSet storage moves = monMoves[monId];
        uint256 numMoves = allowedMoves.length;
        for (uint256 i; i < numMoves; ++i) {
            moves.add(address(allowedMoves[i]));
        }
        EnumerableSetLib.AddressSet storage abilities = monAbilities[monId];
        uint256 numAbilities = allowedAbilities.length;
        for (uint256 i; i < numAbilities; ++i) {
            abilities.add(address(allowedAbilities[i]));
        }
    }

    function modifyMon(
        uint256 monId,
        MonStats memory _monStats,
        IMoveSet[] memory movesToAdd,
        IMoveSet[] memory movesToRemove,
        IAbility[] memory abilitiesToAdd,
        IAbility[] memory abilitiesToRemove
    ) external onlyOwner {
        MonStats storage existingMon = monStats[monId];
        if (existingMon.hp == 0 && existingMon.stamina == 0) {
            revert MonNotyetCreated();
        }
        monStats[monId] = _monStats;
        EnumerableSetLib.AddressSet storage moves = monMoves[monId];
        {
            uint256 numMovesToAdd = movesToAdd.length;
            for (uint256 i; i < numMovesToAdd; ++i) {
                moves.add(address(movesToAdd[i]));
            }
        }
        {
            uint256 numMovesToRemove = movesToRemove.length;
            for (uint256 i; i < numMovesToRemove; ++i) {
                moves.remove(address(movesToAdd[i]));
            }
        }
        EnumerableSetLib.AddressSet storage abilities = monAbilities[monId];
        {
            uint256 numAbilitiesToAdd = abilitiesToAdd.length;
            for (uint256 i; i < numAbilitiesToAdd; ++i) {
                abilities.add(address(abilitiesToAdd[i]));
            }
        }
        {
            uint256 numAbilitiesToRemove = abilitiesToRemove.length;
            for (uint256 i; i < numAbilitiesToRemove; ++i) {
                abilities.remove(address(abilitiesToAdd[i]));
            }
        }
    }

    function getMonData(uint256 monId)
        external
        view
        returns (MonStats memory _monStats, address[] memory moves, address[] memory abilities)
    {
        _monStats = monStats[monId];
        moves = monMoves[monId].values();
        abilities = monAbilities[monId].values();
    }

    function getMonStats(uint256 monId) external view returns (MonStats memory) {
        return monStats[monId];
    }

    function isValidMove(uint256 monId, IMoveSet move) external view returns (bool) {
        return monMoves[monId].contains(address(move));
    }

    function isValidAbility(uint256 monId, IAbility ability) external view returns (bool) {
        return monAbilities[monId].contains(address(ability));
    }
}
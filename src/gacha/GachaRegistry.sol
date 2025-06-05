// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../teams/IMonRegistry.sol";
import "../lib/ERC721Soulbound.sol";
import {EnumerableSetLib} from "../lib/EnumerableSetLib.sol";

contract GachaRegistry is IMonRegistry, ERC721Soulbound {

    IMonRegistry public MON_REGISTRY;

    mapping(address => EnumerableSetLib.Uint256Set) private monsOwned;

    constructor(IMonRegistry _MON_REGISTRY) ERC721Soulbound("MONS", "MONS") {
        MON_REGISTRY = _MON_REGISTRY;
    }

    function tokenURI(uint256 id) public override view returns (string memory) {
        return "";
    }

    // All IMonRegistry functions are just pass throughs
    function getMonData(uint256 monId)
        external
        returns (MonStats memory mon, address[] memory moves, address[] memory abilities)
    {
        return MON_REGISTRY.getMonData(monId);
    }

    function getMonStats(uint256 monId) external view returns (MonStats memory) {
        return MON_REGISTRY.getMonStats(monId);
    }

    function getMonMetadata(uint256 monId, bytes32 key) external view returns (bytes32) {
        return MON_REGISTRY.getMonMetadata(monId, key);
    }

    function getMonCount() external view returns (uint256) {
        return MON_REGISTRY.getMonCount();
    }

    function getMonIds(uint256 start, uint256 end) external view returns (uint256[] memory) {
        return MON_REGISTRY.getMonIds(start, end);
    }

    function isValidMove(uint256 monId, IMoveSet move) external view returns (bool) {
        return MON_REGISTRY.isValidMove(monId, move);
    }

    function isValidAbility(uint256 monId, IAbility ability) external view returns (bool) {
        return MON_REGISTRY.isValidAbility(monId, ability);
    }

    function validateMon(Mon memory m, uint256 monId) external view returns (bool) {
        return MON_REGISTRY.validateMon(m, monId);
    }
}

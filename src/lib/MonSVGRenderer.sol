// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../teams/IMonRegistry.sol";

library MonSVGRenderer {

    uint256 constant HEIGHT = 32;
    uint256 constant WIDTH = 32;
    uint256 constant NUM_IMG_SLOTS = 16;

    renderMon(uint256 monId, IMonRegistry monRegistry) external view returns (string memory) {
    }
}
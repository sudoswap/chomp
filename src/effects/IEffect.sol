// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

interface IEffect {
    // Whether or not an effect can be registered
    function isValidToRegister(Battle memory battle, BattleState memory state, uint256[][] memory target)
        external
        returns (bool);

    // Whether to run the effect at the start of the round
    function shouldRunAtRoundStart() external returns (bool);

    // Whether to run the effect at the end of the round
    function shouldRunAtRoundEnd() external returns (bool);

    // Perform the effect, return updated state
    function handleEffect(
        Battle memory battle,
        BattleState memory state,
        uint256 rng,
        bytes memory extraData,
        uint256[][] memory target
    ) external pure returns (MonState[][] memory monStates, bytes memory updatedExtraData);
}

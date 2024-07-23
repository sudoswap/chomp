// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./Structs.sol";

interface IEffect {

    // Whether or not an effect can be registered
    function isValidToRegister(Battle calldata battle, BattleState calldata state, uint256[][] calldata target) external returns (bool);

    // Whether to run the effect at the start of the round
    function runAtRoundStart() external returns (bool);

    // Whether to run the effect at the end of the round
    function runAtRoundEnd() external returns (bool);

    // Perform the effect, return updated state
    function handleEffect(Battle calldata battle, BattleState calldata state, uint256 rng, bytes calldata extraData, uint256[][] calldata target)
        external
        pure
        returns (MonState[][] memory monStates, bytes calldata updatedExtraData);
}
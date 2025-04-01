// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

enum Type {
    Yin,
    Yang,
    Earth,
    Water,
    Fire,
    Metal,
    Ice,
    Nature,
    Lightning,
    Mythic,
    Air,
    Mind,
    Cyber,
    Wild,
    Cosmic,
    None
}

enum BattleProposalStatus {
    Proposed,
    Accepted,
    Started,
    Ended
}

enum EffectStep {
    OnApply,
    RoundStart,
    RoundEnd,
    OnRemove,
    OnMonSwitchIn,
    OnMonSwitchOut,
    AfterDamage,
    AfterMove
}

enum MoveClass {
    Physical,
    Special,
    Self,
    Other
}

enum MonStateIndexName {
    Hp,
    Stamina,
    Speed,
    Attack,
    Defense,
    SpecialAttack,
    SpecialDefense,
    IsKnockedOut,
    ShouldSkipTurn,
    Type1,
    Type2
}

enum EffectRunCondition {
    SkipIfGameOver, // Default to always run
    SkipIfP0KO, // Skips if P0 is KO'ed
    SkipIfP1KO, // Skips if P1 is KO'ed
    SkipIfBothKO, // Skips if both are KO'ed
}
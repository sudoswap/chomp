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
    Started
}

enum EffectStep {
    OnApply,
    RoundStart,
    RoundEnd,
    OnRemove,
    OnMonSwitchIn,
    OnMonSwitchOut,
    AfterDamage
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
    defense,
    SpecialAttack,
    specialDefense,
    IsKnockedOut,
    ShouldSkipTurn
}

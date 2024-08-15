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

enum EffectStep {
    OnApply,
    RoundStart,
    RoundEnd,
    OnRemove
}

enum AttackSupertype {
    Physical,
    Special
}

enum MonStateIndexName {
    Hp,
    Stamina,
    Speed,
    Attack,
    Defence,
    SpecialAttack,
    SpecialDefence,
    IsKnockedOut,
    ShouldSkipTurn
}

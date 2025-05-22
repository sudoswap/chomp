# System Architecture Overview

(summarized by ai, bls be careful)

CHOMP is built as a modular, extensible battle engine that allows for custom mons, moves, abilities, and effects.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CHOMP Architecture                         │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                             Core Engine                             │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   Engine    │  │CommitManager│  │  Validator  │  │   Ruleset   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Game Components                             │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │    Mons     │  │    Moves    │  │  Abilities  │  │   Effects   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Components

### Engine.sol
The central component of the system that manages the battle state and coordinates all interactions. It:
- Creates and advances battles
- Executes moves to update game state
- Manages effects and their lifecycle
- Handles mon switching
- Determines battle outcomes

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Engine Flow                               │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────┐
│  Start Battle   │
└─────────────────┘
         │
         ▼
┌─────────────────┐         ┌─────────────────┐
│ Players Commit  │ ──────► │ Players Reveal  │
└─────────────────┘         └─────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           Execute Turn                              │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Run Global  │  │Run Priority │  │Run Secondary│  │ End of Turn │ │
│  │   Effects   │──►   Player's  │──►  Player's   │──►   Effects   │ │
│  │             │  │    Move     │  │    Move     │  │             │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │  Check Game     │
                            │     Over        │
                            └─────────────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │  Next Turn or   │
                            │  End Battle     │
                            └─────────────────┘
```

### ICommitManager.sol
Manages the commit-reveal mechanism for player moves:
- Players commit a hash of their move
- After both players commit, they reveal their moves
- Ensures fair play by preventing players from changing their moves after seeing the opponent's choice

### IValidator.sol
Validates game rules and player actions:
- Ensures teams are valid at game start
- Validates that moves are legal
- Checks for game over conditions
- Handles timeout conditions
- Computes priority between players

## Game Components

### Mons
mons are the battling entities with:
- Stats (HP, stamina, speed, attack, defense, etc.)
- Abilities
- Moves
- Types

```
┌─────────────────────────────────────────────────────────────────────┐
│                             Mon                                     │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                 ┌─────────────────┼─────────────────┐
                 ▼                 ▼                 ▼
        ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
        │    Stats    │    │   Ability   │    │    Moves    │
        └─────────────┘    └─────────────┘    └─────────────┘
               │                  │                  │
               ▼                  ▼                  ▼
        ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
        │ HP, Stamina │    │ Activates   │    │ Up to 4     │
        │ Speed, Atk  │    │ on switch   │    │ different   │
        │ Def, SpAtk  │    │ or specific │    │ moves with  │
        │ SpDef, Types│    │ conditions  │    │ various     │
        │             │    │             │    │ effects     │
        └─────────────┘    └─────────────┘    └─────────────┘
```

### Moves (IMoveSet)
Actions that mons can take during battle:
- Can deal damage
- Apply effects
- Consume stamina
- Use priority values to determine execution order

```
┌─────────────────────────────────────────────────────────────────────┐
│                             Move                                    │
└─────────────────────────────────────────────────────────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    Attributes   │       │     Effects     │       │    Execution    │
└─────────────────┘       └─────────────────┘       └─────────────────┘
         │                         │                         │
         ▼                         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ - Base Power    │       │ - Status Effects│       │ - Priority      │
│ - Stamina Cost  │       │ - Stat Changes  │       │ - Accuracy      │
│ - Type          │       │ - Field Effects │       │ - Target        │
│ - Move Class    │       │ - Weather       │       │ - Damage Calc   │
└─────────────────┘       └─────────────────┘       └─────────────────┘
```

### Abilities (IAbility)
Passive effects that are tied to a specific mon:
- Activate when a mon enters battle
- Can modify stats, apply effects, or change battle conditions
- Provide unique characteristics to mons

### Effects (IEffect)
Temporary or permanent modifications to the battle state:
- Can be applied to mons or globally
- Have lifecycle hooks for different battle phases
- Can modify stats, apply status conditions, or change battle mechanics

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Effect Lifecycle                            │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                            ┌─────────────┐
                            │   onApply   │
                            └─────────────┘
                                   │
                                   ▼
         ┌───────────────────────────────────────────┐
         │                                           │
         ▼                                           ▼
┌─────────────────┐                         ┌─────────────────┐
│  onRoundStart   │                         │  onMonSwitchIn  │
└─────────────────┘                         └─────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────┐                         ┌─────────────────┐
│   onAfterMove   │                         │ onMonSwitchOut  │
└─────────────────┘                         └─────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────┐                         ┌─────────────────┐
│  onAfterDamage  │                         │    onRemove     │
└─────────────────┘                         └─────────────────┘
         │
         ▼
┌─────────────────┐
│   onRoundEnd    │
└─────────────────┘
```

## Battle Flow

The battle system follows a turn-based structure with simultaneous move selection:

1. **Battle Initialization**
   - Players select their teams
   - Battle is created with a validator, ruleset, and randomness oracle
   - Initial global effects are applied

2. **Turn Execution**
   - Players commit their moves (hash of move + salt)
   - Players reveal their moves
   - Engine determines move priority
   - Global effects are processed
   - Priority player's move is executed
   - Secondary player's move is executed
   - End-of-turn effects are processed
   - Check for game over conditions

3. **Battle Resolution**
   - Battle ends when one player has all mons KOed.
   - Winner is determined and recorded
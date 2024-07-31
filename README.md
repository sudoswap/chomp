# untitled battle game

on-chain turn-based pvp battling game, inspired by pokemon showdown x mugen

designed to be highly extensible

### Engine.sol
Main entry point for handling Battles.
Handles committing, revealing, and executing moves to advance battle state.
Stores global state / data available to all players.

General flow:
- p1 commits hash of a Move
- p2 commits hash of a Move
- p1 reveals hash
- p2 reveals hash
- anyone can execute to advance game state
- validator ensures moves are legal at each stage

### Validator
Validators do auxiliary verification outside of the game engine. They handle additional game ending conditions like timeouts and hook into the Battle's lifecycle, e.g. Battle start and Battle end.

### Mons
Mons are the player's game pieces. They can each hold a number of Moves and have their own stats. They are intended to be used to validate the end result of a Battle. 

### Moves
A Move takes in game state and returns any updates. It also has limited ability to write to a global key-value table. 
See `IMove.sol` for the current working interface.

### Effects
Moves can return Effects, which are persistent side effects that alter game state. Effects can be called on several lifecycle hooks during a Battle's execution by the Engine. See `IEffect.sol` for the current working interface.
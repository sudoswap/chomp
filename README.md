# C.H.O.M.P. (credibly hackable on-chain monster pvp)

on-chain turn-based pvp battling game, (heavily) inspired by pokemon showdown x mugen

designed to be highly extensible

general flow of the game is: 
- each turn, players simultaneously choose a move on their active mon.
- moves can alter stats, do damage, or generally mutate game state in some way.
- this continues until one player has all their mons knocked out.

(think normal pokemon style)

mechanical differences are:
- extensible engine, write your own Effects or Moves
- far greater support for state-based moves / mechanics
- stamina-based resource system instead of PP for balancing moves

See [Architecture](ARCHITECTURE.md) for a deeper dive.

## Getting Started

This repo uses [foundry](https://book.getfoundry.sh/getting-started/installation).

To get started:

`forge install`

`forge test`

### Engine.sol
Main entry point for creating/advancing Battles.
Handles executing moves to advance battle state.
Stores global state / data available to all players.

### CommitManager.sol
Main entry point for managing moves.
Allows users to commit/reveal moves for battles.
Stores commitment history.

### IMoveSet.sol
Interface for a Move, an available choice for a Mon.

### IEffect.sol
Interface for an Effect, which can mutate game state and manage its own state. Moves and Effects can attach new Effects to a game state.

## Game Flow
General flow of battle:
- p1 commits hash of a Move
- p2 commits hash of a Move
- p1 reveals hash
- p2 reveals hash
- execute to advance game state

During a player's turn, they can choose either a Move on their active Mon, or switch to a new Mon.

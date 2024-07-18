# untitled battle game

on-chain turn-based pvp battling game

### Engine.sol
Main entry point for handling battles.
General flow:
- p1 commits hash of move
- p2 commits hash of move
- p1 reveals hash
- p2 reveals hash
- anyone can execute to advance game state
- validator contract ensures moves are legal at each stag
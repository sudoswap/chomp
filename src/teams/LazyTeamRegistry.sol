// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "../Structs.sol";

import "./IMonRegistry.sol";
import "./ITeamRegistry.sol";

contract LazyTeamRegistry is ITeamRegistry {
    uint32 constant BITS_PER_MON_INDEX = 32;
    uint256 constant ONES_MASK = (2 ** BITS_PER_MON_INDEX) - 1;

    struct Args {
        IMonRegistry REGISTRY;
        uint256 MONS_PER_TEAM;
        uint256 MOVES_PER_MON;
    }

    error InvalidTeamSize();
    error InvalidNumMovesPerMon();
    error InvalidMove();
    error InvalidAbility();
    error DuplicateMonId();

    IMonRegistry immutable REGISTRY;
    uint256 immutable MONS_PER_TEAM;
    uint256 immutable MOVES_PER_MON;

    mapping(address => mapping(uint256 => Mon[])) public teams;
    mapping(address => mapping(uint256 => uint256)) public monRegistryIndicesForTeamPacked;
    mapping(address => uint256) public numTeams;

    address firstToRegister;
    uint256 constant DEFAULT_INDEX = 0;

    constructor(Args memory args) {
        REGISTRY = args.REGISTRY;
        MONS_PER_TEAM = args.MONS_PER_TEAM;
        MOVES_PER_MON = args.MOVES_PER_MON;
    }

    function createTeam(uint256[] memory monIndices, IMoveSet[][] memory moves, IAbility[] memory abilities) external {

        // Set first to register
        if (firstToRegister == address(0)) {
            firstToRegister = msg.sender;
        }

        if (monIndices.length != MONS_PER_TEAM) {
            revert InvalidTeamSize();
        }
        for (uint256 i; i < MONS_PER_TEAM; i++) {
            uint256 numMoves = moves[i].length;
            if (numMoves != MOVES_PER_MON) {
                revert InvalidNumMovesPerMon();
            }
            for (uint256 j; j < numMoves; j++) {
                if (!REGISTRY.isValidMove(monIndices[i], moves[i][j])) {
                    revert InvalidMove();
                }
            }
            if (!REGISTRY.isValidAbility(monIndices[i], abilities[i])) {
                revert InvalidAbility();
            }
        }

        // Check for duplicate mon indices
        _checkForDuplicates(monIndices);

        // Initialize team and set indices
        uint256 teamId = numTeams[msg.sender];
        for (uint256 i; i < MONS_PER_TEAM; i++) {
            teams[msg.sender][teamId].push(
                Mon({stats: REGISTRY.getMonStats(monIndices[i]), moves: moves[i], ability: abilities[i]})
            );
            _setMonRegistryIndices(teamId, uint32(monIndices[i]), i);
        }

        // Update the team index
        numTeams[msg.sender] += 1;
    }

    function updateTeam(
        uint256 teamIndex,
        uint256[] memory teamMonIndicesToOverride,
        uint256[] memory newMonIndices,
        IMoveSet[][] memory newMoves,
        IAbility[] memory newAbilities
    ) external {
        uint256 numMonsToOverride = teamMonIndicesToOverride.length;

        // Verify that the new moves and abilities are valid
        for (uint256 i; i < numMonsToOverride; i++) {
            uint256 monIndex = newMonIndices[i];
            uint256 numMoves = newMoves[i].length;
            if (numMoves != MOVES_PER_MON) {
                revert InvalidNumMovesPerMon();
            }
            for (uint256 j; j < numMoves; j++) {
                if (!REGISTRY.isValidMove(monIndex, newMoves[i][j])) {
                    revert InvalidMove();
                }
            }
            if (!REGISTRY.isValidAbility(monIndex, newAbilities[i])) {
                revert InvalidAbility();
            }
        }

        // Check for duplicate mon indices
        _checkForDuplicates(newMonIndices);

        // Update the team
        for (uint256 i; i < numMonsToOverride; i++) {
            uint256 monIndexToOverride = teamMonIndicesToOverride[i];
            teams[msg.sender][teamIndex][monIndexToOverride] =
                Mon({stats: REGISTRY.getMonStats(newMonIndices[i]), moves: newMoves[i], ability: newAbilities[i]});
            _setMonRegistryIndices(teamIndex, uint32(newMonIndices[i]), monIndexToOverride);
        }
    }

    function _checkForDuplicates(uint256[] memory monIndices) internal view {
        for (uint256 i; i < MONS_PER_TEAM - 1; i++) {
            for (uint256 j = i + 1; j < MONS_PER_TEAM; j++) {
                if (monIndices[i] == monIndices[j]) {
                    revert DuplicateMonId();
                }
            }
        }
    }

    function copyTeam(address playerToCopy, uint256 teamIndex) external {
        // Initialize team and set indices
        uint256 teamId = numTeams[msg.sender];
        for (uint256 i; i < MONS_PER_TEAM; i++) {
            teams[msg.sender][teamId].push(teams[playerToCopy][teamIndex][i]);
        }
        monRegistryIndicesForTeamPacked[msg.sender][teamIndex] =
            monRegistryIndicesForTeamPacked[playerToCopy][teamIndex];

        // Update the team index
        numTeams[msg.sender] += 1;
    }

    // Layout: | Nothing | Nothing | Mon5 | Mon4 | Mon3 | Mon2 | Mon1 | Mon 0 <-- rightmost bits
    function _setMonRegistryIndices(uint256 teamIndex, uint32 monId, uint256 position) internal {
        // Create a bitmask to clear the bits we want to modify
        uint256 clearBitmask = ~(ONES_MASK << (position * BITS_PER_MON_INDEX));

        // Get the existing packed value
        uint256 existingPackedValue = monRegistryIndicesForTeamPacked[msg.sender][teamIndex];

        // Clear the bits we want to modify
        uint256 clearedValue = existingPackedValue & clearBitmask;

        // Create the value bitmask with the new monId
        uint256 valueBitmask = uint256(monId) << (position * BITS_PER_MON_INDEX);

        // Combine the cleared value with the new value
        monRegistryIndicesForTeamPacked[msg.sender][teamIndex] = clearedValue | valueBitmask;
    }

    function _getMonRegistryIndex(address player, uint256 teamIndex, uint256 position)
        internal
        view
        returns (uint256)
    {
        return uint32(monRegistryIndicesForTeamPacked[player][teamIndex] >> (position * BITS_PER_MON_INDEX));
    }

    function getMonRegistryIndicesForTeam(address player, uint256 teamIndex) public view returns (uint256[] memory) {
        if (teamIndex == DEFAULT_INDEX && player != firstToRegister) {
            return getMonRegistryIndicesForTeam(firstToRegister, DEFAULT_INDEX);
        }
        uint256[] memory ids = new uint256[](MONS_PER_TEAM);
        for (uint256 i; i < MONS_PER_TEAM; ++i) {
            ids[i] = _getMonRegistryIndex(player, teamIndex, i);
        }
        return ids;
    }

    // Overwrite so it's the first to register's player's team
    function getTeam(address player, uint256 teamIndex) external view returns (Mon[] memory) {
        if (teamIndex == DEFAULT_INDEX) {
            return teams[firstToRegister][DEFAULT_INDEX];
        }
        return teams[player][teamIndex];
    }

    function getTeamCount(address player) external view returns (uint256) {
        uint256 teamCount = numTeams[player];
        if (teamCount == 0) {
            return 1;
        }
        return teamCount;
    }

    function getMonRegistry() external view returns (IMonRegistry) {
        return REGISTRY;
    }

    function getTeamData(address player, uint256 teamIndex) external view returns (string[] memory, uint256[] memory) {
        Mon[] storage team = teams[player][teamIndex];
        string[] memory teamDataNames = new string[](team.length * (MOVES_PER_MON + 2));
        uint256[] memory moveMetadata = new uint256[](team.length * MOVES_PER_MON * 2);
        for (uint256 i; i < team.length; i++) {
            uint256 monId = _getMonRegistryIndex(player, teamIndex, i);
            teamDataNames[i * (MOVES_PER_MON + 2)] = REGISTRY.getMonMetadata(monId, bytes32("name"));
            teamDataNames[i * (MOVES_PER_MON + 2) + 1] = (team[i].ability).name();

            bytes32 mockBattleKey = bytes32(0);

            for (uint256 j; j < MOVES_PER_MON; j++) {
                teamDataNames[i * (MOVES_PER_MON + 2) + j + 2] = (team[i].moves[j]).name();

                uint256 baseIndex = i * MOVES_PER_MON * 2 + j * 2;

                // Set priority
                moveMetadata[baseIndex] = (team[i].moves[j]).priority(mockBattleKey);

                // Set type
                moveMetadata[baseIndex + 1] = uint256((team[i].moves[j]).moveType(mockBattleKey));
            }
        }
        return (teamDataNames, moveMetadata);
    }
}

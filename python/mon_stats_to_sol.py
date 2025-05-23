#!/usr/bin/env python3
"""
author: augment
Script to generate a Foundry deployment script (SetupMons.s.sol) that:
1. Deploys all required move and ability contracts for each mon
2. Creates entries in the DefaultMonRegistry contract by calling createMon
3. Reads data from drool/mons.csv, drool/moves.csv, and drool/abilities.csv
"""

import csv
import os
import re
from typing import Dict, List


class MonData:
    """Represents a mon with its stats, moves, and abilities"""
    def __init__(self, mon_id: int, name: str, hp: int, stamina: int, speed: int,
                 attack: int, defense: int, special_attack: int, special_defense: int,
                 type1: str, type2: str):
        self.mon_id = mon_id
        self.name = name
        self.hp = hp
        self.stamina = stamina
        self.speed = speed
        self.attack = attack
        self.defense = defense
        self.special_attack = special_attack
        self.special_defense = special_defense
        self.type1 = type1
        self.type2 = type2
        self.moves: List[str] = []
        self.abilities: List[str] = []


class ContractInfo:
    """Represents information about a contract to be deployed"""
    def __init__(self, name: str, contract_path: str, dependencies: List[str]):
        self.name = name
        self.contract_path = contract_path
        self.dependencies = dependencies
        self.variable_name = self._generate_variable_name()

    def _generate_variable_name(self) -> str:
        """Generate a valid Solidity variable name from contract name"""
        # Remove spaces and convert to camelCase
        words = self.name.replace(" ", "").split()
        if not words:
            return "contract"

        # First word lowercase, rest title case
        result = words[0].lower()
        for word in words[1:]:
            result += word.capitalize()

        # Remove any non-alphanumeric characters
        result = re.sub(r'\W+', '', result)

        return result


def read_mons_csv(file_path: str) -> Dict[str, MonData]:
    """Read mons.csv and return a dictionary of mon name -> MonData"""
    mons = {}
    with open(file_path, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            mon = MonData(
                mon_id=int(row['Id']),
                name=row['Name'],
                hp=int(row['HP']),
                stamina=5,
                speed=int(row['Speed']),
                attack=int(row['Attack']),
                defense=int(row['Defense']),
                special_attack=int(row['SpecialAttack']),
                special_defense=int(row['SpecialDefense']),
                type1=row['Type1'],
                type2=row['Type2']
            )
            mons[mon.name] = mon
    return mons


def read_moves_csv(file_path: str, mons: Dict[str, MonData]) -> None:
    """Read moves.csv and populate move data for each mon"""
    with open(file_path, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            move_name = row['Name'].strip()
            mon_name = row['Mon'].strip()
            if move_name and mon_name and mon_name in mons:
                mons[mon_name].moves.append(move_name)


def read_abilities_csv(file_path: str, mons: Dict[str, MonData]) -> None:
    """Read abilities.csv and populate ability data for each mon"""
    with open(file_path, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            ability_name = row['Name'].strip()
            mon_name = row['Mon'].strip()

            if ability_name and mon_name and mon_name in mons:
                mons[mon_name].abilities.append(ability_name)


def convert_type_to_solidity(type_str: str) -> str:
    """Convert CSV type string to Solidity Type enum value"""
    if type_str == "NA" or type_str == "":
        return "Type.None"
    return "Type." + type_str


def contract_name_from_move_or_ability(name: str) -> str:
    """Convert move/ability name to contract name (remove spaces and -)"""
    name = re.sub(r'\W+', '', name.replace(" ", ""))
    return name


def get_mon_directory_name(mon_name: str) -> str:
    """Convert mon name to directory name (lowercase)"""
    return mon_name.lower()


def analyze_contract_dependencies(contract_path: str) -> List[str]:
    """Analyze a contract file to determine its constructor dependencies"""
    dependencies = []

    try:
        with open(contract_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Look for constructor parameters
        constructor_match = re.search(r'constructor\s*\([^)]*\)', content, re.MULTILINE | re.DOTALL)
        if constructor_match:
            constructor_text = constructor_match.group(0)

            # Extract parameter names that start with underscore
            param_matches = re.findall(r'(\w+)\s+(_\w+)', constructor_text)
            for param_type, param_name in param_matches:
                # Remove leading underscore for environment variable name
                env_name = param_name[1:].upper()
                dependencies.append(env_name)

    except FileNotFoundError:
        print(f"Warning: Contract file not found: {contract_path}")
    except Exception as e:
        print(f"Warning: Error analyzing contract {contract_path}: {e}")

    return dependencies


def get_contracts_for_mon(mon: MonData, base_path: str) -> Dict[str, ContractInfo]:
    """Get all contracts needed for a specific mon"""
    contracts = {}
    mon_dir = get_mon_directory_name(mon.name)

    # Collect move contracts
    for move_name in mon.moves:
        contract_name = contract_name_from_move_or_ability(move_name)
        contract_path = os.path.join(base_path, "src", "mons", mon_dir, f"{contract_name}.sol")

        if contract_name not in contracts:
            dependencies = analyze_contract_dependencies(contract_path)
            contracts[contract_name] = ContractInfo(move_name, contract_path, dependencies)

    # Collect ability contracts
    for ability_name in mon.abilities:
        contract_name = contract_name_from_move_or_ability(ability_name)
        contract_path = os.path.join(base_path, "src", "mons", mon_dir, f"{contract_name}.sol")

        if contract_name not in contracts:
            dependencies = analyze_contract_dependencies(contract_path)
            contracts[contract_name] = ContractInfo(ability_name, contract_path, dependencies)

    return contracts


def collect_all_contracts(mons: Dict[str, MonData], base_path: str) -> Dict[str, ContractInfo]:
    """Collect all unique contracts that need to be deployed"""
    contracts = {}

    for mon in mons.values():
        mon_contracts = get_contracts_for_mon(mon, base_path)
        contracts.update(mon_contracts)

    return contracts


def generate_deploy_function_for_mon(mon: MonData, base_path: str) -> List[str]:
    """Generate the deploy function for a specific mon"""
    function_name = f"deploy{mon.name.replace(' ', '')}"
    lines = []
    
    lines.append(f"    function {function_name}(DefaultMonRegistry registry) internal {{")
    
    # Get contracts for this mon
    mon_contracts = get_contracts_for_mon(mon, base_path)
    mon_dir = get_mon_directory_name(mon.name)
    
    if mon_contracts:
        lines.append(f"        // Deploy contracts for {mon.name}")
        
        # Deploy contracts
        for contract in mon_contracts.values():
            contract_name = contract_name_from_move_or_ability(contract.name)
            
            # Build constructor arguments
            constructor_args = []
            for dep in contract.dependencies:
                constructor_args.append(f"vm.envAddress(\"{dep}\")")
            
            args_str = ", ".join(constructor_args)
            lines.append(f"        {contract_name} {contract.variable_name} = new {contract_name}({args_str});")
        
        lines.append("")
    
    # Generate MonStats
    type1 = convert_type_to_solidity(mon.type1)
    type2 = convert_type_to_solidity(mon.type2)
    
    lines.append(f"        // Create {mon.name}")
    lines.extend([
        "        MonStats memory stats = MonStats({",
        f"            hp: {mon.hp},",
        f"            stamina: {mon.stamina},",
        f"            speed: {mon.speed},",
        f"            attack: {mon.attack},",
        f"            defense: {mon.defense},",
        f"            specialAttack: {mon.special_attack},",
        f"            specialDefense: {mon.special_defense},",
        f"            type1: {type1},",
        f"            type2: {type2}",
        "        });"
    ])
    
    # Generate moves array
    if mon.moves:
        lines.append(f"        IMoveSet[] memory moves = new IMoveSet[]({len(mon.moves)});")
        for i, move_name in enumerate(mon.moves):
            contract_name = contract_name_from_move_or_ability(move_name)
            if contract_name in mon_contracts:
                var_name = mon_contracts[contract_name].variable_name
                lines.append(f"        moves[{i}] = IMoveSet(address({var_name}));")
    else:
        lines.append("        IMoveSet[] memory moves = new IMoveSet[](0);")
    
    # Generate abilities array
    if mon.abilities:
        lines.append(f"        IAbility[] memory abilities = new IAbility[]({len(mon.abilities)});")
        for i, ability_name in enumerate(mon.abilities):
            contract_name = contract_name_from_move_or_ability(ability_name)
            if contract_name in mon_contracts:
                var_name = mon_contracts[contract_name].variable_name
                lines.append(f"        abilities[{i}] = IAbility(address({var_name}));")
    else:
        lines.append("        IAbility[] memory abilities = new IAbility[](0);")
    
    # Generate metadata arrays (empty for now)
    lines.extend([
        "        bytes32[] memory keys = new bytes32[](0);",
        "        string[] memory values = new string[](0);"
    ])
    
    # Generate createMon call
    lines.append(f"        registry.createMon({mon.mon_id}, stats, moves, abilities, keys, values);")
    lines.append("    }")
    lines.append("")
    
    return lines


def generate_solidity_script(mons: Dict[str, MonData], contracts: Dict[str, ContractInfo], base_path: str) -> str:
    """Generate the complete Solidity deployment script"""

    # Generate imports
    imports = [
        "// SPDX-License-Identifier: AGPL-3.0",
        "pragma solidity ^0.8.0;",
        "",
        "import {Script} from \"forge-std/Script.sol\";",
        "import {DefaultMonRegistry} from \"../src/teams/DefaultMonRegistry.sol\";",
        "import {MonStats} from \"../src/Structs.sol\";",
        "import {Type} from \"../src/Enums.sol\";",
        "import {IMoveSet} from \"../src/moves/IMoveSet.sol\";",
        "import {IAbility} from \"../src/abilities/IAbility.sol\";",
        ""
    ]

    # Add contract imports
    for contract in contracts.values():
        mon_dir = None
        for mon in mons.values():
            if contract.name in mon.moves or contract.name in mon.abilities:
                mon_dir = get_mon_directory_name(mon.name)
                break

        if mon_dir:
            contract_name = contract_name_from_move_or_ability(contract.name)
            import_path = f"../src/mons/{mon_dir}/{contract_name}.sol"
            imports.append(f"import {{{contract_name}}} from \"{import_path}\";")

    imports.append("")

    # Generate contract header and main run function
    contract_lines = [
        "contract SetupMons is Script {",
        "    function run() external {",
        "        vm.startBroadcast();",
        "",
        "        // Get the DefaultMonRegistry address",
        "        DefaultMonRegistry registry = DefaultMonRegistry(vm.envAddress(\"DEFAULT_MON_REGISTRY\"));",
        ""
    ]
    
    # Add calls to individual deploy functions
    contract_lines.append("        // Deploy all mons")
    for mon in sorted(mons.values(), key=lambda m: m.mon_id):
        function_name = f"deploy{mon.name.replace(' ', '')}"
        contract_lines.append(f"        {function_name}(registry);")
    
    contract_lines.extend([
        "",
        "        vm.stopBroadcast();",
        "    }",
        ""
    ])
    
    # Generate individual deploy functions for each mon
    deploy_functions = []
    for mon in sorted(mons.values(), key=lambda m: m.mon_id):
        deploy_functions.extend(generate_deploy_function_for_mon(mon, base_path))
    
    # Generate contract footer
    contract_footer = ["}"]

    # Combine all parts
    all_lines = imports + contract_lines + deploy_functions + contract_footer
    return "\n".join(all_lines)


def main():
    """Main function to generate the deployment script"""
    base_path = "."  # Assume script is run from repository root

    # Read CSV data
    print("Reading CSV data...")
    mons = read_mons_csv(os.path.join(base_path, "drool", "mons.csv"))
    read_moves_csv(os.path.join(base_path, "drool", "moves.csv"), mons)
    read_abilities_csv(os.path.join(base_path, "drool", "abilities.csv"), mons)

    print(f"Loaded {len(mons)} mons")

    # Collect all contracts
    print("Analyzing contracts...")
    contracts = collect_all_contracts(mons, base_path)
    print(f"Found {len(contracts)} unique contracts to deploy")

    # Generate Solidity script
    print("Generating Solidity script...")
    solidity_code = generate_solidity_script(mons, contracts, base_path)

    # Write to output file
    output_path = os.path.join(base_path, "script", "SetupMons.s.sol")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(solidity_code)

    print(f"Generated deployment script: {output_path}")

    # Print summary
    print("\nSummary:")
    for mon in sorted(mons.values(), key=lambda m: m.mon_id):
        print(f"  {mon.name}: {len(mon.moves)} moves, {len(mon.abilities)} abilities")


if __name__ == "__main__":
    main()
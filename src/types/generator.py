import csv

def multiplier_to_bits(m):
    if m == 0:
        return '00'
    if m == 1:
        return '01'
    if m == 2:
        return '10'
    else:
        return '11'

def parse_csv(file_path):
    v1 = ''
    v2 = ''
    with open(file_path, 'r') as f:
        reader = csv.reader(f)
        # Skip the header row
        next(reader)  
        for row in reader:
            # Skip empty rows
            if not row or all(cell.strip() == '' for cell in row):
                continue
            attacker, defender, multiplier = row
            
            # We prepend each new value so we can use right shifts later to extract out the right one
            if len(v1) < 256:
                v1 = multiplier_to_bits(int(multiplier)) + v1
            else:
                v2 = multiplier_to_bits(int(multiplier)) + v2
    
    # Prepend v2 with zeroes for the rest of it
    v2 = ('0' * 62) + v2
    return (int(v1, 2), int(v2, 2))

def generate_solidity_contract(encoded_uints):
    contract = f"""
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {{ITypeCalculator}} from "./ITypeCalculator.sol";
import "../Enums.sol";

contract TypeCalculator is ITypeCalculator {{
    uint256 private constant MULTIPLIERS_1 = {encoded_uints[0]}; // First 128 type combinations
    uint256 private constant MULTIPLIERS_2 = {encoded_uints[1]}; // Remaining 97 type combinations

    function getTypeEffectiveness(Type attackerType, Type defenderType) external pure returns (uint32) {{
        uint256 index = uint256(attackerType) * 15 + uint256(defenderType);
        uint256 shift;
        uint256 multipliers;
        
        if (index < 128) {{
            shift = index * 2;
            multipliers = MULTIPLIERS_1;
        }} else {{
            shift = (index - 128) * 2;
            multipliers = MULTIPLIERS_2;
        }}
        
        // Return the last 2 bits of the multipliers for the correct shift
        return uint32((multipliers >> shift) & 3);
    }}
}}
"""
    return contract

def main():
    csv_file = './types.csv'  # Replace with your CSV file path
    encoded_uints = parse_csv(csv_file)
    solidity_contract = generate_solidity_contract(encoded_uints)
    
    with open('TypeCalculator.sol', 'w') as f:
        f.write(solidity_contract)
    
    print("Solidity contract has been generated and saved as TypeCalculator.sol")

if __name__ == "__main__":
    main()
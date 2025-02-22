'''
For each mon, calculate the amount of damage you need (either Attack or Special Attack) to knock it out. (We'll avoid type stuff for now)
'''

import csv
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.patches import Rectangle

mons = {}
with open('./data/mons.csv', 'r') as f:
    reader = csv.reader(f)
    next(reader)  # Skip header
    for row in reader:
        name, hp, attack, defense, sp_attack, sp_defense, speed, type1, type2, bst = row
        mons[name] = {
            'hp': int(hp),
            'attack': int(attack),
            'defense': int(defense),
            'sp_attack': int(sp_attack),
            'sp_defense': int(sp_defense),
            'speed': int(speed),
            'type1': type1,
            'type2': type2
        }

# For each mon, calculate how much each mon (including itself) would need to do (in both Atk/SpAtk) to KO it
damage_calc = {}
for mon_name, mon_stats in mons.items():
    for other_mon_name, other_mon_stats in mons.items():
        atk_damage_needed = mon_stats['hp'] / (other_mon_stats['attack'] / mon_stats['defense'])
        sp_atk_damage_needed = mon_stats['hp'] / (other_mon_stats['sp_attack'] / mon_stats['sp_defense'])
        if mon_name not in damage_calc:
            damage_calc[mon_name] = {}
        damage_calc[mon_name][other_mon_name] = {
            'atk_damage_needed': atk_damage_needed,
            'sp_atk_damage_needed': sp_atk_damage_needed
        }

# Convert results into visualization
mon_names = sorted(mons.keys())
n = len(mon_names)

# Create the figure and axis
fig, ax = plt.subplots(figsize=(15, 15), dpi=300)

# Create custom colormap from red (low damage) to white to blue (high damage)
colors = ['#FF4136', '#FFFFFF', '#0074D9']
cmap = LinearSegmentedColormap.from_list("custom", colors, N=256)

# Function to normalize values for consistent coloring
def normalize_value(value, all_values):
    min_val = min(all_values)
    max_val = max(all_values)
    return (value - min_val) / (max_val - min_val)

# Collect all damage values for normalization
all_damages = []
for defender in mon_names:
    for attacker in mon_names:
        all_damages.extend([
            damage_calc[defender][attacker]['atk_damage_needed'],
            damage_calc[defender][attacker]['sp_atk_damage_needed']
        ])

# Draw the grid
for i in range(n):
    for j in range(n):
        # Get damage values
        atk_damage = damage_calc[mon_names[i]][mon_names[j]]['atk_damage_needed']
        sp_atk_damage = damage_calc[mon_names[i]][mon_names[j]]['sp_atk_damage_needed']
        
        # Normalize values
        atk_norm = normalize_value(atk_damage, all_damages)
        sp_atk_norm = normalize_value(sp_atk_damage, all_damages)
        
        # Draw left half of cell (physical damage)
        ax.add_patch(Rectangle((j, i), 0.5, 1, 
                             facecolor=cmap(atk_norm)))
        
        # Draw right half of cell (special damage)
        ax.add_patch(Rectangle((j + 0.5, i), 0.5, 1, 
                             facecolor=cmap(sp_atk_norm)))
        
        # Add text values
        ax.text(j + 0.25, i + 0.5, f'{atk_damage:.0f}', 
                ha='center', va='center', fontsize=6)
        ax.text(j + 0.75, i + 0.5, f'{sp_atk_damage:.0f}', 
                ha='center', va='center', fontsize=6)

# Set up axes
ax.set_xlim(0, n)
ax.set_ylim(0, n)
ax.set_xticks(np.arange(n) + 0.5)
ax.set_yticks(np.arange(n) + 0.5)
ax.set_xticklabels(mon_names, rotation=45, ha='right')
ax.set_yticklabels(mon_names)

# Add grid
ax.set_xticks(np.arange(0, n, 1), minor=True)
ax.set_yticks(np.arange(0, n, 1), minor=True)
ax.grid(which="minor", color="black", linestyle='-', linewidth=0.5)

# Add title and labels
plt.title("Damage Needed to KO\n(Left: Physical, Right: Special)", pad=20)

# Add colorbar
norm = plt.Normalize(min(all_damages), max(all_damages))
sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
cbar = fig.colorbar(sm, ax=ax)  # Specify the axes to steal space from
cbar.ax.set_ylabel("Damage Needed", rotation=-90, va="bottom")

# Adjust layout and save
plt.tight_layout()
plt.savefig("damage_analysis.png", bbox_inches='tight')
plt.close()

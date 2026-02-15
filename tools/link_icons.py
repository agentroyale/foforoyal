#!/usr/bin/env python3
"""
Add icon references to Godot .tres resource files.

This script modifies .tres files in-place to add icon texture references.
"""

import os
import re
from pathlib import Path

# Base directory
BASE_DIR = Path("/home/lumen/novojogo/godot")

# Mapping of .tres files to icon filenames
MAPPING = {
    "resources/items/wood.tres": "wood",
    "resources/items/stone.tres": "stone",
    "resources/items/metal_ore.tres": "metal_ore",
    "resources/items/metal_fragments.tres": "metal_fragments",
    "resources/items/sulfur_ore.tres": "sulfur_ore",
    "resources/items/sulfur.tres": "sulfur",
    "resources/items/high_quality_metal.tres": "high_quality_metal",
    "resources/items/cloth.tres": "cloth",
    "resources/items/low_grade_fuel.tres": "low_grade_fuel",
    "resources/items/scrap.tres": "scrap",
    "resources/items/gunpowder.tres": "gunpowder",
    "resources/items/rock_tool.tres": "rock_tool",
    "resources/items/stone_hatchet.tres": "stone_hatchet",
    "resources/items/stone_pickaxe.tres": "stone_pickaxe",
    "resources/items/metal_hatchet.tres": "metal_hatchet",
    "resources/items/metal_pickaxe.tres": "metal_pickaxe",
    "resources/items/bandage.tres": "bandage",
    "resources/items/wooden_spear.tres": "wooden_spear",
    "resources/items/c4.tres": "c4",
    "resources/items/satchel_charge.tres": "satchel_charge",
    "resources/items/rocket.tres": "rocket",
    "resources/items/furnace.tres": "furnace",
    "resources/items/campfire.tres": "campfire",
    "resources/items/lock.tres": "lock",
    "resources/weapons/rock_weapon.tres": "rock_tool",
    "resources/weapons/revolver.tres": "revolver",
    "resources/weapons/thompson.tres": "thompson",
    "resources/weapons/hunting_bow.tres": "hunting_bow",
}


def process_tres_file(file_path: Path, icon_name: str) -> bool:
    """
    Process a single .tres file to add icon reference.

    Args:
        file_path: Path to the .tres file
        icon_name: Name of the icon file (without extension)

    Returns:
        True if file was modified, False otherwise
    """
    if not file_path.exists():
        print(f"⚠️  File not found: {file_path}")
        return False

    # Read the file
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if icon already exists
    if re.search(r'\bicon\s*=\s*', content):
        print(f"⏭️  Skipping {file_path.relative_to(BASE_DIR)} (already has icon)")
        return False

    lines = content.split('\n')
    new_lines = []
    modified = False

    # Track state
    in_header = True
    last_ext_resource_idx = -1
    script_line_idx = -1

    for i, line in enumerate(lines):
        # Find the header line to increment load_steps
        if in_header and line.startswith('[gd_resource'):
            # Increment load_steps
            new_line = re.sub(
                r'load_steps=(\d+)',
                lambda m: f'load_steps={int(m.group(1)) + 1}',
                line
            )
            new_lines.append(new_line)
            modified = True
            continue

        # Track the last ext_resource line
        if line.startswith('[ext_resource'):
            last_ext_resource_idx = len(new_lines)
            new_lines.append(line)
            continue

        # Found the [resource] or [sub_resource] section
        if line.startswith('[resource]') or line.startswith('[sub_resource]'):
            in_header = False

            # Insert icon ext_resource before this line
            if last_ext_resource_idx >= 0:
                # Add blank line if needed
                if new_lines and new_lines[-1].strip():
                    pass  # Keep existing spacing

                # Insert the icon ext_resource
                icon_line = f'[ext_resource type="Texture2D" path="res://assets/textures/icons/{icon_name}.png" id="icon_1"]'
                new_lines.append(icon_line)
                new_lines.append('')  # Blank line before [resource]

            new_lines.append(line)
            continue

        # Find the script = ExtResource(...) line in [resource] section
        if not in_header and re.match(r'script\s*=\s*ExtResource', line):
            script_line_idx = len(new_lines)
            new_lines.append(line)
            # Insert icon reference right after script line
            new_lines.append('icon = ExtResource("icon_1")')
            continue

        # Default: keep the line as-is
        new_lines.append(line)

    if not modified:
        print(f"⚠️  Could not modify {file_path.relative_to(BASE_DIR)} (no load_steps found)")
        return False

    # Write back to file
    new_content = '\n'.join(new_lines)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"✅ Modified {file_path.relative_to(BASE_DIR)} (added icon: {icon_name})")
    return True


def main():
    """Main entry point."""
    print("🔧 Adding icon references to .tres files...\n")

    modified_count = 0
    skipped_count = 0
    error_count = 0

    for tres_path, icon_name in MAPPING.items():
        full_path = BASE_DIR / tres_path

        try:
            if process_tres_file(full_path, icon_name):
                modified_count += 1
            else:
                if full_path.exists():
                    skipped_count += 1
                else:
                    error_count += 1
        except Exception as e:
            print(f"❌ Error processing {tres_path}: {e}")
            error_count += 1

    print(f"\n📊 Summary:")
    print(f"   Modified: {modified_count}")
    print(f"   Skipped:  {skipped_count}")
    print(f"   Errors:   {error_count}")
    print(f"   Total:    {len(MAPPING)}")


if __name__ == '__main__':
    main()

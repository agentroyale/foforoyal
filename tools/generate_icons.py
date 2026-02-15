#!/usr/bin/env python3
"""Generate game item icons using Gemini API."""

import google.generativeai as genai
from PIL import Image
import io
import os
import sys
import time

API_KEY = os.environ.get("GEMINI_API_KEY", "AIzaSyDlSllGenkYNNdLi_TnN6wqCCpO1q1dOC0")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textures", "icons")
ICON_SIZE = 128

STYLE_PROMPT = (
    "2D game inventory icon, stylized low-poly survival game style, "
    "centered object on a solid dark charcoal background (#1a1a2e), "
    "clean edges, no text, no labels, no numbers, no badges, no overlays, "
    "slightly angled 3/4 view, soft lighting from top-left, "
    "square format, single item only."
)

# item_filename: description
ITEMS = {
    # Resources
    "wood": "a bundle of 4-5 rough wooden logs tied together",
    "stone": "a rough grey stone rock, slightly jagged edges",
    "metal_ore": "a chunk of dark ore with metallic orange-copper veins",
    "metal_fragments": "a pile of small shiny metal scraps and fragments",
    "sulfur_ore": "a yellowish rocky chunk with bright yellow sulfur crystals",
    "sulfur": "a pile of bright yellow sulfur powder",
    "high_quality_metal": "a refined shiny steel ingot with a slight blue tint",
    "cloth": "a folded piece of beige-brown cloth fabric",
    "low_grade_fuel": "a rusty metal jerry can with fuel",
    "scrap": "a pile of rusty gears, springs and metal junk",
    "gunpowder": "a small pile of dark grey gunpowder with a few grains scattered",
    # Tools
    "rock_tool": "a simple grey hand-sized stone used as a primitive tool",
    "stone_hatchet": "a stone hatchet with a wooden handle and stone blade tied with rope",
    "stone_pickaxe": "a stone pickaxe with a wooden handle and pointed stone head",
    "metal_hatchet": "a metal hatchet with a wooden handle and shiny metal blade",
    "metal_pickaxe": "a metal pickaxe with a wooden handle and metal pointed head",
    # Weapons
    "assault_rifle": "a military assault rifle, dark metal with wooden furniture",
    "thompson": "a Thompson submachine gun, classic WW2 style with drum magazine",
    "revolver": "a six-shooter revolver, dark metal with wooden grip",
    "hunting_bow": "a simple wooden hunting bow with string",
    "wooden_spear": "a long wooden spear with a sharpened point",
    # Medical
    "bandage": "a rolled white medical bandage",
    # Explosives
    "c4": "a brick of C4 explosive with a small red detonator attached",
    "satchel_charge": "a crude canvas satchel bomb with a fuse",
    "rocket": "a military rocket/RPG warhead, olive green with red tip",
    # Placeables
    "furnace": "a small stone furnace with a metal grate and orange glow inside",
    "campfire": "a small campfire with stacked logs and flames",
    "lock": "a sturdy metal padlock, silver with a keyhole",
    # Building pieces
    "foundation": "a square wooden floor platform seen from above at angle",
    "wall": "a wooden wall panel with horizontal planks",
    "floor_piece": "a wooden ceiling/floor tile seen from slightly below",
    "doorway": "a wooden wall frame with an empty doorway opening",
    "door": "a wooden door with metal hinges and handle",
    "stairs": "wooden stairs going up at an angle",
    "roof": "a triangular wooden roof piece / sloped roof panel",
    "window_frame": "a wooden wall with a window opening",
    "tool_cupboard": "a small wooden cupboard/cabinet for tools",
}


def generate_icon(model, item_name: str, description: str) -> Image.Image | None:
    """Generate a single icon using Gemini."""
    prompt = f"Generate a game item icon: {description}. {STYLE_PROMPT}"

    try:
        response = model.generate_content(
            prompt,
            generation_config={"response_modalities": ["IMAGE", "TEXT"]},
        )

        for part in response.candidates[0].content.parts:
            if hasattr(part, "inline_data") and part.inline_data:
                image_data = part.inline_data.data
                img = Image.open(io.BytesIO(image_data))
                img = img.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
                return img
    except Exception as e:
        print(f"  ERROR generating {item_name}: {e}")
    return None


def main():
    genai.configure(api_key=API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-image")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Filter items if args provided
    items_to_generate = ITEMS
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        filter_names = set(args)
        items_to_generate = {k: v for k, v in ITEMS.items() if k in filter_names}

    total = len(items_to_generate)
    generated = 0
    skipped = 0

    for i, (name, desc) in enumerate(items_to_generate.items(), 1):
        out_path = os.path.join(OUTPUT_DIR, f"{name}.png")

        # Skip if already exists (use --force to regenerate)
        if os.path.exists(out_path) and "--force" not in sys.argv:
            print(f"[{i}/{total}] {name} — already exists, skipping")
            skipped += 1
            continue

        print(f"[{i}/{total}] Generating {name}...")
        img = generate_icon(model, name, desc)

        if img:
            img.save(out_path)
            generated += 1
            print(f"  -> saved {out_path}")
        else:
            print(f"  -> FAILED")

        # Rate limit: ~15 RPM for free tier
        if i < total:
            time.sleep(4)

    print(f"\nDone: {generated} generated, {skipped} skipped, {total - generated - skipped} failed")


if __name__ == "__main__":
    main()

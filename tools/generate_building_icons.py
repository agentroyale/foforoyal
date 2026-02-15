#!/usr/bin/env python3
"""Generate building piece icons using Imagen 4 via Google GenAI SDK.

Usage:
    pip install google-genai Pillow python-dotenv
    python3 tools/generate_building_icons.py           # generate missing only
    python3 tools/generate_building_icons.py --force    # regenerate all
    python3 tools/generate_building_icons.py pillar half_wall  # specific items
"""

from google import genai
from google.genai import types
from PIL import Image
import io
import os
import sys
import time
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

API_KEY = os.environ.get("GEMINI_API_KEY", "")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textures", "icons")
ICON_SIZE = 128

STYLE_PROMPT = (
    "2D game inventory icon, stylized low-poly survival game style, "
    "centered object on a solid dark charcoal background (#1a1a2e), "
    "clean edges, no text, no labels, no numbers, no badges, no overlays, "
    "slightly angled 3/4 view, soft lighting from top-left, "
    "square format, single item only."
)

BUILDING_ICONS = {
    "foundation": "a square wooden floor platform seen from above at angle, rough planks",
    "wall": "a wooden wall panel with horizontal planks, nails visible",
    "floor_piece": "a wooden ceiling/floor tile seen from slightly below, planks",
    "doorway": "a wooden wall frame with an empty doorway opening in the center",
    "door": "a wooden door with metal hinges and a simple handle",
    "stairs": "wooden stairs going up at an angle, side view",
    "roof": "a triangular wooden roof piece, sloped roof panel",
    "window_frame": "a wooden wall panel with a square window opening",
    "tool_cupboard": "a small wooden cupboard/cabinet for storing tools",
    "triangle_foundation": "a triangular wooden floor platform seen from above, rough planks",
    "half_wall": "a short half-height wooden wall panel, horizontal planks",
    "wall_arched": "a wooden wall with an arched opening at the top",
    "wall_gated": "a wooden wall with a large gate/door frame opening",
    "wall_window_arched": "a wooden wall with an arched window opening",
    "wall_window_closed": "a wooden wall with a closed/shuttered window",
    "ceiling": "a flat wooden ceiling panel seen from below, planks with beams",
    "floor_wood": "a polished wooden floor tile seen from above, nice wood grain",
    "pillar": "a vertical wooden support pillar/column, structural beam",
}


def generate_icon(client: genai.Client, item_name: str, description: str) -> Image.Image | None:
    prompt = f"Generate a game building piece icon: {description}. {STYLE_PROMPT}"
    try:
        response = client.models.generate_images(
            model="imagen-4.0-generate-001",
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                aspect_ratio="1:1",
            ),
        )
        if response.generated_images:
            image_bytes = response.generated_images[0].image.image_bytes
            img = Image.open(io.BytesIO(image_bytes))
            img = img.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
            return img
    except Exception as e:
        print(f"  ERROR generating {item_name}: {e}")
    return None


def main():
    if not API_KEY:
        print("ERROR: GEMINI_API_KEY not set. Check your .env file.")
        sys.exit(1)

    client = genai.Client(api_key=API_KEY)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    items_to_generate = BUILDING_ICONS
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        filter_names = set(args)
        items_to_generate = {k: v for k, v in BUILDING_ICONS.items() if k in filter_names}

    total = len(items_to_generate)
    generated = 0
    skipped = 0

    for i, (name, desc) in enumerate(items_to_generate.items(), 1):
        out_path = os.path.join(OUTPUT_DIR, f"{name}.png")

        if os.path.exists(out_path) and "--force" not in sys.argv:
            print(f"[{i}/{total}] {name} -- already exists, skipping")
            skipped += 1
            continue

        print(f"[{i}/{total}] Generating {name}...")
        img = generate_icon(client, name, desc)

        if img:
            img.save(out_path)
            generated += 1
            print(f"  -> saved {out_path}")
        else:
            print(f"  -> FAILED")

        if i < total:
            time.sleep(3)

    print(f"\nDone: {generated} generated, {skipped} skipped, {total - generated - skipped} failed")


if __name__ == "__main__":
    main()

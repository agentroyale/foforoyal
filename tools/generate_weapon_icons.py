#!/usr/bin/env python3
"""Generate weapon icons using Gemini API."""

import google.generativeai as genai
from PIL import Image, ImageDraw, ImageFont
import io
import os
import sys
import time

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

# weapon_filename: description
WEAPONS = {
    "pistol": "a modern semi-automatic handgun pistol, grey steel",
    "mp5": "an MP5 submachine gun, compact black tactical",
    "bullpup": "a bullpup assault rifle, modern tactical green",
    "pump_shotgun": "a pump-action shotgun, brown wood and steel",
    "sawed_off": "a sawed-off double barrel shotgun, short barrels",
    "sniper_rifle": "a modern sniper rifle with scope, dark grey",
    "bolt_action": "a bolt-action rifle with scope, wood stock",
}


def create_placeholder_icon(weapon_name: str) -> Image.Image:
    """Create a simple placeholder icon with text."""
    img = Image.new("RGB", (ICON_SIZE, ICON_SIZE), color="#1a1a2e")
    draw = ImageDraw.Draw(img)

    # Draw weapon name text
    text = weapon_name.replace("_", "\n").upper()

    # Use default font
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    except:
        font = ImageFont.load_default()

    # Get text bbox and center it
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (ICON_SIZE - text_width) // 2
    y = (ICON_SIZE - text_height) // 2

    # Draw dark grey background box
    padding = 10
    draw.rectangle(
        [x - padding, y - padding, x + text_width + padding, y + text_height + padding],
        fill="#2a2a3e"
    )

    # Draw text
    draw.text((x, y), text, fill="#888888", font=font)

    return img


def generate_icon(model, weapon_name: str, description: str) -> Image.Image | None:
    """Generate a single weapon icon using Gemini."""
    if not API_KEY:
        print(f"  No API key, creating placeholder...")
        return create_placeholder_icon(weapon_name)

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
        print(f"  ERROR generating {weapon_name}: {e}")
        print(f"  Creating placeholder instead...")
        return create_placeholder_icon(weapon_name)

    return None


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Configure Gemini if API key exists
    model = None
    if API_KEY:
        try:
            genai.configure(api_key=API_KEY)
            model = genai.GenerativeModel("gemini-2.5-flash-image")
            print("Gemini API configured successfully")
        except Exception as e:
            print(f"Failed to configure Gemini API: {e}")
            print("Will use placeholders instead")
    else:
        print("No GEMINI_API_KEY found in environment")
        print("Will create placeholder icons instead")

    # Filter weapons if args provided
    weapons_to_generate = WEAPONS
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        filter_names = set(args)
        weapons_to_generate = {k: v for k, v in WEAPONS.items() if k in filter_names}

    total = len(weapons_to_generate)
    generated = 0
    skipped = 0

    for i, (name, desc) in enumerate(weapons_to_generate.items(), 1):
        out_path = os.path.join(OUTPUT_DIR, f"{name}.png")

        # Skip if already exists (use --force to regenerate)
        if os.path.exists(out_path) and "--force" not in sys.argv:
            print(f"[{i}/{total}] {name} — already exists, skipping")
            skipped += 1
            continue

        print(f"[{i}/{total}] Generating {name}...")
        img = generate_icon(model, name, desc) if model else create_placeholder_icon(name)

        if img:
            img.save(out_path)
            generated += 1
            print(f"  -> saved {out_path}")
        else:
            print(f"  -> FAILED (creating placeholder)")
            img = create_placeholder_icon(name)
            img.save(out_path)
            generated += 1

        # Rate limit: ~15 RPM for free tier (only if using API)
        if model and i < total:
            time.sleep(4)

    print(f"\nDone: {generated} generated, {skipped} skipped")


if __name__ == "__main__":
    main()

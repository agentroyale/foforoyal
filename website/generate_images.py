#!/usr/bin/env python3
"""Generate website images using Gemini API."""

import google.generativeai as genai
from PIL import Image
import io
import os
import sys
import time

API_KEY = os.environ.get("GEMINI_API_KEY", "AIzaSyAg0VY8xrkrzFIM_LIt_Xt27XA9Gvup-74")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "img")

STYLE_BASE = (
    "Low-poly stylized 3D render, chibi proportions, KayKit art style, "
    "vibrant colors, dark moody atmosphere, no text, no watermark, no UI elements"
)

IMAGES = {
    # Hero banner (1920x800)
    "hero_banner": {
        "prompt": f"Wide panoramic scene of a low-poly battle royale battlefield at dusk, "
                  f"a ruined city with cute chibi soldiers parachuting down from a plane, "
                  f"explosions and gunfire in the distance, orange-purple dramatic sky, "
                  f"cinematic composition. {STYLE_BASE}",
        "size": (1920, 800),
    },
    # Feature images (800x600)
    "feature_combat": {
        "prompt": f"Two chibi soldiers in intense third-person combat, one firing an assault rifle "
                  f"with muzzle flash, bullet tracers flying, another taking cover behind a wall, "
                  f"urban environment. {STYLE_BASE}",
        "size": (800, 600),
    },
    "feature_building": {
        "prompt": f"A chibi character building a wooden base structure, placing wall pieces, "
                  f"partially constructed fort with foundation and walls visible, "
                  f"construction in progress feel. {STYLE_BASE}",
        "size": (800, 600),
    },
    "feature_looting": {
        "prompt": f"A chibi character opening a glowing loot crate in a dark room, "
                  f"weapons and items spilling out, golden glow illuminating the scene, "
                  f"excited discovery moment. {STYLE_BASE}",
        "size": (800, 600),
    },
    "feature_zone": {
        "prompt": f"Aerial view of a shrinking danger zone in a battle royale, "
                  f"a glowing red-orange energy wall closing in on a low-poly city, "
                  f"tiny chibi soldiers running toward the safe area, dramatic. {STYLE_BASE}",
        "size": (800, 600),
    },
    # Game mode images (900x500)
    "mode_survival": {
        "prompt": f"A chibi character in a survival game, standing next to a campfire "
                  f"outside a wooden base at night, trees and mountains in background, "
                  f"cozy but dangerous wilderness atmosphere, torch light. {STYLE_BASE}",
        "size": (900, 500),
    },
    "mode_br": {
        "prompt": f"Battle royale drop scene, 30 chibi soldiers jumping from a plane "
                  f"with colorful parachutes over a low-poly city grid, "
                  f"top-down perspective, vibrant and action-packed. {STYLE_BASE}",
        "size": (900, 500),
    },
    # Character art (400x500)
    "char_barbarian": {
        "prompt": f"A chibi barbarian warrior character, muscular with red war paint, "
                  f"holding a large axe, fierce battle stance, "
                  f"red accent lighting, dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    "char_knight": {
        "prompt": f"A chibi knight character in blue armor with shield and sword, "
                  f"noble heroic pose, blue accent lighting, dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    "char_mage": {
        "prompt": f"A chibi mage character in purple robes with a glowing staff, "
                  f"magical purple energy particles, mystical pose, dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    "char_ranger": {
        "prompt": f"A chibi ranger character in green outfit with a bow and arrow, "
                  f"stealthy stance, green forest accent lighting, dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    "char_rogue": {
        "prompt": f"A chibi rogue character in dark leather with dual daggers, "
                  f"sneaky crouching pose, golden-amber accent lighting, dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    "char_hooded": {
        "prompt": f"A chibi hooded mysterious character in a dark grey cloak, "
                  f"face hidden in shadow, arms crossed, cool grey-blue accent lighting, "
                  f"dark background. {STYLE_BASE}",
        "size": (400, 500),
    },
    # Logo (600x200)
    "logo": {
        "prompt": "Game logo design for 'CHIBI ROYALE', bold blocky letters with battle damage, "
                  "golden-orange color with dark outline, low-poly style, "
                  "small crown on the R, transparent-style dark background, clean vector look",
        "size": (600, 200),
    },
    # Favicon (64x64)
    "favicon": {
        "prompt": "A tiny chibi soldier head icon, cute round face with helmet, "
                  "simple bold design suitable for a 64x64 favicon, "
                  "dark background, low-poly style, bright colors",
        "size": (64, 64),
    },
}


def generate_image(model, name: str, config: dict) -> Image.Image | None:
    """Generate a single image using Gemini."""
    prompt = f"Generate an image: {config['prompt']}"
    try:
        response = model.generate_content(
            prompt,
            generation_config={"response_modalities": ["IMAGE", "TEXT"]},
        )
        for part in response.candidates[0].content.parts:
            if hasattr(part, "inline_data") and part.inline_data:
                image_data = part.inline_data.data
                img = Image.open(io.BytesIO(image_data))
                w, h = config["size"]
                img = img.resize((w, h), Image.LANCZOS)
                return img
    except Exception as e:
        print(f"  ERROR generating {name}: {e}")
    return None


def main():
    genai.configure(api_key=API_KEY)
    model = genai.GenerativeModel("gemini-2.5-flash-image")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    items_to_generate = IMAGES
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        filter_names = set(args)
        items_to_generate = {k: v for k, v in IMAGES.items() if k in filter_names}

    total = len(items_to_generate)
    generated = 0
    skipped = 0

    for i, (name, config) in enumerate(items_to_generate.items(), 1):
        out_path = os.path.join(OUTPUT_DIR, f"{name}.png")

        if os.path.exists(out_path) and "--force" not in sys.argv:
            print(f"[{i}/{total}] {name} -- already exists, skipping")
            skipped += 1
            continue

        print(f"[{i}/{total}] Generating {name} ({config['size'][0]}x{config['size'][1]})...")
        img = generate_image(model, name, config)

        if img:
            img.save(out_path)
            generated += 1
            print(f"  -> saved {out_path}")
        else:
            print(f"  -> FAILED")

        if i < total:
            time.sleep(4)

    print(f"\nDone: {generated} generated, {skipped} skipped, {total - generated - skipped} failed")


if __name__ == "__main__":
    main()

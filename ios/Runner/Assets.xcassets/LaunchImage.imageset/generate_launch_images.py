"""Generate iOS LaunchImage PNGs from the kerosene-logo-white.png foreground."""
import sys
import os
from PIL import Image

src = "/home/astrofer/Kerosene/frontend/assets/logo/kerosene-logo-white.png"
out_dir = os.path.dirname(os.path.abspath(__file__))

if not os.path.exists(src):
    print(f"Source not found: {src}")
    sys.exit(1)

src_img = Image.open(src).convert("RGBA")
print(f"Source: {src_img.size}")

# Simple resize, white logo on transparent background
# 1x = 120pt, 2x = 240pt, 3x = 360pt
# We want the icon to be centered and about 60% of the size
sizes = {
    "LaunchImage.png": 100,    # 1x = 100px
    "LaunchImage@2x.png": 200, # 2x = 200px
    "LaunchImage@3x.png": 300, # 3x = 300px
}

for filename, target_size in sizes.items():
    out_path = os.path.join(out_dir, filename)
    resized = src_img.resize((target_size, target_size), Image.LANCZOS)
    resized.save(out_path, "PNG")
    print(f"Saved: {out_path} ({target_size}x{target_size})")

print("Done generating iOS LaunchImages.")

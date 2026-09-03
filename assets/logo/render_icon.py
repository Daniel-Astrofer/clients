"""Render Kerosene Lottie logo to high-quality PNG for Flutter app icon.

Outputs:
  kerosene-logo-white.png   — White logo on transparent (for flutter_launcher_icons)
  kerosene-icon-black.png   — White logo on black (combined icon for iOS/Win/Mac)
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ASSET_DIR = Path(__file__).resolve().parent
LOTTIE_PATH = ASSET_DIR / "kerosene-logo-white.json"
OUTPUT_FG = ASSET_DIR / "kerosene-logo-white.png"
OUTPUT_COMBINED = ASSET_DIR / "kerosene-icon-black.png"

with LOTTIE_PATH.open(encoding="utf-8") as f:
    anim = json.load(f)

W, H = anim["w"], anim["h"]


def scalar(v):
    if isinstance(v, list):
        return v[0] if len(v) == 1 else v
    return v


def lerp(a, b, t):
    if isinstance(a, list) and isinstance(b, list):
        return [ai + (bi - ai) * t for ai, bi in zip(a, b)]
    return a + (b - a) * t


def eval_val(val, frame):
    if not isinstance(val, dict):
        return val
    k = val.get("k", val)
    a = val.get("a", 0)
    if a == 0:
        return k
    if not isinstance(k, list) or len(k) == 0:
        return k
    for i, kf in enumerate(k):
        t = kf.get("t", 0)
        if frame < t:
            if i == 0:
                return kf.get("s", k)
            prev = k[i - 1]
            t0, t1 = prev["t"], kf["t"]
            if t1 <= t0:
                return kf.get("s", prev.get("s"))
            r = (frame - t0) / (t1 - t0)
            return lerp(prev["s"], kf["s"], r)
    return k[-1].get("s", k)


def get_path(path_data):
    v = path_data["v"]
    i_p = path_data["i"]
    o_p = path_data["o"]
    n = len(v)
    steps = 32
    pts = []
    for idx in range(n):
        x0, y0 = v[idx]
        ox, oy = o_p[idx]
        nxt = (idx + 1) % n
        x1, y1 = v[nxt]
        ix, iy = i_p[nxt]
        for s in range(steps + 1):
            t = s / steps
            u = 1 - t
            bx = u ** 3 * x0 + 3 * u ** 2 * t * (x0 + ox) + 3 * u * t ** 2 * (x1 + ix) + t ** 3 * x1
            by = u ** 3 * y0 + 3 * u ** 2 * t * (y0 + oy) + 3 * u * t ** 2 * (y1 + iy) + t ** 3 * y1
            pts.append((bx, by))
    return pts


def render_shape_mask(frame):
    """Render only the logo shape in white on a transparent canvas.
    Returns a grayscale Image where white = logo, black = outside.
    """
    mask = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(mask)

    for layer in anim["layers"]:
        if layer["ty"] != 4:
            continue

        layer_o = scalar(eval_val(layer["ks"].get("o", 100), frame))
        layer_s = scalar(eval_val(layer["ks"].get("s", 100), frame))

        for grp in layer.get("shapes", []):
            if grp["ty"] != "gr":
                continue

            tr = grp.get("tr", {})
            anchor = scalar(eval_val(tr.get("a", [0, 0]), frame))
            position = scalar(eval_val(tr.get("p", [0, 0]), frame))
            grp_scale = scalar(eval_val(tr.get("s", 100), frame))
            grp_o = scalar(eval_val(tr.get("o", 100), frame))

            opacity = (layer_o / 100.0) * (grp_o / 100.0)
            if opacity <= 0:
                continue

            if isinstance(grp_scale, list):
                gsx, gsy = grp_scale[0] / 100.0, grp_scale[1] / 100.0
            else:
                gsx = gsy = grp_scale / 100.0

            # Determine if this shape is the white background → skip it
            is_bg = False
            for it in grp.get("it", []):
                if it["ty"] == "fl":
                    c = it["c"]["k"]
                    if c[0] > 0.99 and c[1] > 0.99 and c[2] > 0.99:
                        is_bg = True

            if is_bg:
                continue

            for it in grp.get("it", []):
                if it["ty"] == "sh":
                    pd = it["ks"]["k"]
                    pts = get_path(pd)

                    if gsx != 1.0 or gsy != 1.0:
                        ax, ay = (anchor[0], anchor[1]) if isinstance(anchor, list) else (0, 0)
                        px, py = (position[0], position[1]) if isinstance(position, list) else (0, 0)
                        pts = [((x - ax) * gsx + ax + (px - ax) * (1 - gsx),
                                (y - ay) * gsy + ay + (py - ay) * (1 - gsy))
                               for x, y in pts]

                    a_val = int(opacity * 255)
                    if a_val > 255:
                        a_val = 255
                    draw.polygon(pts, fill=a_val)

    return mask


FRAME = 59

print(f"Rendering logo mask (frame {FRAME})...")
mask = render_shape_mask(FRAME)
print(f"  Mask size: {mask.size}, non-zero pixels: {mask.getextrema()}")

# Foreground: white logo on transparent background
fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
fg_rgba = fg.load()
mask_data = mask.load()
for y in range(H):
    for x in range(W):
        m = mask_data[x, y]
        if m > 0:
            fg_rgba[x, y] = (255, 255, 255, m)
fg.save(OUTPUT_FG, "PNG")
print(f"Saved foreground: {OUTPUT_FG}")

# Combined: white logo on black background (for iOS/macOS/Windows icons)
combined = Image.new("RGBA", (W, H), (0, 0, 0, 255))
combined_rgba = combined.load()
for y in range(H):
    for x in range(W):
        m = mask_data[x, y]
        if m > 0:
            combined_rgba[x, y] = (255, 255, 255, m)
combined.save(OUTPUT_COMBINED, "PNG")
print(f"Saved combined: {OUTPUT_COMBINED}")

print("Done.")

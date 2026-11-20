"""Build the wheel textures (TGA) for the add-on, and their PNG copies for
the training web page.

Usage, from the repo root:
    npm pack @iconify-json/game-icons && tar xzf iconify-json-game-icons-*.tgz
    pip install cairosvg pillow
    python3 tools/make_media.py package/icons.json   # everything
    python3 tools/make_media.py textures             # sectors and center only (Pillow)
    python3 tools/make_media.py png OUT_DIR          # PNG copies of Media/ (Pillow)

Writes CommandAndConquer/Media/:
    sector3_fill.tga, sector3_border.tga   one sector of a 3-part wheel, pointing up
    sector5_fill.tga, sector5_border.tga   one sector of a 5-part wheel (step 1, v0.8)
    sector6_fill.tga, sector6_border.tga   one sector of a 6-part wheel, pointing up
    center.tga                              center disc with its border
    icons/<name>.tga                        white game-icons.net icons, 64x64

Sector textures span the whole wheel (the wheel center is the texture
center) so the add-on rotates one texture per sector. Everything stays
inside the inscribed circle, so rotation never clips.
"""

import io
import json
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "CommandAndConquer", "Media")

SIZE = 512          # final texture size
SS = 4              # supersampling
OUTER = 0.48        # outer radius, fraction of texture size (inside inscribed circle)
INNER = OUTER * 0.32  # inner radius (hollow center / center disc)
GAP = 0.011         # gap between sectors, fraction of texture size
BORDER = 0.0055     # border thickness, fraction of texture size
BORDER_RGBA = (166, 138, 98, 235)

# Icon name in the add-on -> game-icons.net name.
ICONS = {
    "def": "checked-shield",
    "flag": "flying-flag",
    "efc": "running-ninja",
    "attack": "broadsword",
    "inc": "hazard-sign",
    "scout": "spyglass",
    "cancel": "cancel",
    "take": "grab",
    "roof": "house",
    "ramp": "stairs",
    "tunnel": "dungeon-gate",
    "gy": "tombstone",
    "mid": "crossroad",
    "escort": "guards",
    "zerg": "rally-the-troops",
    "help": "medical-pack",
    "cap": "trophy-cup",
}


def save_tga(img, name):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, format="TGA")
    return path


def sector_mask(n):
    big = SIZE * SS
    c = big / 2
    r_out, r_in = OUTER * big, INNER * big
    half = math.pi / n
    pts = []
    steps = 96
    for i in range(steps + 1):  # outer arc, left to right (bearing from -half to +half)
        a = -half + 2 * half * i / steps
        pts.append((c + r_out * math.sin(a), c - r_out * math.cos(a)))
    for i in range(steps + 1):  # inner arc, back
        a = half - 2 * half * i / steps
        pts.append((c + r_in * math.sin(a), c - r_in * math.cos(a)))
    mask = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(mask)
    d.polygon(pts, fill=255)
    # Constant-width gaps along the two sector edges, and around the center.
    gap = GAP * big
    for a in (-half, half):
        d.line([(c, c), (c + 2 * r_out * math.sin(a), c - 2 * r_out * math.cos(a))], fill=0, width=int(gap))
    d.ellipse([c - r_in - gap / 2, c - r_in - gap / 2, c + r_in + gap / 2, c + r_in + gap / 2], fill=0)
    # Slightly rounded corners.
    mask = mask.filter(ImageFilter.GaussianBlur(SS * 2)).point(lambda v: 255 if v > 128 else 0)
    return mask


def ring_border(mask, width_px):
    k = int(width_px) | 1
    eroded = mask.filter(ImageFilter.MinFilter(k))
    return ImageChops.subtract(mask, eroded)


def colorize(alpha_big, rgba):
    alpha = alpha_big.resize((SIZE, SIZE), Image.LANCZOS)
    r, g, b, a = rgba
    img = Image.new("RGBA", (SIZE, SIZE), (r, g, b, 0))
    img.putalpha(alpha.point(lambda v: v * a // 255))
    return img


def make_sectors(n):
    mask = sector_mask(n)
    border = ring_border(mask, BORDER * SIZE * SS * 2)
    save_tga(colorize(mask, (255, 255, 255, 255)), f"sector{n}_fill.tga")
    save_tga(colorize(border, BORDER_RGBA), f"sector{n}_border.tga")


def make_center():
    size = 256
    big = size * SS
    c = big / 2
    r = 0.47 * big
    disc = Image.new("L", (big, big), 0)
    ImageDraw.Draw(disc).ellipse([c - r, c - r, c + r, c + r], fill=255)
    border = ring_border(disc, 0.022 * big)
    fill = disc.resize((size, size), Image.LANCZOS)
    edge = border.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (18, 16, 14, 0))
    img.putalpha(fill.point(lambda v: v * 200 // 255))
    rim = Image.new("RGBA", (size, size), BORDER_RGBA[:3] + (0,))
    rim.putalpha(edge.point(lambda v: v * BORDER_RGBA[3] // 255))
    img = Image.alpha_composite(img, rim)
    save_tga(img, "center.tga")


def make_icons(icons_json):
    import cairosvg  # only needed for the icons

    data = json.load(open(icons_json))["icons"]
    for key, name in ICONS.items():
        body = data[name]["body"]
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
               f'width="64" height="64" style="color:white">{body}</svg>')
        png = cairosvg.svg2png(bytestring=svg.encode())
        img = Image.open(io.BytesIO(png)).convert("RGBA")
        save_tga(img, f"icons/{key}.tga")


def export_png(out_dir):
    """Same pixels as the add-on's TGA files, as PNG for the browser."""
    count = 0
    for folder, _, files in os.walk(OUT):
        for name in files:
            if not name.endswith(".tga"):
                continue
            rel = os.path.relpath(os.path.join(folder, name), OUT)
            dest = os.path.join(out_dir, rel[:-4] + ".png")
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            Image.open(os.path.join(folder, name)).convert("RGBA").save(dest, optimize=True)
            count += 1
    print(count, "PNG files written to", os.path.normpath(out_dir))


def main():
    args = sys.argv[1:]
    if args[:1] == ["png"] and len(args) == 2:
        export_png(args[1])
        return
    if args == ["textures"]:
        for n in (3, 5, 6):
            make_sectors(n)
        make_center()
    elif len(args) == 1:
        for n in (3, 5, 6):
            make_sectors(n)
        make_center()
        make_icons(args[0])
    else:
        sys.exit(__doc__)
    print("Media written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()

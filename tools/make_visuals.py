#!/usr/bin/env python3
"""Generate all 2D art for IGI 3 2D from local data (no downloads).

    python tools/make_visuals.py

Outputs actor sprites, the menu background and the README key art.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
DOC = ROOT / "docs" / "images"
SPR.mkdir(parents=True, exist_ok=True)
DOC.mkdir(parents=True, exist_ok=True)

FONT = ROOT / "assets" / "fonts" / "NotoSans-Bold.ttf"
MAP = ROOT / "assets" / "maps" / "kajla_osm.png"
GOLD = (214, 176, 98)
TEAL = (105, 198, 184)
CREAM = (240, 235, 220)
INK = (10, 18, 22)

PALETTE = {
    "hero": (36, 86, 88, GOLD),
    "enemy": (104, 42, 44, (220, 120, 110)),
    "commander": (130, 36, 48, GOLD),
    "military": (74, 86, 52, (190, 200, 140)),
    "police": (38, 58, 92, (150, 180, 225)),
    "airforce": (52, 96, 130, (170, 215, 240)),
    "naval": (28, 48, 78, (120, 160, 210)),
    "commando": (44, 72, 48, (150, 205, 140)),
    "protector": (210, 208, 196, (250, 245, 225)),
    "gang": (110, 62, 30, (240, 160, 90)),
    "civilian": (92, 88, 82, (190, 185, 170)),
}


def sprite(name: str, spec) -> Image.Image:
    body, accent = spec[:3], spec[3]
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((6, 30, 58, 58), fill=(0, 0, 0, 55))          # shadow
    d.rounded_rectangle((18, 16, 46, 48), radius=11, fill=body + (255,),
                        outline=accent + (255,), width=2)   # torso
    d.ellipse((25, 8, 39, 22), fill=(205, 174, 140, 255))   # head
    d.ellipse((27, 10, 37, 20), fill=(30, 38, 40, 255))     # hair/cap
    d.line((32, 24, 32, 4), fill=accent + (255,), width=4)  # facing / weapon
    d.ellipse((29, 1, 35, 7), fill=(235, 230, 210, 255))
    return im


def font(size):
    return ImageFont.truetype(str(FONT), size)


def dark_map(size, coverage=1.0):
    src = Image.open(MAP).convert("RGB")
    w, h = size
    scale = max(w / src.width, h / src.height) * coverage
    src = src.resize((int(src.width * scale), int(src.height * scale)), Image.LANCZOS)
    left = (src.width - w) // 2
    top = (src.height - h) // 2
    src = src.crop((left, top, left + w, top + h))
    src = ImageEnhance.Color(src).enhance(0.25)
    src = ImageEnhance.Brightness(src).enhance(0.42)
    return src


def menu_bg():
    w, h = 1280, 720
    im = dark_map((w, h), 1.25).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(5, 16, 20, 90))
    for x in range(0, w, 64):
        d.line((x, 0, x - 360, h), fill=(90, 190, 175, 22), width=2)
    d.rectangle((0, h - 8, w, h), fill=GOLD + (255,))
    im = Image.alpha_composite(im, over)
    im.convert("RGB").save(SPR / "menu_bg.png", optimize=True)


def sheet():
    cols = 4
    cw, ch = 120, 130
    rows = (len(PALETTE) + cols - 1) // cols
    im = Image.new("RGB", (cols * cw, rows * ch), INK)
    d = ImageDraw.Draw(im)
    for i, (name, spec) in enumerate(PALETTE.items()):
        x = (i % cols) * cw
        y = (i // cols) * ch
        sp = sprite(name, spec)
        im.paste(sp, (x + cw // 2 - 32, y + 4), sp)
        d.text((x + cw // 2, y + 72), name, font=font(14), fill=CREAM, anchor="mm")
    im.save(DOC / "sprites.png", optimize=True)


def banner():
    w, h = 1600, 620
    im = dark_map((w, h), 1.2).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(4, 14, 18, 120))
    d.rectangle((56, 50, 66, h - 50), fill=GOLD + (255,))
    d.text((96, 80), "IGI 3  /  2D", font=font(140), fill=CREAM + (255,))
    d.text((102, 244), "SONTEK KAJLA - TOP-DOWN STEALTH", font=font(46), fill=GOLD + (255,))
    d.line((102, 320, 760, 320), fill=GOLD + (200,), width=3)
    d.text((104, 348), "15 BENGALI MISSIONS  /  REAL OSM MAP  /  GODOT 4.3",
           font=font(28), fill=TEAL + (255,))
    chips = ["WALK-IN BUILDINGS", "165 NEUTRALS", "BCS GATES", "SHOPS + ECONOMY"]
    x = 104
    for c in chips:
        tw = d.textbbox((0, 0), c, font=font(20))[2]
        d.rounded_rectangle((x, 450, x + tw + 36, 506), radius=8,
                            fill=(10, 26, 30, 220), outline=GOLD + (190,), width=2)
        d.text((x + 18, 478), c, font=font(20), fill=TEAL + (255,), anchor="lm")
        x += tw + 54
    d.rectangle((0, h - 8, w, h), fill=GOLD + (255,))
    Image.alpha_composite(im, over).convert("RGB").save(DOC / "banner.png", optimize=True)


def map_overview():
    w, h = 1200, 760
    im = dark_map((w, h), 1.0).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(4, 12, 16, 45))
    d.rounded_rectangle((36, 34, 580, 158), radius=12, fill=(5, 13, 18, 230),
                        outline=GOLD + (220,), width=3)
    d.text((66, 76), "SONTEK KAJLA 2D", font=font(48), fill=CREAM + (255,))
    d.text((68, 130), "REAL OPENSTREETMAP FOOTPRINTS - DHAKA", font=font(20), fill=TEAL + (255,))
    d.rectangle((0, h - 10, w, h), fill=GOLD + (255,))
    Image.alpha_composite(im, over).convert("RGB").save(DOC / "map-overview.png", optimize=True)


if __name__ == "__main__":
    for name, spec in PALETTE.items():
        sprite(name, spec).save(SPR / f"actor_{name}.png")
    menu_bg()
    sheet()
    banner()
    map_overview()
    for p in sorted(SPR.glob("*.png")) + sorted(DOC.glob("*.png")):
        print(p.relative_to(ROOT), p.stat().st_size // 1024, "KB")

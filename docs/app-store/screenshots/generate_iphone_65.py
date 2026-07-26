#!/usr/bin/env python3
"""Generate Blind Tiger App Store screenshots for iPhone 6.5\" Display."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / "iphone-6.5"
ASSETS = ROOT / "assets/images"

# iPhone 12/13 Pro Max — accepted for App Store Connect "iPhone 6.5\" Display"
W, H = 1284, 2778

TIGER_RED = (212, 37, 43)
MATTE = (14, 14, 14)
GOLD = (184, 146, 74)
GOLD_DIM = (139, 108, 50)
OFFWHITE = (245, 245, 245)
MUTED = (163, 163, 163)
GREEN = (46, 204, 113)
YELLOW = (241, 196, 15)


def pick_font(candidates: list[str], size: int, index: int = 0) -> ImageFont.ImageFont:
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                try:
                    return ImageFont.truetype(path, size)
                except OSError:
                    continue
    return ImageFont.load_default()


DISPLAY = [
    "/System/Library/Fonts/Supplemental/Didot.ttc",
    "/System/Library/Fonts/Supplemental/Bodoni 72.ttc",
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
]
SANS = [
    "/System/Library/Fonts/Avenir Next.ttc",
    "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
    "/System/Library/Fonts/HelveticaNeue.ttc",
]
CJK = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/Supplemental/Songti.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
]


def f_display(size: int) -> ImageFont.ImageFont:
    return pick_font(DISPLAY, size, 0)


def f_sans(size: int) -> ImageFont.ImageFont:
    return pick_font(SANS, size, 0)


def f_sans_bold(size: int) -> ImageFont.ImageFont:
    return pick_font(SANS, size, 1)


def f_ui(size: int) -> ImageFont.ImageFont:
    return pick_font(SANS, size, 0)


def f_cjk(size: int) -> ImageFont.ImageFont:
    return pick_font(CJK, size, 0)


def cover_crop(img: Image.Image, tw: int, th: int, focus=(0.5, 0.45)) -> Image.Image:
    iw, ih = img.size
    scale = max(tw / iw, th / ih)
    nw, nh = int(iw * scale), int(ih * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = int((nw - tw) * focus[0])
    top = int((nh - th) * focus[1])
    left = max(0, min(left, nw - tw))
    top = max(0, min(top, nh - th))
    return img.crop((left, top, left + tw, top + th))


def darken(img: Image.Image, alpha: float = 0.55) -> Image.Image:
    overlay = Image.new("RGB", img.size, MATTE)
    return Image.blend(img, overlay, alpha)


def grade_red(img: Image.Image, strength: float = 0.18) -> Image.Image:
    r, g, b = img.split()
    r = r.point(lambda x: min(255, int(x + 180 * strength)))
    g = g.point(lambda x: max(0, int(x - 60 * strength)))
    b = b.point(lambda x: max(0, int(x - 100 * strength)))
    return Image.merge("RGB", (r, g, b))


def text_center(draw: ImageDraw.ImageDraw, text: str, y: int, font, fill, canvas_w=W):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(((canvas_w - tw) // 2, y), text, font=font, fill=fill)


def draw_status_bar(draw: ImageDraw.ImageDraw, y: int = 54):
    draw.text((60, y), "9:41", font=f_ui(28), fill=OFFWHITE)
    draw.text((W - 200, y), "●●●●  100%", font=f_ui(22), fill=OFFWHITE)


def load_tiger_logo(size: int = 360) -> Image.Image:
    """Load paper-cut tiger and place on dark circular badge."""
    src = Image.open(ASSETS / "image-005d97bb-05ea-4575-a51c-69d84b9acfcf.png").convert("RGBA")
    # Make white background transparent so red cutout sits cleanly
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if r > 240 and g > 240 and b > 240:
                px[x, y] = (0, 0, 0, 0)
    src = src.resize((size - 40, size - 40), Image.Resampling.LANCZOS)

    badge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.ellipse([2, 2, size - 3, size - 3], fill=(20, 8, 8, 255), outline=GOLD + (255,), width=5)
    d.ellipse([14, 14, size - 15, size - 15], outline=TIGER_RED + (200,), width=2)
    ox = (size - src.width) // 2
    oy = (size - src.height) // 2
    badge.paste(src, (ox, oy), src)
    return badge


def vertical_fade(height: int, top_a: int, bot_a: int, color=MATTE) -> Image.Image:
    overlay = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(height):
        t = i / max(1, height - 1)
        a = int(top_a + (bot_a - top_a) * t)
        od.line([(0, i), (W, i)], fill=color + (a,))
    return overlay


# ── Photos ──────────────────────────────────────────────────────────
photo_bar = Image.open(ASSETS / "frankie-cordoba-ghQjlrXlXeY-unsplash.jpg").convert("RGB")
photo_porch = Image.open(ASSETS / "jonas-jaeken-WY1AqSH4dUQ-unsplash.jpg").convert("RGB")
photo_neon = Image.open(ASSETS / "aleksandr-popov-fa5QQ63u5W4-unsplash.jpg").convert("RGB")
photo_crowd = Image.open(ASSETS / "pim-myten-m41k1lTzjVM-unsplash.jpg").convert("RGB")
collage = Image.open(ASSETS / "image-cf922476-f054-4f17-8543-82eca97743ef.png").convert("RGB")
emblem = load_tiger_logo(340)


def shot_welcome() -> Image.Image:
    bg = darken(grade_red(cover_crop(photo_porch, W, H, (0.5, 0.4)), 0.22), 0.62)
    canvas = bg.convert("RGBA")
    top = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    for i in range(900):
        td.line([(0, i), (W, i)], fill=(80, 0, 0, int(90 * (1 - i / 900))))
    bottom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bottom)
    for i in range(700):
        bd.line([(0, H - 700 + i), (W, H - 700 + i)], fill=MATTE + (int(200 * (i / 700)),))
    canvas = Image.alpha_composite(Image.alpha_composite(canvas, top), bottom)
    d = ImageDraw.Draw(canvas)
    draw_status_bar(d)

    text_center(d, "BLIND TIGER  ·  CLUB DISTRICT", 160, f_sans_bold(26), TIGER_RED)
    # CJK + Latin eyebrow (separate fonts so glyphs render)
    eyebrow_cjk = "私人会所"
    eyebrow_lat = "  ·  MEMBER PASS"
    fc, fl = f_cjk(24), f_ui(22)
    bc = d.textbbox((0, 0), eyebrow_cjk, font=fc)
    bl = d.textbbox((0, 0), eyebrow_lat, font=fl)
    total_w = (bc[2] - bc[0]) + (bl[2] - bl[0])
    ex0 = (W - total_w) // 2
    d.text((ex0, 210), eyebrow_cjk, font=fc, fill=GOLD_DIM)
    d.text((ex0 + (bc[2] - bc[0]), 214), eyebrow_lat, font=fl, fill=GOLD_DIM)
    text_center(d, "Your time", 320, f_display(92), OFFWHITE)
    text_center(d, "starts now.", 430, f_display(92), OFFWHITE)
    text_center(d, "TIME IS YOUR CURRENCY.", 560, f_sans(30), MUTED)

    ex = (W - emblem.width) // 2
    ey = 660
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [ex - 40, ey - 40, ex + emblem.width + 40, ey + emblem.height + 40],
        fill=(184, 146, 74, 55),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.alpha_composite(canvas, glow)
    canvas.paste(emblem, (ex, ey), emblem)
    d = ImageDraw.Draw(canvas)

    strip_y = 1100
    strip = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(strip)
    sd.rounded_rectangle(
        [80, strip_y, W - 80, strip_y + 130],
        radius=28,
        fill=(20, 20, 20, 220),
        outline=(212, 37, 43, 100),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, strip)
    d = ImageDraw.Draw(canvas)
    d.text((120, strip_y + 28), "LIVE  ·  2h 00m", font=f_sans_bold(34), fill=GREEN)
    d.text((120, strip_y + 78), "WALLET READY", font=f_ui(24), fill=MUTED)
    d.text((W - 280, strip_y + 48), "ENTER", font=f_sans_bold(32), fill=TIGER_RED)

    # How it works beats — three equal cards with margin
    beats = [("DESK", "Cash loads time"), ("DOOR", "QR unlocks entry"), ("LOUNGE", "Timer runs live")]
    by = 1360
    gap, side = 20, 64
    card_w = (W - side * 2 - gap * 2) // 3
    for i, (title, sub) in enumerate(beats):
        x0 = side + i * (card_w + gap)
        card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        cd.rounded_rectangle(
            [x0, by, x0 + card_w, by + 210],
            radius=18,
            fill=(22, 22, 22, 220),
            outline=(60, 30, 30, 180),
            width=1,
        )
        canvas = Image.alpha_composite(canvas, card)
        d = ImageDraw.Draw(canvas)
        d.text((x0 + 24, by + 36), f"0{i + 1}", font=f_sans_bold(22), fill=TIGER_RED)
        d.text((x0 + 24, by + 80), title, font=f_sans_bold(28), fill=OFFWHITE)
        d.text((x0 + 24, by + 130), sub, font=f_ui(20), fill=MUTED)

    cta_y = 2450
    cta = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cta)
    cd.rounded_rectangle([100, cta_y, W - 100, cta_y + 110], radius=18, fill=TIGER_RED + (255,))
    canvas = Image.alpha_composite(canvas, cta)
    d = ImageDraw.Draw(canvas)
    text_center(d, "CREATE MEMBER ACCOUNT", cta_y + 32, f_sans_bold(32), OFFWHITE)
    text_center(d, "Age 21+  ·  member pass required", cta_y + 130, f_ui(24), MUTED)
    return canvas.convert("RGB")


def shot_packages() -> Image.Image:
    bg = darken(grade_red(cover_crop(photo_bar, W, H, (0.5, 0.35)), 0.15), 0.78)
    canvas = bg.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(H):
        a = int(40 + 40 * math.sin(i / 80))
        od.line([(0, i), (W, i)], fill=(14, 14, 14, min(180, a)))
    canvas = Image.alpha_composite(canvas, overlay)
    d = ImageDraw.Draw(canvas)
    draw_status_bar(d)

    d.text((72, 140), "BLIND TIGER", font=f_sans_bold(26), fill=TIGER_RED)
    d.text((72, 190), "TIME IS YOUR CURRENCY", font=f_display(48), fill=OFFWHITE)
    d.text(
        (72, 270),
        "Choose a package at the desk.\nMinutes and drinks credit to your phone.",
        font=f_ui(28),
        fill=MUTED,
    )

    packages = [
        ("Quick Escape", "PHP 699", "90 min", "2 drinks", "After-work crowd", False),
        ("Standard Night", "PHP 999", "180 min", "4 drinks", "Most guests", True),
        ("After Hours", "PHP 1,299", "240 min", "5 drinks", "Late-night / weekend", False),
        ("Unlimited", "PHP 1,799", "Until closing", "Unlimited*", "VIP / Members", False),
    ]

    y = 420
    card_h = 300
    for name, price, dur, drinks, guest, popular in packages:
        card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        border = TIGER_RED if popular else (60, 40, 40)
        fill = (28, 14, 14, 235) if popular else (22, 22, 22, 220)
        cd.rounded_rectangle(
            [64, y, W - 64, y + card_h - 28],
            radius=22,
            fill=fill,
            outline=border + ((255,) if popular else (160,)),
            width=3 if popular else 1,
        )
        canvas = Image.alpha_composite(canvas, card)
        d = ImageDraw.Draw(canvas)
        if popular:
            d.text((96, y + 28), "MOST POPULAR", font=f_sans_bold(20), fill=TIGER_RED)
            ny = y + 58
        else:
            ny = y + 40
        d.text((96, ny), name, font=f_sans_bold(40), fill=OFFWHITE)
        bbox = d.textbbox((0, 0), price, font=f_display(40))
        pw = bbox[2] - bbox[0]
        d.text((W - 96 - pw, ny), price, font=f_display(40), fill=GOLD)
        d.text((96, ny + 70), f"{dur}  ·  {drinks}", font=f_ui(28), fill=MUTED)
        d.text((96, ny + 120), guest, font=f_ui(24), fill=(120, 120, 120))
        if popular:
            d.rounded_rectangle(
                [W - 320, y + card_h - 110, W - 96, y + card_h - 52],
                radius=12,
                fill=TIGER_RED,
            )
            d.text((W - 290, y + card_h - 98), "SELECT", font=f_sans_bold(24), fill=OFFWHITE)
        y += card_h

    d.text((72, H - 160), "Cash at the desk → wallet updates live.", font=f_ui(26), fill=MUTED)
    return canvas.convert("RGB")


def shot_lounge() -> Image.Image:
    bg = darken(grade_red(cover_crop(photo_crowd, W, H, (0.55, 0.4)), 0.2), 0.7)
    canvas = bg.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(H):
        a = int(30 + (i / H) * 160)
        od.line([(0, i), (W, i)], fill=MATTE + (min(220, a),))
    for i in range(500):
        od.line([(0, i), (W, i)], fill=(60, 0, 0, int(70 * (1 - i / 500))))
    canvas = Image.alpha_composite(canvas, overlay)
    d = ImageDraw.Draw(canvas)
    draw_status_bar(d)

    d.text((72, 130), "INSIDE  ·  CLUB DISTRICT", font=f_sans_bold(24), fill=TIGER_RED)
    d.text((72, 180), "Your night is live.", font=f_display(56), fill=OFFWHITE)

    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle(
        [64, 320, W - 64, 920],
        radius=28,
        fill=(18, 18, 18, 240),
        outline=GREEN + (180,),
        width=3,
    )
    canvas = Image.alpha_composite(canvas, card)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([W // 2 - 220, 420, W // 2 + 220, 860], fill=(46, 204, 113, 40))
    glow = glow.filter(ImageFilter.GaussianBlur(50))
    canvas = Image.alpha_composite(canvas, glow)
    d = ImageDraw.Draw(canvas)

    text_center(d, "PLENTY", 360, f_sans_bold(26), GREEN)
    text_center(d, "2:14:32", 430, f_display(120), GREEN)
    text_center(d, "remaining on your pass", 600, f_ui(28), MUTED)

    bands = [(GREEN, 0.55), (YELLOW, 0.3), (TIGER_RED, 0.15)]
    bx, by, bw, bh = 140, 700, W - 280, 28
    x = bx
    for color, frac in bands:
        wseg = int(bw * frac)
        d.rounded_rectangle([x, by, x + wseg - 6, by + bh], radius=8, fill=color)
        x += wseg
    d.text((140, 760), "Standard Night  ·  4 drinks left", font=f_ui(26), fill=MUTED)
    d.text(
        (140, 820),
        "Green = open night  ·  Yellow = steady  ·  Red = extend",
        font=f_ui(22),
        fill=(100, 100, 100),
    )

    actions = [
        ("Order a pour", "Spend minutes"),
        ("Pass the Glass", "Share time"),
        ("VIP Rooms", "Unlock access"),
        ("Night Hub", "Friends & safety"),
    ]
    y = 1000
    for i, (title, sub) in enumerate(actions):
        col = i % 2
        row = i // 2
        tw = (W - 128 - 24) // 2
        x0 = 64 + col * (tw + 24)
        y0 = y + row * 220
        tile = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        td.rounded_rectangle(
            [x0, y0, x0 + tw, y0 + 190],
            radius=20,
            fill=(26, 26, 26, 230),
            outline=(60, 30, 30, 200),
            width=1,
        )
        canvas = Image.alpha_composite(canvas, tile)
        d = ImageDraw.Draw(canvas)
        d.text((x0 + 36, y0 + 50), title, font=f_sans_bold(32), fill=OFFWHITE)
        d.text((x0 + 36, y0 + 110), sub, font=f_ui(24), fill=MUTED)

    bar = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    bd.rectangle([0, H - 160, W, H], fill=(10, 10, 10, 245))
    bd.line([(0, H - 160), (W, H - 160)], fill=TIGER_RED + (120,), width=2)
    canvas = Image.alpha_composite(canvas, bar)
    d = ImageDraw.Draw(canvas)
    tabs = ["Lounge", "Menu", "Social", "Pass"]
    for i, t in enumerate(tabs):
        x = 100 + i * 280
        color = TIGER_RED if i == 0 else MUTED
        d.text((x, H - 100), t, font=f_sans_bold(26), fill=color)

    return canvas.convert("RGB")


def shot_vip() -> Image.Image:
    bg = darken(grade_red(cover_crop(collage, W, H, (0.75, 0.85)), 0.25), 0.55)
    canvas = bg.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(600):
        od.line([(0, i), (W, i)], fill=(14, 8, 8, int(180 * (1 - i / 600))))
    for i in range(900):
        od.line([(0, H - 900 + i), (W, H - 900 + i)], fill=(14, 8, 8, int(40 + i / 900 * 200)))
    canvas = Image.alpha_composite(canvas, overlay)
    d = ImageDraw.Draw(canvas)
    draw_status_bar(d)

    d.text((72, 140), "SPEND YOUR TIME", font=f_sans_bold(24), fill=GOLD)
    d.text((72, 190), "VIP & hidden\nexperiences", font=f_display(64), fill=OFFWHITE)
    d.text(
        (72, 380),
        "Minutes unlock rooms, booths,\nand members-only moments.",
        font=f_ui(30),
        fill=MUTED,
    )

    experiences = [
        ("VIP Lounge", "30 min", "Private lounge access"),
        ("VVIP Room", "60 min", "Top-tier private room"),
        ("Secret Room", "45 min", "Members-only room"),
        ("Private Booth", "30 min", "Reserved booth time"),
        ("DJ Meet & Greet", "15 min", "Meet the booth"),
    ]

    y = 540
    for name, cost, desc in experiences:
        card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(card)
        cd.rounded_rectangle(
            [64, y, W - 64, y + 170],
            radius=20,
            fill=(18, 12, 12, 230),
            outline=(184, 146, 74, 90),
            width=1,
        )
        canvas = Image.alpha_composite(canvas, card)
        d = ImageDraw.Draw(canvas)
        d.text((100, y + 36), name, font=f_sans_bold(36), fill=OFFWHITE)
        d.text((100, y + 96), desc, font=f_ui(26), fill=MUTED)
        d.rounded_rectangle([W - 300, y + 55, W - 100, y + 115], radius=14, fill=(40, 20, 20))
        d.text((W - 270, y + 68), cost, font=f_sans_bold(28), fill=GOLD)
        y += 190

    foot = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(foot)
    fd.rounded_rectangle([64, H - 280, W - 64, H - 120], radius=22, fill=(212, 37, 43, 230))
    canvas = Image.alpha_composite(canvas, foot)
    d = ImageDraw.Draw(canvas)
    text_center(d, "Wallet  ·  2h 14m remaining", H - 240, f_sans_bold(32), OFFWHITE)
    text_center(d, "Spend minutes. Keep the night moving.", H - 185, f_ui(24), (255, 200, 200))
    return canvas.convert("RGB")


def shot_pass_glass() -> Image.Image:
    bg = darken(grade_red(cover_crop(photo_neon, W, H, (0.5, 0.45)), 0.18), 0.68)
    canvas = bg.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(H):
        od.line([(0, i), (W, i)], fill=(10, 10, 10, 100))
    for i in range(500):
        od.line([(0, i), (W, i)], fill=(14, 14, 14, int(160 * (1 - i / 500))))
    canvas = Image.alpha_composite(canvas, overlay)
    d = ImageDraw.Draw(canvas)
    draw_status_bar(d)

    d.text((72, 140), "SOCIAL PLAY", font=f_sans_bold(24), fill=GREEN)
    d.text((72, 190), "Pass the Glass", font=f_display(64), fill=OFFWHITE)
    d.text((72, 300), "Guest to guest.\nShare minutes. Toast the night.", font=f_ui(32), fill=MUTED)

    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle(
        [64, 480, W - 64, 1280],
        radius=28,
        fill=(18, 18, 18, 245),
        outline=(46, 204, 113, 120),
        width=2,
    )
    canvas = Image.alpha_composite(canvas, card)
    d = ImageDraw.Draw(canvas)

    text_center(d, "SEND TIME", 540, f_sans_bold(24), MUTED)
    text_center(d, "15 min", 620, f_display(100), GREEN)
    text_center(d, "to a friend inside", 780, f_ui(28), MUTED)

    names = ["Maya", "You", "Kai"]
    colors = [(180, 60, 60), TIGER_RED, (60, 100, 80)]
    positions = [280, W // 2, W - 280]
    for name, col, cx in zip(names, colors, positions):
        r = 70
        d.ellipse([cx - r, 900 - r, cx + r, 900 + r], fill=col, outline=OFFWHITE, width=3)
        ini = name[0]
        bbox = d.textbbox((0, 0), ini, font=f_sans_bold(48))
        tw = bbox[2] - bbox[0]
        d.text((cx - tw // 2, 870), ini, font=f_sans_bold(48), fill=OFFWHITE)
        bbox = d.textbbox((0, 0), name, font=f_ui(26))
        tw = bbox[2] - bbox[0]
        d.text((cx - tw // 2, 990), name, font=f_ui(26), fill=MUTED if name != "You" else OFFWHITE)

    d.text((420, 880), "→", font=f_display(48), fill=GREEN)
    d.text((W - 480, 880), "←", font=f_display(48), fill=GOLD_DIM)
    d.text(
        (120, 1100),
        "Nearby friends can accept a toast.\nMinutes move instantly — timer stays honest.",
        font=f_ui(26),
        fill=MUTED,
    )

    cta = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cta)
    cd.rounded_rectangle([140, 1400, W - 140, 1520], radius=18, fill=GREEN + (255,))
    canvas = Image.alpha_composite(canvas, cta)
    d = ImageDraw.Draw(canvas)
    text_center(d, "PASS 15 MINUTES", 1430, f_sans_bold(34), MATTE)

    sum_card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sum_card)
    sd.rounded_rectangle(
        [64, 1700, W - 64, 2300],
        radius=24,
        fill=(22, 22, 22, 235),
        outline=(60, 40, 40, 180),
        width=1,
    )
    canvas = Image.alpha_composite(canvas, sum_card)
    d = ImageDraw.Draw(canvas)
    d.text((110, 1760), "END OF NIGHT", font=f_sans_bold(22), fill=TIGER_RED)
    d.text((110, 1820), "Tonight's summary", font=f_display(44), fill=OFFWHITE)
    rows = [
        ("Time spent", "3h 12m"),
        ("Drinks ordered", "4"),
        ("Time passed", "15 min"),
        ("VIP moments", "1"),
    ]
    yy = 1940
    for label, val in rows:
        d.text((110, yy), label, font=f_ui(28), fill=MUTED)
        bbox = d.textbbox((0, 0), val, font=f_sans_bold(28))
        tw = bbox[2] - bbox[0]
        d.text((W - 110 - tw, yy), val, font=f_sans_bold(28), fill=OFFWHITE)
        yy += 70

    return canvas.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    shots = [
        ("01-welcome.png", shot_welcome),
        ("02-packages.png", shot_packages),
        ("03-lounge-timer.png", shot_lounge),
        ("04-vip-spend.png", shot_vip),
        ("05-pass-the-glass.png", shot_pass_glass),
    ]
    for name, fn in shots:
        print(f"Generating {name}...")
        im = fn()
        assert im.size == (W, H), im.size
        path = OUT / name
        im.save(path, "PNG", optimize=True)
        print(f"  saved {path} ({im.size[0]}x{im.size[1]})")

    (OUT / "README.md").write_text(
        f"""# App Store screenshots — iPhone 6.5\" Display

**Size used:** {W} × {H} px (portrait)  
Accepted by App Store Connect for **iPhone 6.5\" Display** (also accepts 1242 × 2688).

## Files

| File | Scene |
|------|--------|
| `01-welcome.png` | Brand / member pass welcome |
| `02-packages.png` | Time packages & pricing |
| `03-lounge-timer.png` | Inside club live timer |
| `04-vip-spend.png` | VIP rooms & spend minutes |
| `05-pass-the-glass.png` | Pass the Glass + night summary |

## Upload (App Store Connect)

1. Open your app → **App Store** tab → select the iOS version.
2. Scroll to **Previews and Screenshots** → **iPhone 6.5\" Display**.
3. Drag these five PNGs in order (welcome first).
4. Portrait orientation; do not resize — they are already {W}×{H}.
5. Optional: use the same set for other sizes if ASC offers to use 6.5\" screenshots elsewhere.

Brand: tiger red `#D4252B`, matte black, antique gold. Marketing frames composed from club photography + product copy.

Regenerate: `python3 docs/app-store/screenshots/generate_iphone_65.py`
""",
        encoding="utf-8",
    )
    print("Done.")


if __name__ == "__main__":
    main()

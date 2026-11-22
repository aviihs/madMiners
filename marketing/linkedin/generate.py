"""LinkedIn carousel for Mad Miners: 4 slides, 1080x1350.

Run from the repo root:  python3 marketing/linkedin/generate.py . marketing/linkedin
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

ROOT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1080, 1350
BG = (18, 14, 31)
SURFACE = (30, 24, 50)
GOLD = (255, 194, 51)
GOLD_LIGHT = (255, 222, 115)
TEXT = (246, 242, 255)
MUTED = (165, 156, 194)
LINE = (60, 50, 92)

FONTS = ROOT / "app/assets/fonts"
def lilita(size): return ImageFont.truetype(str(FONTS / "LilitaOne-Regular.ttf"), size)
def nunito(size, weight="Bold"): return ImageFont.truetype(str(FONTS / f"Nunito-{weight}.ttf"), size)

ART = ROOT / "app/assets/images/loading"
SHOTS = ROOT / "website/public/screenshots"
ICON = ROOT / "app/branding/icon_framed.png"


def base():
    """Dark cave backdrop from the splash art, blurred and darkened."""
    bd = Image.open(ART / "backdrop.webp").convert("RGB")
    s = max(W / bd.width, H / bd.height)
    bd = bd.resize((int(bd.width * s) + 1, int(bd.height * s) + 1), Image.LANCZOS)
    x, y = (bd.width - W) // 2, (bd.height - H) // 2
    bd = bd.crop((x, y, x + W, y + H)).filter(ImageFilter.GaussianBlur(6))
    bd = ImageEnhance.Brightness(bd).enhance(0.55)
    # vignette
    vig = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(vig)
    for i in range(60):
        d.rectangle([i * 6, i * 7, W - i * 6, H - i * 7], outline=int(255 * (1 - i / 60) ** 2 * 0.0 + i * 4))
    vig = vig.filter(ImageFilter.GaussianBlur(80))
    dark = Image.new("RGB", (W, H), BG)
    return Image.composite(bd, dark, vig).convert("RGBA")


def paste_fit(img, art, box):
    """Paste RGBA art scaled to fit inside box (x0,y0,x1,y1), centred."""
    x0, y0, x1, y1 = box
    s = min((x1 - x0) / art.width, (y1 - y0) / art.height)
    a = art.resize((int(art.width * s), int(art.height * s)), Image.LANCZOS)
    img.alpha_composite(a, (x0 + (x1 - x0 - a.width) // 2, y0 + (y1 - y0 - a.height) // 2))
    return a.size


def text_center(d, y, txt, font, fill):
    w = d.textlength(txt, font=font)
    d.text(((W - w) / 2, y), txt, font=font, fill=fill)


def wrap(d, txt, font, width):
    words, lines, cur = txt.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def rounded(img, radius):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(m)
    return out


def shot_card(path, width, radius=28, border=4):
    sh = Image.open(path).convert("RGB")
    h = int(sh.height * width / sh.width)
    sh = rounded(sh.resize((width, h), Image.LANCZOS), radius)
    card = Image.new("RGBA", (width + border * 2, h + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([0, 0, card.width - 1, card.height - 1], radius=radius + border, fill=GOLD + (255,))
    card.alpha_composite(sh, (border, border))
    shadow = Image.new("RGBA", (card.width + 80, card.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 52, card.width + 40, card.height + 52], radius=radius, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    shadow.alpha_composite(card, (40, 40))
    return shadow


def pill(d, x, y, txt, font, fg=BG, bg=GOLD, padx=22, pady=10):
    w = d.textlength(txt, font=font)
    bb = font.getbbox(txt)
    h = bb[3] - bb[1]
    d.rounded_rectangle([x, y, x + w + padx * 2, y + h + pady * 2 + 6], radius=99, fill=bg)
    d.text((x + padx, y + pady - bb[1] + 3), txt, font=font, fill=fg)
    return w + padx * 2


def footer(d, n):
    f = nunito(26, "Bold")
    d.text((64, H - 78), "Mad Miners · Dig & Treasure", font=f, fill=MUTED)
    t = f"{n} / 4"
    d.text((W - 64 - d.textlength(t, font=f), H - 78), t, font=f, fill=MUTED)


# ---- 1. Cover --------------------------------------------------------------
def slide_cover():
    img = base()
    d = ImageDraw.Draw(img)
    pill(d, 64, 70, "SIDE PROJECT · NOW ON ANDROID", nunito(26, "ExtraBold"))
    paste_fit(img, Image.open(ART / "title.webp").convert("RGBA"), (60, 150, W - 60, 520))
    paste_fit(img, Image.open(ART / "hero.webp").convert("RGBA"), (40, 500, W - 40, 1110))
    d = ImageDraw.Draw(img)
    text_center(d, 1120, "I built a real-time multiplayer", nunito(46, "Black"), TEXT)
    text_center(d, 1176, "mining game, solo.", nunito(46, "Black"), GOLD)
    footer(d, 1)
    return img


# ---- 2. Gameplay -----------------------------------------------------------
def slide_gameplay():
    img = base()
    d = ImageDraw.Draw(img)
    d.text((64, 80), "Dig. Dodge.", font=lilita(92), fill=TEXT)
    d.text((64, 180), "Find the treasure first.", font=lilita(92), fill=GOLD)
    card = shot_card(SHOTS / "deep-mine.jpg", 952)
    img.alpha_composite(card, ((W - card.width) // 2, 300))
    d = ImageDraw.Draw(img)
    points = [
        ("12", "miners race in the same mine, live"),
        ("6", "underground zones, from dirt to lava"),
        ("0", "ads. No pay-to-win. Cosmetics only"),
    ]
    y = 920
    for big, small in points:
        d.text((80, y - 6), big, font=lilita(72), fill=GOLD)
        d.text((230, y + 14), small, font=nunito(38, "Bold"), fill=TEXT)
        y += 112
    footer(d, 2)
    return img


# ---- 3. Under the hood -----------------------------------------------------
def slide_stack():
    img = Image.new("RGBA", (W, H), BG + (255,))
    d = ImageDraw.Draw(img)
    d.text((64, 80), "Under the hood", font=lilita(92), fill=TEXT)
    d.text((64, 190), "One set of game rules, shared by the app and the server.", font=nunito(34, "SemiBold"), fill=MUTED)

    def block(x, y, w, h, title, sub, accent=False):
        d.rounded_rectangle([x, y, x + w, y + h], radius=26, fill=(42, 33, 70) if accent else SURFACE,
                            outline=GOLD if accent else LINE, width=3)
        d.text((x + 28, y + 24), title, font=nunito(36, "Black"), fill=GOLD if accent else TEXT)
        for i, line in enumerate(wrap(d, sub, nunito(27, "SemiBold"), w - 56)):
            d.text((x + 28, y + 76 + i * 36), line, font=nunito(27, "SemiBold"), fill=MUTED)

    def arrow(x, y0, y1, label=None):
        d.line([x, y0, x, y1 - 14], fill=GOLD, width=5)
        d.polygon([(x - 13, y1 - 18), (x + 13, y1 - 18), (x, y1)], fill=GOLD)
        if label:
            d.text((x + 20, (y0 + y1) / 2 - 18), label, font=nunito(26, "ExtraBold"), fill=GOLD_LIGHT)

    block(64, 280, 952, 170, "Flutter + Flame app", "Android client. 60 fps rendering, offline bots in a background isolate.")
    arrow(W // 2, 460, 560, "WebSocket (wss) · REST")
    block(64, 570, 952, 170, "Dart game server", "Authoritative: every dig, blast and reward is decided on the server, so no cheating.")
    arrow(W // 2, 750, 850, "SQL")
    block(64, 860, 952, 150, "PostgreSQL", "Accounts, stats, match history, daily rewards. Hosted on Render.")
    block(64, 1040, 952, 160, "mad_miners_core (shared Dart package)", "Physics, maps, TNT, bots, protocol. Same code on phone and server.", accent=True)
    footer(d, 3)
    return img


# ---- 4. Call to action -----------------------------------------------------
def slide_cta():
    img = base()
    d = ImageDraw.Draw(img)
    a = shot_card(SHOTS / "match-lobby.jpg", 700, radius=24)
    b = shot_card(SHOTS / "surface-shop.jpg", 700, radius=24)
    img.alpha_composite(a, (-30, 40))
    img.alpha_composite(b, (W - b.width + 30, 290))
    icon = rounded(Image.open(ICON).convert("RGB").resize((220, 220), Image.LANCZOS), 50)
    img.alpha_composite(icon, ((W - 220) // 2, 790))
    d = ImageDraw.Draw(img)
    text_center(d, 1010, "Free on Google Play", lilita(84), TEXT)
    text_center(d, 1110, "Search “Mad Miners” · link in the post", nunito(36, "Bold"), GOLD)
    text_center(d, 1170, "Feedback welcome, I read every message.", nunito(32, "SemiBold"), MUTED)
    footer(d, 4)
    return img


slides = [slide_cover(), slide_gameplay(), slide_stack(), slide_cta()]
for i, s in enumerate(slides, 1):
    s.convert("RGB").save(OUT / f"slide-{i}.png", optimize=True)
# LinkedIn takes a PDF as a swipeable "document" carousel.
rgb = [s.convert("RGB") for s in slides]
rgb[0].save(OUT / "mad-miners-carousel.pdf", save_all=True, append_images=rgb[1:], resolution=150)
print("done")

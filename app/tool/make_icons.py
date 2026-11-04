"""Draws the app's launcher and web icons from the website's logo (site/logo/icon.svg: a gold rugby
ball on navy). Run from app/:  python tool/make_icons.py   (needs Pillow)."""

from pathlib import Path

from PIL import Image, ImageDraw

NAVY, GOLD = (16, 33, 58, 255), (201, 162, 75, 255)
SEAM = (16, 33, 58, 255)
EDGE = (16, 33, 58, 90)  # the ball's outline, navy at 35%
HERE = Path(__file__).resolve().parent.parent


def ball(size: int, scale: float) -> Image.Image:
    """The ball on a transparent square, drawn on the logo's 64-unit grid. scale 1 = as in the logo."""
    k = 8  # draw large, then shrink, for smooth edges
    s = size * k
    u = s / 64 * scale
    c = s / 2
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([c - 25 * u, c - 15 * u, c + 25 * u, c + 15 * u], fill=GOLD, outline=EDGE, width=round(2.5 * u))
    d.line([c - 12 * u, c, c + 12 * u, c], fill=SEAM, width=round(3 * u))
    for r in (c - 12 * u, c + 12 * u):  # round ends of the seam
        d.ellipse([r - 1.5 * u, c - 1.5 * u, r + 1.5 * u, c + 1.5 * u], fill=SEAM)
    for x in (25, 30, 35, 40):
        x = c + (x - 32) * u
        d.line([x, c - 3.5 * u, x, c + 3.5 * u], fill=SEAM, width=round(2.4 * u))
        for y in (c - 3.5 * u, c + 3.5 * u):
            d.ellipse([x - 1.2 * u, y - 1.2 * u, x + 1.2 * u, y + 1.2 * u], fill=SEAM)
    im = im.rotate(35, resample=Image.BICUBIC)  # the logo turns it 35 degrees anticlockwise
    return im.resize((size, size), Image.LANCZOS)


def icon(size: int, *, rounded: bool, scale: float = 1.0) -> Image.Image:
    k = 8
    bg = Image.new("RGBA", (size * k, size * k), (0, 0, 0, 0))
    ImageDraw.Draw(bg).rounded_rectangle([0, 0, size * k - 1, size * k - 1], radius=(14 / 64 * size * k) if rounded else 0, fill=NAVY)
    bg = bg.resize((size, size), Image.LANCZOS)
    bg.alpha_composite(ball(size, scale))
    return bg


def save(im: Image.Image, rel: str) -> None:
    p = HERE / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)


if __name__ == "__main__":
    res = "android/app/src/main/res"
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(icon(px, rounded=True), f"{res}/mipmap-{name}/ic_launcher.png")
        # Android 8+ adaptive icon: 108dp layers; the launcher shows the middle 72dp, so the ball is shrunk to fit.
        a = round(px * 108 / 48)
        save(ball(a, 0.62), f"{res}/mipmap-{name}/ic_launcher_foreground.png")
    save(icon(32, rounded=True), "web/favicon.png")
    for px in (192, 512):
        save(icon(px, rounded=True), f"web/icons/Icon-{px}.png")
        save(icon(px, rounded=False, scale=0.8), f"web/icons/Icon-maskable-{px}.png")
    print("Icons written")

"""Draws the app's launcher and web icons and its Google Play graphics (store/) from the website's
logo (site/logo/icon.svg: a gold rugby ball on navy). Run from app/:  python tool/make_icons.py
(needs Pillow). The Play phone screenshots come from tool/store_screenshots_test.dart instead."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

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
    d.ellipse([c - 25 * u, c - 15 * u, c + 25 * u, c + 15 * u], fill=GOLD)
    # The logo's darker rim: a see-through navy stroke centred on the ball's edge, laid over the gold (and the
    # background) rather than replacing it, as the SVG does. Drawing it with outline= would punch a hole instead.
    rim = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    h = 1.25 * u
    ImageDraw.Draw(rim).ellipse([c - 25 * u - h, c - 15 * u - h, c + 25 * u + h, c + 15 * u + h], outline=EDGE, width=round(2.5 * u))
    im.alpha_composite(rim)
    d = ImageDraw.Draw(im)
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


def feature_graphic() -> Image.Image:
    w, h = 1024, 500
    im = Image.new("RGBA", (w, h), (14, 27, 48, 255))
    lines = Image.new("RGBA", (w, h), (0, 0, 0, 0))  # a faint halfway line and 22, as on the website
    for x, a in ((w * 0.72, 60), (w * 0.94, 34)):
        ImageDraw.Draw(lines).line([x, 0, x, h], fill=(201, 162, 75, a), width=3)
    im.alpha_composite(lines)
    d = ImageDraw.Draw(im)
    b = ball(420, 1.25)
    im.alpha_composite(b, (int(w * 0.72) - 210, 40))
    fonts = HERE / "assets/fonts"
    title = ImageFont.truetype(str(fonts / "Poppins-ExtraBold.ttf"), 70)
    line = ImageFont.truetype(str(fonts / "Figtree-SemiBold.ttf"), 31)
    d.text((64, 128), "RugbyAnalysis", font=title, fill=(244, 239, 228, 255))
    d.text((66, 232), "Every Test with the model's pick.", font=line, fill=(244, 239, 228, 255))
    d.text((66, 276), "Rugby World Cup 2027 predictions.", font=line, fill=(201, 162, 75, 255))
    d.text((66, 320), "A heads-up when your team plays.", font=line, fill=(169, 179, 196, 255))
    return im.convert("RGB")


def save(im: Image.Image, rel: str) -> None:
    p = HERE / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)


if __name__ == "__main__":
    res = "android/app/src/main/res"
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(icon(px, rounded=True), f"{res}/mipmap-{name}/ic_launcher.png")
        # Android 8+ adaptive icon: 108dp layers; the launcher shows the middle 72dp and keeps the middle 66dp circle safe, so the ball is shrunk to fit it.
        a = round(px * 108 / 48)
        save(ball(a, 0.7), f"{res}/mipmap-{name}/ic_launcher_foreground.png")
    save(icon(32, rounded=True), "web/favicon.png")
    for px in (192, 512):
        save(icon(px, rounded=True), f"web/icons/Icon-{px}.png")
        save(icon(px, rounded=False, scale=0.8), f"web/icons/Icon-maskable-{px}.png")
    # Google Play: a square 512 icon (Play rounds the corners itself) and the 1024 x 500 feature graphic.
    save(icon(512, rounded=False, scale=0.9).convert("RGB"), "store/play-icon-512.png")
    save(feature_graphic(), "store/feature-graphic-1024x500.png")
    print("Icons written")

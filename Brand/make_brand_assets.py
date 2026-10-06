"""Generates the Sideline symbol SVGs and iOS app icons from the 100-unit grid in the design system PDF.

Symbol: stem 8, hash 22x7, pupil R15, gap 5, built from four rectangles and one circle.
Run: python3 -I Brand/make_brand_assets.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RECTS = [(46, 4, 54, 30), (46, 10, 68, 17), (46, 70, 54, 96), (32, 83, 54, 90)]
PUPIL = (50, 50, 15)  # cx, cy, r

INK, PAPER = "#16181A", "#F2EFE8"
DARK_SURFACE = "#1A1D1B"


def svg_shapes(fill: str, scale: float = 1.0, dx: float = 0.0, dy: float = 0.0) -> str:
    def t(v, d): return round(v * scale + d, 3)
    rects = "".join(
        f'<rect x="{t(x0, dx)}" y="{t(y0, dy)}" width="{round((x1 - x0) * scale, 3)}" '
        f'height="{round((y1 - y0) * scale, 3)}" fill="{fill}"/>'
        for x0, y0, x1, y1 in RECTS
    )
    cx, cy, r = PUPIL
    return rects + f'<circle cx="{t(cx, dx)}" cy="{t(cy, dy)}" r="{round(r * scale, 3)}" fill="{fill}"/>'


def write_svgs() -> None:
    brand = ROOT / "Brand"
    head = '<svg xmlns="http://www.w3.org/2000/svg" '
    (brand / "sideline-symbol.svg").write_text(f'{head}viewBox="0 0 100 100">{svg_shapes(INK)}</svg>\n')
    (brand / "sideline-symbol-white.svg").write_text(f'{head}viewBox="0 0 100 100">{svg_shapes("#FFFFFF")}</svg>\n')
    # Full-bleed square, no baked-in corners (iOS applies the mask). Mark height = 62% of the canvas.
    s = 1024 * 0.62 / 92
    off = 512 - 50 * s
    (brand / "sideline-app-icon-1024.svg").write_text(
        f'{head}viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{INK}"/>'
        f'{svg_shapes(PAPER, s, off, off)}</svg>\n'
    )
    # Wordmark is live text until it is outlined for final release.
    (brand / "sideline-lockup.svg").write_text(
        f'{head}viewBox="0 0 440 120"><g transform="translate(6 6) scale(1.08)">{svg_shapes(INK)}</g>'
        f'<text x="128" y="78" font-family="Newsreader, \'New York\', Georgia, serif" font-weight="500" '
        f'font-size="72" letter-spacing="-0.72" fill="{INK}">Sideline</text></svg>\n'
    )


def render_icon(path: Path, bg: str, fg: str) -> None:
    ss, size = 4, 1024
    img = Image.new("RGB", (size * ss, size * ss), bg)
    d = ImageDraw.Draw(img)
    s = size * ss * 0.62 / 92
    off = size * ss / 2 - 50 * s
    for x0, y0, x1, y1 in RECTS:
        d.rectangle([off + x0 * s, off + y0 * s, off + x1 * s - 1, off + y1 * s - 1], fill=fg)
    cx, cy, r = PUPIL
    d.ellipse([off + (cx - r) * s, off + (cy - r) * s, off + (cx + r) * s, off + (cy + r) * s], fill=fg)
    img.resize((size, size), Image.LANCZOS).save(path)


def write_icons() -> None:
    icons = ROOT / "Sideline" / "Assets.xcassets" / "AppIcon.appiconset"
    render_icon(icons / "AppIcon.png", INK, PAPER)
    render_icon(icons / "AppIcon-Dark.png", DARK_SURFACE, PAPER)
    render_icon(icons / "AppIcon-Tinted.png", "#000000", "#FFFFFF")  # grayscale; iOS recolors


if __name__ == "__main__":
    write_svgs()
    write_icons()

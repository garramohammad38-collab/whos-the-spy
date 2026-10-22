#!/usr/bin/env python3
"""Sort UI-test screenshots into locale folders (ar-SA, en-US) as 6.9" iPhone PORTRAIT
(1320x2868) PNGs and refuse broken captures (big black areas / wrong shape)."""
import sys
from pathlib import Path
from PIL import Image

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
TARGET = (1320, 2868)
SHOTS = ["1-home", "3-word", "4-spy", "5-discuss", "6-result", "2-pass", "7-setup"]
LOCALE = {"ar": "ar-SA", "en-US": "en-US"}
EXTRA = ["ar-8-store"]


def black_fraction(im):
    px = list(im.resize((132, 287)).getdata())
    return sum(1 for r, g, b in px if r < 12 and g < 12 and b < 12) / len(px)


def fix(im):
    im = im.convert("RGB")
    w, h = im.size
    if w > h:
        im = im.rotate(-90, expand=True); w, h = im.size
    if abs(w / h - TARGET[0] / TARGET[1]) > 0.03:
        sys.exit(f"wrong aspect ratio {w}x{h}")
    return im if (w, h) == TARGET else im.resize(TARGET, Image.LANCZOS)


errors = []
for lang, locale in (("ar", "ar-SA"), ("en", "en-US")):
    out = dst / locale
    out.mkdir(parents=True, exist_ok=True)
    for i, shot in enumerate(SHOTS, 1):
        p = src / f"{lang}-{shot}.png"
        if not p.exists():
            errors.append(f"missing {p}"); continue
        im = fix(Image.open(p))
        bf = black_fraction(im)
        if bf > 0.15:
            errors.append(f"{p.name}: {bf:.0%} black pixels - broken capture")
        im.save(out / f"{i:02d}_{p.stem}.png")
        print(out / f"{i:02d}_{p.stem}.png", im.size, f"black={bf:.0%}")
extra = dst / "extra"
extra.mkdir(parents=True, exist_ok=True)
for name in EXTRA:
    p = src / f"{name}.png"
    if p.exists():
        fix(Image.open(p)).save(extra / f"{name}.png")
if errors:
    sys.exit("\n".join(errors))

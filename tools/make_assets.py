#!/usr/bin/env python3
"""Generate the binary assets (app icon, launch logo, sound effects) from code.
Run from the project root:  pip3 install pillow && python3 tools/make_assets.py
All artwork and sounds are original and generated here."""
import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "SpyGame" / "Resources"
A = RES / "Assets.xcassets"

INK, RED, WHITE = (20, 20, 20, 255), (230, 57, 70, 255), (255, 255, 255, 255)
LILAC = (185, 166, 255, 255)


def spy(d, cx, cy, u, col, lens):
    """Original spy mark: wide-brim hat + round glasses + collar, centred on (cx, cy), unit u."""
    # hat crown + band + brim
    d.rounded_rectangle([cx - 2.1 * u, cy - 3.6 * u, cx + 2.1 * u, cy - 1.0 * u], int(0.9 * u), fill=col)
    d.rectangle([cx - 2.1 * u, cy - 1.75 * u, cx + 2.1 * u, cy - 1.15 * u], fill=lens)
    d.ellipse([cx - 4.0 * u, cy - 1.45 * u, cx + 4.0 * u, cy - 0.35 * u], fill=col)
    # glasses
    r = 1.05 * u
    for sx in (-1.35, 1.35):
        x = cx + sx * u
        d.ellipse([x - r, cy + 0.15 * u, x + r, cy + 0.15 * u + 2 * r], fill=col)
        d.ellipse([x - r * 0.62, cy + 0.15 * u + r * 0.38, x + r * 0.62, cy + 0.15 * u + r * 1.62], fill=lens)
    d.rectangle([cx - 0.45 * u, cy + 0.85 * u, cx + 0.45 * u, cy + 1.2 * u], fill=col)
    # coat collar
    d.polygon([(cx - 3.2 * u, cy + 4.4 * u), (cx - 1.0 * u, cy + 2.7 * u), (cx, cy + 4.4 * u)], fill=col)
    d.polygon([(cx + 3.2 * u, cy + 4.4 * u), (cx + 1.0 * u, cy + 2.7 * u), (cx, cy + 4.4 * u)], fill=col)


def make_icon():
    S = 2048
    img = Image.new("RGBA", (S, S), LILAC)
    rays = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy, R0, n = S / 2, S / 2, S * 1.5, 18
    for i in range(n):
        a0 = 2 * math.pi * (2 * i) / (2 * n)
        a1 = 2 * math.pi * (2 * i + 1) / (2 * n)
        rd.polygon([(cx, cy), (cx + R0 * math.cos(a0), cy + R0 * math.sin(a0)),
                    (cx + R0 * math.cos(a1), cy + R0 * math.sin(a1))], fill=(255, 255, 255, 55))
    img = Image.alpha_composite(img, rays)

    logo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(logo)
    half, rad, sh, bw = int(S * 0.31), int(S * 0.12), int(S * 0.035), int(S * 0.028)
    box = [S // 2 - half, S // 2 - half, S // 2 + half, S // 2 + half]
    ld.rounded_rectangle([box[0] + sh, box[1] + sh, box[2] + sh, box[3] + sh], rad, fill=INK)
    ld.rounded_rectangle(box, rad, fill=RED, outline=INK, width=bw)
    u = S * 0.062
    spy(ld, S // 2 + int(S * 0.014), S // 2 - int(S * 0.02) + int(S * 0.014), u, INK, INK)
    spy(ld, S // 2, S // 2 - int(S * 0.02), u, WHITE, INK)
    img = Image.alpha_composite(img, logo)

    (A / "AppIcon.appiconset").mkdir(parents=True, exist_ok=True)
    img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(A / "AppIcon.appiconset" / "AppIcon-1024.png")
    crop = logo.crop((box[0] - 20, box[1] - 20, box[2] + sh + 20, box[3] + sh + 20))
    (A / "LaunchLogo.imageset").mkdir(parents=True, exist_ok=True)
    for sc, size in ((1, 160), (2, 320), (3, 480)):
        crop.resize((size, size), Image.LANCZOS).save(A / "LaunchLogo.imageset" / f"LaunchLogo@{sc}x.png")


R = 44100


def write_wav(name, samples):
    out = RES / "Sounds"
    out.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out / f"{name}.wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(R)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def tone(freq, dur, vol=0.5, attack=0.005, decay=6.0):
    out = []
    for i in range(int(R * dur)):
        t = i / R
        f = freq(t) if callable(freq) else freq
        out.append(math.sin(2 * math.pi * f * t) * min(1, t / attack) * math.exp(-decay * t) * vol)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0 for p in parts) for i in range(n)]


def note(f, d, v=0.22):
    return mix(tone(f, d, v, attack=0.01, decay=7), tone(f * 2, d, v * 0.25, attack=0.01, decay=10))


def make_sounds():
    # Card revealed: soft "pop" chime.
    write_wav("reveal", mix(tone(659.25, 0.25, 0.25, attack=0.004, decay=12), tone(1318.5, 0.25, 0.06, decay=16)))
    # Discussion starts: rising C5-E5-G5.
    write_wav("start", note(523.25, 0.12) + note(659.25, 0.12) + note(783.99, 0.35))
    # Last 10 seconds tick.
    write_wav("tick", mix(tone(1600, 0.05, 0.3, attack=0.001, decay=60), tone(800, 0.05, 0.2, attack=0.001, decay=50)))
    # Time's up / voting: soft ta-da.
    write_wav("end", mix(note(783.99, 0.16), note(523.25, 0.16, 0.12))
              + mix(note(1046.5, 0.6, 0.18), note(659.25, 0.6, 0.14), note(523.25, 0.6, 0.12)))
    # Spy caught / correct guess: bright two-note.
    write_wav("win", mix(tone(880, 0.12, 0.4, decay=10), tone(1760, 0.12, 0.12, decay=14))
              + mix(tone(1318.5, 0.4, 0.45, decay=7), tone(2637, 0.4, 0.1, decay=10)))
    # Spy escaped / wrong: gentle descending (no buzzer).
    write_wav("lose", note(659.25, 0.18, 0.2) + note(523.25, 0.18, 0.2) + note(392.0, 0.45, 0.2))
    # Leaving a round (X): calm G5 -> C5.
    write_wav("stop", mix(tone(784, 0.16, 0.22, attack=0.01, decay=9), tone(1568, 0.16, 0.05, attack=0.01, decay=12))
              + mix(tone(523.25, 0.45, 0.22, attack=0.01, decay=5), tone(1046.5, 0.45, 0.05, attack=0.01, decay=8)))


if __name__ == "__main__":
    make_icon()
    make_sounds()
    print("assets generated")

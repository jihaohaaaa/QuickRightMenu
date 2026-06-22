from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import io
import shutil
import struct
import subprocess

root = Path(__file__).resolve().parents[1]
iconset = root / "Resources" / "AppIcon.iconset"
iconset.mkdir(parents=True, exist_ok=True)
icns_path = root / "Resources" / "AppIcon.icns"

for old_file in iconset.glob("*.png"):
    old_file.unlink()

sizes = [16, 32, 128, 256, 512]

def draw_icon(size: int) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = int(210 * scale)

    for y in range(size):
        t = y / max(size - 1, 1)
        x_mix = 0.18
        color = (
            int(52 + 100 * t + 24 * x_mix),
            int(173 - 76 * t),
            int(240 - 12 * t),
            255,
        )
        draw.line([(0, y), (size, y)], fill=color)

    outer_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(outer_mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    image.putalpha(outer_mask)

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([int(-150 * scale), int(-110 * scale), int(590 * scale), int(560 * scale)], fill=(108, 223, 255, 78))
    glow_draw.ellipse([int(360 * scale), int(360 * scale), int(1190 * scale), int(1160 * scale)], fill=(131, 82, 235, 95))
    image.alpha_composite(glow)

    inset = int(150 * scale)
    panel = [inset, inset, size - inset, size - inset]
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(panel, radius=int(150 * scale), fill=(21, 28, 48, 245))
    draw.rounded_rectangle(
        [panel[0] + int(24 * scale), panel[1] + int(24 * scale), panel[2] - int(24 * scale), panel[3] - int(24 * scale)],
        radius=int(126 * scale),
        outline=(255, 255, 255, 25),
        width=max(1, int(5 * scale)),
    )

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", int(485 * scale))
    except Exception:
        font = ImageFont.load_default()
    text = "Q"
    bbox = draw.textbbox((0, 0), text, font=font)
    tx = (size - (bbox[2] - bbox[0])) / 2 - int(7 * scale)
    ty = (size - (bbox[3] - bbox[1])) / 2 - int(70 * scale)
    draw.text((tx, ty), text, fill=(250, 253, 255, 255), font=font)

    badge = int(255 * scale)
    draw.ellipse(
        [size - badge - int(24 * scale), size - badge - int(24 * scale), size + int(78 * scale), size + int(78 * scale)],
        fill=(255, 202, 68, 255),
    )
    draw.ellipse(
        [size - int(170 * scale), size - int(170 * scale), size - int(92 * scale), size - int(92 * scale)],
        fill=(255, 232, 142, 210),
    )
    return image

base = draw_icon(1024)
for size in sizes:
    img = base.resize((size, size), Image.Resampling.LANCZOS)
    img.convert("RGB").save(iconset / f"icon_{size}x{size}.png")
    retina = base.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
    retina.convert("RGB").save(iconset / f"icon_{size}x{size}@2x.png")

if shutil.which("iconutil"):
    result = subprocess.run(
        ["iconutil", "-c", "icns", str(iconset), "-o", str(icns_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode == 0:
        raise SystemExit(0)

chunks = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
]

payload = bytearray()
for chunk_type, size in chunks:
    img = base.resize((size, size), Image.Resampling.LANCZOS)
    png = io.BytesIO()
    img.save(png, format="PNG")
    data = png.getvalue()
    payload.extend(chunk_type.encode("ascii"))
    payload.extend(struct.pack(">I", len(data) + 8))
    payload.extend(data)

icns = bytearray()
icns.extend(b"icns")
icns.extend(struct.pack(">I", len(payload) + 8))
icns.extend(payload)
icns_path.write_bytes(icns)

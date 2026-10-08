#!/usr/bin/env python3
"""Disegna l'icona dell'Ispettore del Check-in (personaggio originale).

Genera:
  notifier/AppIcon.icns     icona dell'app (compare su ogni notifica)
  notifier/inspector.png    immagine allegata alla notifica (con fumetto)
  notifier/art/icon-1024.png anteprima

Uso: python3 notifier/art/draw_icon.py   (richiede Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
S = 4                     # supersampling
W = 1024 * S


def p(*v):                # scala coordinate dal canvas 1024
    return tuple(int(x * S) for x in v)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vertical_gradient(size, top, bottom):
    w, h = size
    g = Image.new("RGBA", (1, h))
    for y in range(h):
        g.putpixel((0, y), lerp(top, bottom, y / max(1, h - 1)))
    return g.resize((w, h))


def squircle_mask(box, radius):
    m = Image.new("L", (W, W), 0)
    ImageDraw.Draw(m).rounded_rectangle(p(*box), radius=radius * S, fill=255)
    return m


def draw_face(img, cx=512, cy=548, r=292):
    d = ImageDraw.Draw(img)

    # ombra morbida sotto la faccia
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(p(cx - r + 10, cy - r + 34, cx + r + 10, cy + r + 34), fill=(0, 0, 40, 110))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(26 * S)))

    # faccia: gradiente caldo
    face = vertical_gradient(p(2 * r, 2 * r), (255, 214, 92, 255), (247, 160, 52, 255))
    fm = Image.new("L", face.size, 0)
    ImageDraw.Draw(fm).ellipse((0, 0, face.size[0] - 1, face.size[1] - 1), fill=255)
    img.paste(face, p(cx - r, cy - r), fm)

    # riflesso
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse(p(cx - 200, cy - 262, cx - 60, cy - 170), fill=(255, 255, 255, 45))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(30 * S)))

    ink = (58, 34, 20, 255)

    # --- occhio sinistro: socchiuso e sospettoso
    lx, ly = cx - 112, cy - 28
    d.ellipse(p(lx - 58, ly - 20, lx + 58, ly + 20), fill=(255, 255, 255, 255), outline=ink, width=9 * S)
    d.ellipse(p(lx + 2, ly - 17, lx + 36, ly + 17), fill=ink)
    # palpebra pesante
    d.chord(p(lx - 64, ly - 46, lx + 64, ly + 10), 180, 360, fill=(236, 150, 46, 255))
    d.line(p(lx - 62, ly - 14, lx + 62, ly - 14), fill=ink, width=10 * S)
    # sopracciglio aggrottato (scende verso il centro)
    d.line(p(lx - 78, ly - 92, lx + 70, ly - 52), fill=ink, width=26 * S)
    d.ellipse(p(lx - 91, ly - 105, lx - 65, ly - 79), fill=ink)
    d.ellipse(p(lx + 57, ly - 65, lx + 83, ly - 39), fill=ink)

    # --- occhio destro: spalancato dietro il monocolo
    rx, ry = cx + 112, cy - 40
    d.ellipse(p(rx - 62, ry - 62, rx + 62, ry + 62), fill=(255, 255, 255, 255), outline=ink, width=9 * S)
    d.ellipse(p(rx - 36, ry - 22, rx + 10, ry + 24), fill=ink)          # pupilla che ti guarda
    d.ellipse(p(rx - 26, ry - 14, rx - 12, ry), fill=(255, 255, 255, 255))
    # sopracciglio alzatissimo
    d.arc(p(rx - 92, ry - 190, rx + 92, ry - 40), 200, 340, fill=ink, width=26 * S)

    # monocolo + catenella
    gold, gold_dark = (255, 205, 64, 255), (176, 120, 20, 255)
    lens = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lens).ellipse(p(rx - 96, ry - 96, rx + 96, ry + 96), fill=(200, 230, 255, 60))
    img.alpha_composite(lens)
    d.ellipse(p(rx - 100, ry - 100, rx + 100, ry + 100), outline=gold_dark, width=22 * S)
    d.ellipse(p(rx - 98, ry - 98, rx + 98, ry + 98), outline=gold, width=14 * S)
    d.arc(p(rx - 84, ry - 84, rx + 84, ry + 84), 200, 250, fill=(255, 255, 255, 200), width=8 * S)
    chain = [(rx + 82, ry + 60), (rx + 118, ry + 130), (rx + 136, ry + 210), (rx + 132, ry + 290)]
    for a, b in zip(chain, chain[1:]):
        d.line(p(*a, *b), fill=gold_dark, width=8 * S)
    for (x, y) in chain[1:]:
        d.ellipse(p(x - 9, y - 9, x + 9, y + 9), fill=gold)

    # --- bocca: smorfia di traverso, "mmh"
    d.line(p(cx - 70, cy + 128, cx + 54, cy + 108), fill=ink, width=18 * S)
    d.ellipse(p(cx - 79, cy + 119, cx - 61, cy + 137), fill=ink)
    d.ellipse(p(cx + 45, cy + 99, cx + 63, cy + 117), fill=ink)
    # baffetto/guancia
    cheek = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(cheek).ellipse(p(cx - 230, cy + 40, cx - 150, cy + 90), fill=(255, 120, 90, 90))
    img.alpha_composite(cheek.filter(ImageFilter.GaussianBlur(10 * S)))


def app_icon():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    # sfondo "squircle" in stile macOS (griglia 824 su 1024)
    box = (100, 100, 924, 924)
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(p(100, 112, 924, 936), radius=186 * S, fill=(0, 0, 0, 90))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14 * S)))
    bg = vertical_gradient((W, W), (70, 96, 238, 255), (30, 40, 140, 255))
    img.paste(bg, (0, 0), squircle_mask(box, 186))

    # punto interrogativo discreto in alto a sinistra
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 210 * S)
    except OSError:
        font = ImageFont.load_default()
    q = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(q).text(p(178, 150), "?", font=font, fill=(255, 255, 255, 90))
    img.alpha_composite(q)

    draw_face(img, cx=520, cy=548, r=280)
    return img.resize((1024, 1024), Image.LANCZOS)


def attachment():
    """Immagine allegata alla notifica: faccia + fumetto 'check-in?' su sfondo trasparente."""
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw_face(img, cx=470, cy=600, r=300)
    d = ImageDraw.Draw(img)
    # fumetto
    d.rounded_rectangle(p(560, 70, 1000, 280), radius=60 * S, fill=(255, 255, 255, 255),
                        outline=(30, 40, 140, 255), width=10 * S)
    d.polygon(p(640, 270, 700, 270, 610, 350), fill=(255, 255, 255, 255))
    d.line(p(640, 276, 610, 350), fill=(30, 40, 140, 255), width=10 * S)
    d.line(p(700, 276, 610, 350), fill=(30, 40, 140, 255), width=10 * S)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72 * S)
    except OSError:
        font = ImageFont.load_default()
    d.text(p(780, 175), "check-in?", font=font, fill=(30, 40, 140, 255), anchor="mm")
    return img.resize((512, 512), Image.LANCZOS)


if __name__ == "__main__":
    icon = app_icon()
    (ROOT / "art").mkdir(exist_ok=True)
    icon.save(ROOT / "art" / "icon-1024.png")
    icon.save(ROOT / "AppIcon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
    attachment().save(ROOT / "inspector.png")
    print("ok")

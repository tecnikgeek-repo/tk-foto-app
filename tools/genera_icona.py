"""Icone di tk-foto nello stile delle app TK: quadrato navy, prodotto bianco dentro la cornice
tratteggiata del ritaglio, bollino verde acqua con le forbici.
Uso: python tools/genera_icona.py (serve Pillow) -> assets/icona.png e assets/icona-adattiva.png,
poi: dart run flutter_launcher_icons"""
import os
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_ICONE = r"C:\dev\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
NAVY, NAVY2, ACCENTO = (15, 23, 42), (30, 41, 59), (13, 148, 136)
BORSA = chr(0xF016F)  # Icons.shopping_bag_rounded
FORBICI = chr(0xF66D)  # Icons.content_cut_rounded
G = 4096


def sfondo(img):
    lato = img.size[0]
    grad = Image.new("RGB", (lato, lato))
    gd = ImageDraw.Draw(grad)
    for i in range(lato):
        t = i / lato
        gd.line([(0, i), (lato, i)], fill=tuple(int(NAVY2[k] + (NAVY[k] - NAVY2[k]) * t) for k in range(3)))
    maschera = Image.new("L", (lato, lato), 0)
    ImageDraw.Draw(maschera).rounded_rectangle([0, 0, lato - 1, lato - 1], radius=int(lato * .24), fill=255)
    img.paste(grad, (0, 0), maschera)


def tratteggio(d, box, raggio, spessore, pieno, vuoto, colore):
    """Rettangolo arrotondato tratteggiato: lati a trattini, angoli pieni."""
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius=raggio, outline=colore, width=spessore)
    # buchi lungo i lati dritti, colore del fondo
    passo = pieno + vuoto
    for lato in ("su", "giu", "sx", "dx"):
        if lato in ("su", "giu"):
            a, b = x0 + raggio, x1 - raggio
            y = y0 if lato == "su" else y1 - spessore + 1
            t = a + pieno
            while t + vuoto < b:
                d.rectangle([t, y - 2, t + vuoto, y + spessore + 2], fill=(0, 0, 0, 0))
                t += passo
        else:
            a, b = y0 + raggio, y1 - raggio
            x = x0 if lato == "sx" else x1 - spessore + 1
            t = a + pieno
            while t + vuoto < b:
                d.rectangle([x - 2, t, x + spessore + 2, t + vuoto], fill=(0, 0, 0, 0))
                t += passo


def simbolo(img, x0, y0, s):
    strato = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(strato)
    tratteggio(d, [x0 + s * .06, y0 + s * .06, x0 + s * .86, y0 + s * .86], int(s * .1), int(s * .035),
               int(s * .07), int(s * .05), (255, 255, 255, 150))
    f = ImageFont.truetype(FONT_ICONE, int(s * .58))
    d.text((x0 + s * .46, y0 + s * .45), BORSA, font=f, fill="white", anchor="mm")
    cx, cy, r = x0 + s * .80, y0 + s * .80, s * .20
    d.ellipse([cx - r * 1.14, cy - r * 1.14, cx + r * 1.14, cy + r * 1.14], fill=NAVY)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENTO)
    fp = ImageFont.truetype(FONT_ICONE, int(s * .25))
    d.text((cx, cy), FORBICI, font=fp, fill="white", anchor="mm")
    img.alpha_composite(strato)


img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
sfondo(img)
simbolo(img, G * .10, G * .10, G * .80)
img.resize((1024, 1024), Image.LANCZOS).save(os.path.join(QUI, "assets", "icona.png"))
ad = Image.new("RGBA", (G, G), (0, 0, 0, 0))
simbolo(ad, G * .19, G * .19, G * .62)
ad.resize((1024, 1024), Image.LANCZOS).save(os.path.join(QUI, "assets", "icona-adattiva.png"))
print("icone create")

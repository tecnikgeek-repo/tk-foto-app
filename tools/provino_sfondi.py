"""Provino di tutti gli sfondi a tema: una riga per categoria, nome sotto ogni sfondo.
Uso: python tools/provino_sfondi.py <file png di uscita>"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
elenco = json.load(open(os.path.join(QUI, "tools", "sfondi_canva.json"), encoding="utf-8"))
W, H, T, M = 180, 223, 26, 8
font = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 15)
titolo = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 20)
righe = len(elenco)
foglio = Image.new("RGB", (M + 10 * (W + M), righe * (H + T + 34) + M), (238, 241, 246))
d = ImageDraw.Draw(foglio)
y = M
for categoria, sfondi in elenco.items():
    d.text((M, y), categoria.upper(), font=titolo, fill=(15, 23, 42))
    y += 30
    for n, s in enumerate(sfondi):
        im = Image.open(os.path.join(QUI, "assets", "sfondi", categoria, f"{n + 1:02d}.jpg"))
        im.thumbnail((W, H))
        x = M + n * (W + M)
        foglio.paste(im, (x, y))
        d.text((x + 2, y + H + 3), s["nome"], font=font, fill=(51, 65, 85))
    y += H + T + 4
foglio.save(sys.argv[1], quality=85)
print("provino salvato")

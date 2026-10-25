"""Porta nell'app gli sfondi a tema esportati da Canva.
Il design Canva «tk-foto sfondi a tema» ha una pagina per sfondo, nell'ordine di sfondi_canva.json
(categorie e sfondi in quell'ordine), dopo una prima pagina da saltare.
Uso: python tools/importa_sfondi.py <cartella con i JPG esportati, numerati per pagina> [pagine da saltare] [categorie]
[categorie] = solo queste, separate da virgola (i JPG sono solo i loro, nello stesso ordine); le altre restano come sono.
-> assets/sfondi/<categoria>/NN.jpg (JPG 82, lato lungo 1408) + lib/dati/temi_elenco.dart"""
import json, os, re, sys
from PIL import Image

QUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
elenco = json.load(open(os.path.join(QUI, "tools", "sfondi_canva.json"), encoding="utf-8"))
cartella = sys.argv[1]
saltate = int(sys.argv[2]) if len(sys.argv) > 2 else 1
solo = sys.argv[3].split(",") if len(sys.argv) > 3 else list(elenco)


def numero(nome):
    cifre = re.findall(r"\d+", nome)
    return int(cifre[-1]) if cifre else 0


file = sorted((f for f in os.listdir(cartella) if f.lower().endswith((".jpg", ".jpeg", ".png"))), key=numero)
file = file[saltate:]
attesi = sum(len(elenco[c]) for c in solo)
if len(file) != attesi:
    sys.exit(f"trovati {len(file)} file, ne servono {attesi}")

righe = []
i = 0
for categoria, sfondi in elenco.items():
    dest = os.path.join(QUI, "assets", "sfondi", categoria)
    os.makedirs(dest, exist_ok=True)
    voci = []
    for n, s in enumerate(sfondi, 1):
        if categoria in solo:
            im = Image.open(os.path.join(cartella, file[i])).convert("RGB")
            i += 1
            if max(im.size) > 1408:
                im.thumbnail((1408, 1408), Image.LANCZOS)
            im.save(os.path.join(dest, f"{n:02d}.jpg"), quality=82, optimize=True, progressive=True)
        voci.append(f"({n}, '{s['nome'].replace(chr(39), chr(92) + chr(39))}')")
    righe.append(f"  '{categoria}': [{', '.join(voci)}],")

with open(os.path.join(QUI, "lib", "dati", "temi_elenco.dart"), "w", encoding="utf-8", newline="\n") as f:
    f.write("// Scritto da tools/importa_sfondi.py: non modificare a mano.\n")
    f.write("// categoria -> (numero del file, nome mostrato)\n")
    f.write("const elencoTemi = <String, List<(int, String)>>{\n" + "\n".join(righe) + "\n};\n")
print(f"importati {i} sfondi")

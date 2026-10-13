#!/usr/bin/env python3
"""Dresse la carte de la RAM utilisateur et dit ce qu'il reste de libre.

A lancer apres chaque ajout un peu gros : les zones de travail sont a
adresse fixe, et le programme finit par les rattraper.
"""

import os
import re
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    subprocess.run(["64tass", "--cbm-prg", "-o", "dames.prg", "-L", "dames.lst",
                    "main.asm"], cwd=RACINE, capture_output=True)
    src = open(os.path.join(RACINE, "constantes.asm")).read()
    lst = open(os.path.join(RACINE, "dames.lst")).read()

    def val(nom):
        trouve = re.search(r"^%s\s*=\s*\$([0-9A-Fa-f]+)" % nom, src, re.M)
        return int(trouve.group(1), 16) if trouve else None

    fin_prog = max(int(m, 16) for m in re.findall(r"^\.([0-9a-f]{4})", lst, re.M))
    os.remove(os.path.join(RACINE, "dames.lst"))

    zones = [
        ("programme + donnees", 0x0401, fin_prog),
        ("marques", val("marques"), val("marques") + 143),
        ("index des coups", val("coups_index_lo"), val("coups_index_hi") + 191),
        ("liste des coups", val("coups_zone"), val("coups_zone") + 1535),
        ("annulation (recherche)", val("annul_zone"), val("annul_zone") + 511),
        ("ordre des coups", val("ordre_lo"), val("ordre_hi") + 191),
        ("transpositions", val("table_trans"), val("table_trans") + 8191),
        ("annulation (partie)", val("annul_partie"), val("FIN_ANNUL_PARTIE")
         if val("FIN_ANNUL_PARTIE") else 0x67FF),
    ]
    zones.sort(key=lambda z: z[1])

    print("%-24s %-13s %7s" % ("zone", "adresses", "octets"))
    occupe = 0
    precedent = 0x0400
    trous = []
    for nom, debut, fin in zones:
        if debut > precedent + 1:
            trous.append((precedent + 1, debut - 1))
        print("%-24s $%04X-$%04X %7d" % (nom, debut, fin, fin - debut + 1))
        occupe += fin - debut + 1
        precedent = max(precedent, fin)
    if precedent < 0x7FFF:
        trous.append((precedent + 1, 0x7FFF))

    print("\n%-24s %-13s %7s" % ("libre", "adresses", "octets"))
    libre = 0
    for debut, fin in trous:
        print("%-24s $%04X-$%04X %7d" % ("", debut, fin, fin - debut + 1))
        libre += fin - debut + 1

    marge = val("marques") - fin_prog - 1
    print("\nRAM utilisateur $0400-$7FFF : %d octets" % (0x8000 - 0x0400))
    print("  occupes : %d   libres : %d (%.1f Ko)" % (occupe, libre, libre / 1024))
    print("  marge avant la premiere zone de travail : %d octets" % marge)
    print("  plus 64 Ko de RAM etendue, jamais touches")
    return 0


if __name__ == "__main__":
    sys.exit(main())

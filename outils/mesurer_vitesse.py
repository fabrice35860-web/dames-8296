#!/usr/bin/env python3
"""Mesure le cout du generateur de coups dans VICE.

Depouille les horloges deposees par test_vitesse.asm et en tire le temps
d'une generation, de quoi dimensionner la profondeur de recherche.
"""

import os
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from test_coups import executer, ecrire_positions                 # noqa: E402
from reference import (plateau_initial, plateau_depuis, coups_legaux,  # noqa: E402
                       PION_B, PION_N, DAME_B, DAME_N, BLANC, NOIR)

NB_TOURS = 50


def main():
    positions = [
        ("ouverture", plateau_initial(), BLANC),
        ("milieu de partie",
         plateau_depuis({7: PION_N, 12: PION_N, 13: PION_N, 18: PION_N, 19: PION_N,
                         22: PION_N, 23: PION_N, 24: PION_N, 28: PION_B, 29: PION_B,
                         32: PION_B, 33: PION_B, 34: PION_B, 38: PION_B, 39: PION_B,
                         43: PION_B}), BLANC),
        ("finale avec dames",
         plateau_depuis({5: DAME_B, 23: DAME_B, 31: PION_B,
                         14: DAME_N, 36: DAME_N, 44: PION_N}), BLANC),
        ("prise obligatoire",
         plateau_depuis({32: PION_B, 28: PION_N, 19: PION_N}), BLANC),
    ]
    ecrire_positions(positions, os.path.join(RACINE, "test_positions.asm"))
    prg = os.path.join(RACINE, "test_vitesse.prg")
    r = subprocess.run(["64tass", "--cbm-prg", "-o", prg, "test_vitesse.asm"],
                       cwd=RACINE, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout + r.stderr)
        return 1
    donnees = executer(prg, 4096)
    if donnees is None:
        print("ECHEC : le programme de mesure ne s'est pas termine")
        return 1

    print("%-20s %8s %8s %10s" % ("position", "coups", "jiffies", "par appel"))
    i = 0
    for nom, pl, trait in positions:
        avant = donnees[i] * 65536 + donnees[i + 1] * 256 + donnees[i + 2]
        apres = donnees[i + 3] * 65536 + donnees[i + 4] * 256 + donnees[i + 5]
        nb = donnees[i + 6]
        i += 7
        jiffies = apres - avant
        # une image vaut 1/50 s sur une machine europeenne, soit 20 000 cycles
        ms = jiffies * 20.0 / NB_TOURS
        print("%-20s %8d %8d %8.1f ms" % (nom, nb, jiffies, ms))
        attendu = len(coups_legaux(pl, trait))
        if nb != attendu:
            print("   (attention : %d coups attendus)" % attendu)
    return 0


if __name__ == "__main__":
    sys.exit(main())

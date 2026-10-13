#!/usr/bin/env python3
"""Verifie le prototype de reference sur des positions aux resultats connus.

L'oracle sert a juger le code 6502 : il faut donc d'abord le juger lui-meme.
Chaque position ci-dessous a ete calculee a la main a partir des regles FFJD.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference import (plateau_depuis, plateau_initial, coups_legaux, afficher,
                       PION_B, PION_N, DAME_B, DAME_N, BLANC, NOIR)      # noqa: E402


def notation(coups):
    return sorted(str(c) for c in coups)


CAS = [
    ("ouverture : 9 coups simples",
     plateau_initial(), BLANC,
     ["31-26", "31-27", "32-27", "32-28", "33-28", "33-29", "34-29", "34-30", "35-30"]),

    ("prise obligatoire : les coups simples disparaissent",
     plateau_depuis({32: PION_B, 28: PION_N}), BLANC,
     ["32x23(28)"]),

    ("rafle double",
     plateau_depuis({32: PION_B, 28: PION_N, 19: PION_N}), BLANC,
     ["32x14(19,28)"]),

    ("le pion prend aussi en arriere",
     plateau_depuis({28: PION_B, 32: PION_N}), BLANC,
     ["28x37(32)"]),

    ("prise majoritaire : seule la plus longue est jouable",
     # en bas a droite une prise simple (45x34), a gauche une rafle de
     # deux (32x14) : seule la rafle est jouable
     plateau_depuis({32: PION_B, 28: PION_N, 19: PION_N,
                     45: PION_B, 40: PION_N}), BLANC,
     ["32x14(19,28)"]),

    ("prises de meme longueur : libre choix",
     plateau_depuis({31: PION_B, 27: PION_N,
                     35: PION_B, 30: PION_N}), BLANC,
     ["31x22(27)", "35x24(30)"]),

    ("promotion : le pion s'arrete sur la derniere rangee",
     plateau_depuis({7: PION_B}), BLANC,
     ["7-1D", "7-2D"]),

    ("pas de promotion si le pion ne fait que traverser",
     # 14 prend 9, arrive en 3 sur la derniere rangee, mais doit continuer
     # et prendre 8 : il finit en 12 et reste pion
     plateau_depuis({14: PION_B, 9: PION_N, 8: PION_N}), BLANC,
     ["14x12(8,9)"]),

    ("dame volante : deplacement a distance",
     plateau_depuis({46: DAME_B}), BLANC,
     ["46-41", "46-37", "46-32", "46-28", "46-23", "46-19", "46-14", "46-10", "46-5"]),

    ("dame volante : prise a distance, arret libre derriere",
     plateau_depuis({46: DAME_B, 23: PION_N}), BLANC,
     ["46x19(23)", "46x14(23)", "46x10(23)", "46x5(23)"]),

    ("dame : une piece juste derriere interdit la prise",
     plateau_depuis({46: DAME_B, 23: PION_N, 19: PION_N}), BLANC,
     ["46-41", "46-37", "46-32", "46-28"]),

    ("rafle de dame en deux temps",
     plateau_depuis({46: DAME_B, 23: PION_N, 14: PION_N}), BLANC,
     ["46x10(14,23)", "46x5(14,23)"]),

    ("rafle en carre : le pion revient sur sa case de depart",
     # 33 prend 28, 18, 19, 29 et retombe en 33, qu'il a quittee des le debut ;
     # il ne peut pas repartir, les quatre pieces etant deja prises
     plateau_depuis({33: PION_B, 28: PION_N, 18: PION_N,
                     19: PION_N, 29: PION_N}), BLANC,
     ["33x33(18,19,28,29)"]),

    ("une piece deja prise bloque le passage",
     # apres 50x44, la dame s'arrete en 39 : 33 est encore la et barre la
     # diagonale ; elle doit donc enchainer sur 33 et ne peut pas en rester la
     plateau_depuis({50: DAME_B, 44: PION_N, 33: PION_N}), BLANC,
     ["50x28(33,44)", "50x22(33,44)", "50x17(33,44)",
      "50x11(33,44)", "50x6(33,44)"]),

    ("rafle ambigue : deux chemins, deux butins",
     plateau_depuis({8: PION_B, 10: DAME_N, 24: PION_N, 25: DAME_B, 38: PION_N,
                     39: PION_N, 42: PION_N, 45: PION_B, 47: DAME_N,
                     50: DAME_N}), BLANC,
     ["25x5(10,38,39)", "25x5(10,39,42)"]),

    ("trait aux Noirs : le sens d'avance est inverse",
     plateau_initial(), NOIR,
     ["16-21", "17-21", "17-22", "18-22", "18-23", "19-23", "19-24", "20-24", "20-25"]),
]


def main():
    echecs = 0
    for nom, pl, trait, attendu in CAS:
        obtenu = notation(coups_legaux(pl, trait))
        if obtenu != sorted(attendu):
            echecs += 1
            print("ECHEC  %s" % nom)
            print(afficher(pl))
            print("   attendu : %s" % " ".join(sorted(attendu)))
            print("   obtenu  : %s" % " ".join(obtenu))
            print()
        else:
            print("ok     %-55s %s" % (nom, " ".join(obtenu)))
    print()
    print("%d cas, %d echec(s)" % (len(CAS), echecs))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())

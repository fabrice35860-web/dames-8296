#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere donnees_tables.asm : tables de conversion cases <-> plateau <-> ecran.

Le plateau interne est un tableau de 12x12 = 144 octets avec une bordure
d'une case tout autour (cases fantomes), de sorte que les quatre directions
diagonales soient des decalages constants :
    haut-gauche -13, haut-droit -11, bas-gauche +11, bas-droit +13
Case (r,c) avec r,c dans 0..9  ->  index = 12*(r+1) + (c+1) = 12*r + c + 13

Numerotation officielle des dames internationales (1..50) :
    case n  ->  r = (n-1) // 5
                c = 2*((n-1) % 5) + (1 si r pair, 0 si r impair)
Les cases jouables (foncees) sont celles ou (r+c) est impair.

Geometrie ecran : case (r,c) -> x = 2 + 5*c, y = 2 + 2*r
Adresse ecran du coin haut-gauche = $8000 + 80*y + x
"""

import os

ECRAN = 0x8000


def rc_depuis_num(n):
    r = (n - 1) // 5
    c = 2 * ((n - 1) % 5) + (1 if r % 2 == 0 else 0)
    return r, c


def idx_depuis_rc(r, c):
    return 12 * r + c + 13


def octets(nom, valeurs, commentaire, par_ligne=10):
    lignes = ["; " + commentaire, nom + ":"]
    for i in range(0, len(valeurs), par_ligne):
        tranche = valeurs[i:i + par_ligne]
        lignes.append("        .byte " + ",".join("$%02X" % v for v in tranche))
    return "\n".join(lignes) + "\n"


def bonus_pion(n):
    """Valeur de position d'un pion blanc sur la case n.

    Un pion vaut d'autant plus qu'il approche de la promotion ; le centre
    est plus sur que les bords ; et garder garnie sa derniere rangee evite
    de se faire percer.
    """
    r, c = rc_depuis_num(n)
    valeur = (9 - r) * 2                 # avancement vers la promotion
    if 2 <= c <= 7:
        valeur += 2                      # colonnes centrales
    if n >= 46:
        valeur += 3                      # derniere rangee encore gardee
    return valeur


def bonus_dame(n):
    """Valeur de position d'une dame blanche : seul le centre compte,
    d'ou elle rayonne sur les deux grandes diagonales."""
    r, c = rc_depuis_num(n)
    if 2 <= c <= 7 and 2 <= r <= 7:
        return 4
    return 0


def zobrist():
    """Nombres de hachage Zobrist, 16 bits, un par couple (piece, case).

    Tirage a germe fixe : la table doit etre la meme d'une compilation a
    l'autre, et le prototype de reference doit pouvoir la reproduire.
    """
    import random
    alea = random.Random(20251013)
    # 4 types de pieces (pion blanc, dame blanche, pion noir, dame noire)
    # et 50 cases, plus une valeur pour le camp au trait
    valeurs = [alea.randrange(1, 65536) for _ in range(4 * 50 + 1)]
    return valeurs


def main():
    num_vers_idx = []
    case_adr_lo = []
    case_adr_hi = []
    idx_vers_num = [0] * 144

    for n in range(1, 51):
        r, c = rc_depuis_num(n)
        assert (r + c) % 2 == 1, "case %d non jouable" % n
        idx = idx_depuis_rc(r, c)
        num_vers_idx.append(idx)
        idx_vers_num[idx] = n
        x = 2 + 5 * c
        y = 2 + 2 * r
        adr = ECRAN + 80 * y + x
        case_adr_lo.append(adr & 0xFF)
        case_adr_hi.append(adr >> 8)

    # adresses du debut de chaque ligne ecran (25 lignes)
    lig_lo = [(ECRAN + 80 * y) & 0xFF for y in range(25)]
    lig_hi = [(ECRAN + 80 * y) >> 8 for y in range(25)]

    out = []
    out.append("; " + "=" * 69)
    out.append(";  donnees_tables.asm - tables precalculees")
    out.append(";  FICHIER GENERE PAR outils/generer_tables.py - NE PAS EDITER A LA MAIN")
    out.append("; " + "=" * 69 + "\n")
    out.append(octets("num_vers_idx", num_vers_idx,
                      "numero de case officiel (1..50) -> index plateau. Indexe par n-1."))
    out.append(octets("idx_vers_num", idx_vers_num,
                      "index plateau (0..143) -> numero de case, 0 si case non jouable.", 12))
    out.append(octets("case_adr_lo", case_adr_lo,
                      "adresse ecran du coin haut-gauche de la case n (poids faible)."))
    out.append(octets("case_adr_hi", case_adr_hi,
                      "adresse ecran du coin haut-gauche de la case n (poids fort)."))
    out.append(octets("lignes_lo", lig_lo,
                      "adresse du debut de la ligne ecran y (poids faible).", 13))
    out.append(octets("lignes_hi", lig_hi,
                      "adresse du debut de la ligne ecran y (poids fort).", 13))
    out.append(octets("bonus_pion", [bonus_pion(n) for n in range(1, 51)],
                      "valeur de position d'un pion blanc, case 1 a 50. Pour un pion\n"
                      ";  noir sur la case n, lire l'entree de la case 51-n."))
    out.append(octets("bonus_dame", [bonus_dame(n) for n in range(1, 51)],
                      "valeur de position d'une dame blanche, meme symetrie."))

    zob = zobrist()
    out.append(octets("zobrist_lo", [v & 0xFF for v in zob[:200]],
                      "hachage Zobrist : (type de piece - 1) * 50 + (case - 1)."))
    out.append(octets("zobrist_hi", [v >> 8 for v in zob[:200]],
                      "hachage Zobrist, poids fort."))
    out.append(octets("zob_base", [0, 50, 100, 150],
                      "debut de chaque type de piece dans la table Zobrist."))
    out.append("; valeur ajoutee quand les Noirs sont au trait\n"
               "zob_trait:\n        .byte $%02X,$%02X\n"
               % (zob[200] & 0xFF, zob[200] >> 8))

    racine = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    chemin = os.path.join(racine, "donnees_tables.asm")
    with open(chemin, "w") as f:
        f.write("\n".join(out))
    print("ecrit:", chemin)
    print("controles : case 1 -> idx", num_vers_idx[0], "| case 50 -> idx", num_vers_idx[49])
    print("case 1 ecran $%04X | case 46 ecran $%04X"
          % (case_adr_hi[0] * 256 + case_adr_lo[0], case_adr_hi[45] * 256 + case_adr_lo[45]))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compare l'evaluation et la recherche 6502 a leur reference Python.

Meme principe que outils/test_coups.py : une batterie de positions est
embarquee dans un .prg, VICE l'execute, et le pilote relit les resultats
par le moniteur distant pour les confronter a outils/reference_ia.py.

Usage :  python3 outils/test_ia.py [-p profondeur] [-n positions] [-v]
"""

import os
import re
import subprocess
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from test_coups import (executer, ecrire_positions, positions_construites,   # noqa: E402
                        positions_aleatoires, POSITIONS_PAR_LOT)
from reference import (afficher, coups_legaux, jouer,                        # noqa: E402
                       NUM_VERS_IDX, BLANC)
from reference_ia import evaluer, meilleur_coup, alphabeta, SCORE_INF        # noqa: E402


def coup_optimal(pl, trait, profondeur, depart, arrivee, score_voulu):
    """Le coup (depart, arrivee) vaut-il bien le score optimal ?

    Plusieurs coups peuvent relier les memes cases en prenant des pieces
    differentes : il suffit que l'un d'eux atteigne le score.
    """
    for coup in coups_legaux(pl, trait):
        if (coup.depart, coup.arrivee) != (depart, arrivee):
            continue
        suivant = jouer(pl, coup)
        score = -alphabeta(suivant, 1 - trait, profondeur - 1,
                           -SCORE_INF, SCORE_INF, 1)
        if score == score_voulu:
            return True
    return False


def signe16(lo, hi):
    valeur = lo | (hi << 8)
    return valeur - 65536 if valeur >= 32768 else valeur


def regler_profondeur(profondeur):
    chemin = os.path.join(RACINE, "test_ia.asm")
    texte = open(chemin).read()
    texte = re.sub(r"^profondeur  \.byte \d+", "profondeur  .byte %d" % profondeur,
                   texte, flags=re.M)
    open(chemin, "w").write(texte)


def main():
    bavard = "-v" in sys.argv
    profondeur = 2
    if "-p" in sys.argv:
        profondeur = int(sys.argv[sys.argv.index("-p") + 1])
    nb_alea = 20
    if "-n" in sys.argv:
        nb_alea = int(sys.argv[sys.argv.index("-n") + 1])

    positions = positions_construites() + positions_aleatoires(nb_alea, germe=31)
    regler_profondeur(profondeur)
    prg = os.path.join(RACINE, "test_ia.prg")

    print("%d positions, recherche a la profondeur %d" % (len(positions), profondeur))
    resultats = []
    for debut in range(0, len(positions), POSITIONS_PAR_LOT):
        lot = positions[debut:debut + POSITIONS_PAR_LOT]
        ecrire_positions(lot, os.path.join(RACINE, "test_positions.asm"))
        assemblage = subprocess.run(["64tass", "--cbm-prg", "-o", prg, "test_ia.asm"],
                                    cwd=RACINE, capture_output=True, text=True)
        if assemblage.returncode != 0:
            print(assemblage.stdout + assemblage.stderr)
            return 1
        donnees = executer(prg, 32768)
        if donnees is None:
            print("ECHEC : le programme de test ne s'est pas termine dans VICE")
            return 1
        for i in range(len(lot)):
            bloc = donnees[i * 62:(i + 1) * 62]
            resultats.append((signe16(bloc[0], bloc[1]), signe16(bloc[2], bloc[3]),
                              bloc[4], bloc[5], bloc[6] | (bloc[7] << 8),
                              list(bloc[12:62]),
                              (bloc[8], bloc[9]), (bloc[10], bloc[11])))
        print("   lot %d-%d traite" % (debut + 1, debut + len(lot)))

    echecs = 0
    total_images = 0
    for (nom, pl, trait), (eval6502, score6502, dep, arr, images, apres,
                           cle_apres, cle_vraie) in zip(positions, resultats):
        total_images += images
        voulu_eval = evaluer(pl, trait)
        voulu_score, voulu_coup = meilleur_coup(pl, trait, profondeur)
        soucis = []
        if eval6502 != voulu_eval:
            soucis.append("evaluation : attendu %d, obtenu %d" % (voulu_eval, eval6502))
        if score6502 != voulu_score:
            soucis.append("score : attendu %d, obtenu %d" % (voulu_score, score6502))
        # Le coup retenu peut differer de celui de la reference sans que ce
        # soit une erreur : a score egal, chacun garde le premier rencontre,
        # et les deux ne produisent pas les coups dans le meme ordre. Ce qui
        # compte est que le coup retenu atteigne bien le score optimal.
        if voulu_coup is not None:
            if not coup_optimal(pl, trait, profondeur, dep, arr, voulu_score):
                soucis.append("coup %d-%d : n'atteint pas le score optimal %d"
                              % (dep, arr, voulu_score))
        if cle_apres != cle_vraie:
            soucis.append("hachage : la clef n'est pas revenue a sa valeur "
                          "($%02X%02X au lieu de $%02X%02X)"
                          % (cle_apres[1], cle_apres[0], cle_vraie[1], cle_vraie[0]))
        depart_voulu = [pl[NUM_VERS_IDX[n]] for n in range(1, 51)]
        if apres != depart_voulu:
            differences = [n for n in range(1, 51)
                           if apres[n - 1] != depart_voulu[n - 1]]
            soucis.append("plateau abime par la recherche, cases %s"
                          % " ".join(str(n) for n in differences[:12]))
        if soucis:
            echecs += 1
            print("ECHEC  %s" % nom)
            print(afficher(pl))
            for s in soucis:
                print("   " + s)
            print()
        elif bavard:
            print("ok     %-26s eval %6d  score %6d  %d-%d  %d images"
                  % (nom, eval6502, score6502, dep, arr, images))
    print()
    print("%d position(s), %d echec(s), %.1f s de recherche au total"
          % (len(positions), echecs, total_images / 50.0))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Tests automatiques de l'affichage et de la saisie (etape 1).

Chaque scenario lance le jeu dans VICE en injectant une suite de touches,
relit l'ecran produit avec outils/lire_ecran.py, et verifie que les lignes
attendues contiennent bien le texte voulu.

Usage :  python3 outils/test_affichage.py [-v]

Limite connue : l'option -keybuf de VICE ne transmet que des caracteres deja
decodes. Elle ne passe donc ni les fleches du curseur ($1D/$9D/$11/$91) ni la
touche DEL ($14), et les lettres doivent y etre ecrites en minuscules. Les
scenarios ci-dessous deplacent le curseur avec le pave numerique, qui emet des
chiffres ordinaires ; les fleches et DEL restent a verifier a la main.
"""

import os
import subprocess
import sys
import tempfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from lire_ecran import lire_grille, symbole          # noqa: E402

PRG = os.path.join(RACINE, "dames.prg")
CYCLES = "26000000"

# Un scenario : (nom, touches, [(ligne, texte attendu), ...])
# Le texte attendu doit apparaitre quelque part dans la ligne.
SCENARIOS = [
    # au depart c'est aux Blancs : l'ordinateur, qui tient les Noirs, ne
    # joue pas encore, inutile de le couper ici
    ("position de depart", "\n ", [
        (3, "ORDI   : NOIRS"),
        (0, "JEU DE DAMES INTERNATIONALES"),
        (0, "COMMODORE 8296"),
        (2, "TRAIT  : BLANCS"),
        (3, "ORDI   : NOIRS"),
        (4, "NIVEAU :  1"),
        (5, "PIECES : 20 - 20"),
        (7, "DERNIERS COUPS"),
        (13, "LEGENDE"),
        (15, "PION BLANC"),
        (17, "DAME BLANCHE"),
        (19, "PION NOIR"),
        (21, "DAME NOIRE"),
        (23, "NOUVELLE PARTIE - AUX BLANCS DE JOUER"),
        (24, "CASE 32"),
        (24, "R=RETOUR *=COUP ?=AIDE Q=FIN"),
    ]),
    # Deplacements du curseur depuis la case 32 (rangee 6, colonne logique 3).
    ("pave 4 : case a gauche", "\n ao4", [(24, "CASE 31")]),
    ("pave 6 : case a droite", "\n ao6", [(24, "CASE 33")]),
    ("pave 8 : rangee du dessus", "\n ao8", [(24, "CASE 27")]),
    ("pave 2 : rangee du dessous", "\n ao2", [(24, "CASE 37")]),
    ("pave 7 : diagonale haut-gauche", "\n ao7", [(24, "CASE 27")]),
    ("pave 9 : diagonale haut-droite", "\n ao9", [(24, "CASE 28")]),
    ("pave 1 : diagonale bas-gauche", "\n ao1", [(24, "CASE 37")]),
    ("pave 3 : diagonale bas-droite", "\n ao3", [(24, "CASE 38")]),
    # Le curseur ne quitte pas le damier.
    ("bord gauche : 31 puis 4", "\n ao44", [(24, "CASE 31")]),
    ("bord bas : descendre six fois", "\n ao222222", [(24, "CASE 47")]),
    ("choix d'une piece", "\n ao ", [
        (23, "PIECE 32 SELECTIONNEE - DESTINATION ?"),
        (24, "CASE 32"),
    ]),
    ("choix relache si on revalide", "\n ao  ", [
        (23, "CHOISISSEZ UNE PIECE - TRAIT AUX BLANCS"),
    ]),
    ("changement de piece choisie", "\n ao 6 ", [
        (23, "PIECE 33 SELECTIONNEE - DESTINATION ?"),
    ]),
    ("case vide sans piece choisie", "\n ao9 ", [
        (23, "CASE VIDE - CHOISISSEZ UNE DE VOS PIECES"),
    ]),
    ("piece de l'adversaire", "\n ao888 ", [
        (23, "CETTE PIECE EST A L'ADVERSAIRE"),
    ]),
    ("coup joue au curseur, le trait change", "\n ao 9 ", [
        (2, "TRAIT  : NOIRS"),
        (8, "32-28"),
        (23, "CHOISISSEZ UNE PIECE - TRAIT AUX NOIRS"),
        (24, "CASE 28"),          # le curseur reste sur la piece jouee
    ]),
    ("deux coups dans l'historique", "\n ao 9 88 2 ", [
        (2, "TRAIT  : BLANCS"),
        (8, "18-23"),
        (9, "32-28"),
    ]),
    # --- les regles, depuis l'etape 2 ---------------------------------
    ("coup impossible refuse", "\n ao 88 ", [
        (23, "COUP IMPOSSIBLE - CHOISISSEZ UNE AUTRE CASE"),
    ]),
    ("piece bloquee", "\n ao222 ", [
        (23, "CETTE PIECE EST BLOQUEE"),
    ]),
    # apres 32-28 19-23, les Blancs doivent prendre : aucune autre piece
    # ne peut jouer
    ("prise obligatoire", "\n ao 9 99 1 33 ", [
        (23, "PRISE OBLIGATOIRE - CETTE PIECE NE PEUT PAS JOUER"),
    ]),
    ("prise effective : piece retiree et comptee", "\n ao 9 99 1 1 99 ", [
        (5, "PIECES : 20 - 19"),
        (8, "28X19"),
        (2, "TRAIT  : NOIRS"),
    ]),
    # Saisie en notation, ouverte par "*".
    ("etoile ouvre la saisie", "\n ao*", [(24, "VOTRE COUP :")]),
    ("etoile puis echap par etoile", "\n ao**", [(24, "CASE 32")]),
    ("saisie d'un numero de case", "\n ao*28\n", [
        (24, "CASE 28"),
        (23, "CASE VIDE - CHOISISSEZ UNE DE VOS PIECES"),
    ]),
    # 33 est en premiere ligne : contrairement a 37, elle a des coups
    ("saisie pour choisir une piece", "\n ao*33\n", [
        (23, "PIECE 33 SELECTIONNEE - DESTINATION ?"),
    ]),
    ("coup joue par la saisie", "\n ao *28\n", [
        (8, "32-28"),
        (2, "TRAIT  : NOIRS"),
    ]),
    ("numero hors du damier", "\n ao*99\n", [
        (23, "NUMERO DE CASE INVALIDE (1 A 50)"),
    ]),
    ("aide", "\n ao?", [
        (23, "FLECHES/PAVE : DEPLACER  ESPACE : CHOISIR"),
        (23, "* : NUMERO  R : RETOUR  M : MENU"),
    ]),
    # --- l'ordinateur, depuis l'etape 3 -------------------------------
    ("l'ordinateur repond au premier coup", "\n a 9 ", [
        (2, "TRAIT  : BLANCS"),      # il a joue, la main revient au joueur
        (3, "ORDI   : NOIRS"),
        (9, "32-28"),                # le coup du joueur
    ]),
    ("bascule du camp tenu par l'ordinateur", "\n ao", [
        (3, "ORDI   : AUCUN"),
        (23, "O : CAMP TENU PAR L'ORDINATEUR"),
    ]),
    # --- choix du jeu de caracteres ---------------------------------
    ("ecran de choix de la ROM", "", [
        (4, "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"),
        (7, "1 - ROM STANDARD"),
        (7, "2 - ROM FRANCAISE (EDEX)"),
        (21, "1 OU 2 POUR CHOISIR"),
    ]),
    ("reglage du jeu de caracteres dans le menu", "\n226", [
        (11, "JEU DE CARACTERES ROM FRANCAISE (EDEX)"),
    ]),
    # --- menu et retour arriere ---------------------------------------
    ("ecran de reglages au lancement", "\n", [
        (0, "JEU DE DAMES INTERNATIONALES"),
        (4, "AUX DAMES, LES BLANCS JOUENT TOUJOURS LE PREMIER COUP"),
        (7, "NIVEAU"),
        (9, "VOUS JOUEZ        LES BLANCS (VOUS COMMENCEZ)"),
        (14, "ESPACE : COMMENCER LA PARTIE"),
    ]),
    ("reglage du niveau", "\n66", [
        (7, "NIVEAU            3"),
    ]),
    ("le joueur prend les Noirs : l'ordinateur ouvre", "\n26 ", [
        (3, "ORDI   : BLANCS"),
        (8, "31-27"),                 # la machine a joue le premier coup
        (23, "CHOISISSEZ UNE PIECE - TRAIT AUX NOIRS"),
    ]),
    ("retour arriere apres un coup", "\n ao 9 r", [
        (5, "PIECES : 20 - 20"),
        (8, ""),                      # l'historique est revenu en arriere
        (24, "CASE 32"),
        (2, "TRAIT  : BLANCS"),
    ]),
    ("retour arriere sans rien a defaire", "\n aor", [
        (23, "AUCUN COUP A DEFAIRE"),
    ]),
    ("retour arriere rend les pieces prises", "\n a9 *33\n*29\nr", [
        (5, "PIECES : 20 - 20"),
    ]),
    ("la touche M ramene aux reglages", "\n am", [
        (14, "ESPACE : COMMENCER LA PARTIE"),
    ]),
    # Q rend la main au BASIC : on verifie qu'une commande tapee ensuite
    # s'execute normalement, donc que la machine est dans un etat sain.
    ("retour au BASIC par Q", "\n qprint\"retour ok\"\n", [
        (None, "RETOUR OK"),
        (None, "READY."),
    ]),
    ("nouvelle partie remet tout a zero", "\n ao 9 n", [
        (2, "TRAIT  : BLANCS"),
        (5, "PIECES : 20 - 20"),
        (8, ""),                        # l'historique est efface
        (23, "NOUVELLE PARTIE - AUX BLANCS DE JOUER"),
        (24, "CASE 32"),                # le curseur revient a sa case de depart
    ]),
]


def jouer(touches, image):
    cmd = ["xpet", "-model", "8296", "-autostart", PRG,
           "-limitcycles", CYCLES, "-exitscreenshot", image, "-warp", "+sound"]
    if touches:
        cmd += ["-keybuf", touches]
    subprocess.run(cmd, capture_output=True, timeout=300)


def texte_ligne(grille, n):
    """Ligne d'ecran en texte ; la video inverse est ignoree pour la comparaison,
    un espace inverse (fond des cases foncees et des bandeaux) redevient un espace."""
    return "".join(symbole(c).replace("#", " ") for c in grille[n]).rstrip()


def test_clignotement(dossier):
    """Le fond de la case sous le curseur doit battre en inversion video,
    sans que la piece change de couleur.

    Au depart le curseur est sur la case 32, qui porte un pion blanc. Le
    fond (colonne 0 de la case, ligne 14) alterne entre $A0 et $20, tandis
    que la piece reste $D5 : c'est la video inverse qui distingue un Blanc
    d'un Noir, et inverser la piece la ferait changer de camp a l'oeil.
    """
    etats = set()
    for cycles in range(26000000, 27200001, 150000):
        image = os.path.join(dossier, "clign.png")
        if os.path.exists(image):
            os.remove(image)
        cmd = ["xpet", "-model", "8296", "-autostart", PRG,
               "-limitcycles", str(cycles), "-exitscreenshot", image,
               "-warp", "+sound", "-keybuf", "\n "]  # ROM puis ESPACE
        subprocess.run(cmd, capture_output=True, timeout=300)
        if not os.path.exists(image):
            continue
        grille, infos = lire_grille(image)
        etats.add(grille[14][17])       # fond de la case 32
        # VICE prend parfois sa capture en plein rafraichissement : on ne
        # juge la couleur de la piece que sur les captures impeccables
        if infos[5] == 2000 and grille[14][18] != 0xD5:
            return ("la piece sous le curseur change de couleur : $%02X au "
                    "lieu de $D5" % grille[14][18])
    if not {0xA0, 0x20} <= etats:
        return "le fond de la case sous le curseur ne clignote pas (vu : %s)" % \
               " ".join("$%02X" % e for e in sorted(etats))
    return None


def main():
    bavard = "-v" in sys.argv
    if not os.path.exists(PRG):
        print("dames.prg absent : lancer d'abord 64tass --cbm-prg -o dames.prg main.asm")
        return 1
    echecs = 0
    with tempfile.TemporaryDirectory() as dossier:
        for nom, touches, attentes in SCENARIOS:
            image = os.path.join(dossier, "ecran.png")
            jouer(touches, image)
            if not os.path.exists(image):
                print("ECHEC  %-32s : pas de capture d'ecran" % nom)
                echecs += 1
                continue
            grille, _ = lire_grille(image)
            manques = []
            for ligne, attendu in attentes:
                if ligne is None:       # cherche n'importe ou sur l'ecran
                    tout = "\n".join(texte_ligne(grille, i) for i in range(25))
                    if attendu not in tout:
                        manques.append(("*", attendu, tout.replace("\n", " | ")[:70]))
                elif attendu not in texte_ligne(grille, ligne):
                    manques.append((ligne, attendu, texte_ligne(grille, ligne)))
            if manques:
                echecs += 1
                print("ECHEC  %s" % nom)
                for ligne, attendu, obtenu in manques:
                    print("       ligne %-2s attendu : %r" % (ligne, attendu))
                    print("                obtenu  : %r" % obtenu)
            else:
                print("ok     %s" % nom)
            if bavard:
                for i in range(25):
                    print("    %2d| %s" % (i, texte_ligne(grille, i)))

        probleme = test_clignotement(dossier)
        if probleme:
            echecs += 1
            print("ECHEC  clignotement : %s" % probleme)
        else:
            print("ok     clignotement de la case sous le curseur")
    print()
    print("%d scenario(s), %d echec(s)" % (len(SCENARIOS) + 1, echecs))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())

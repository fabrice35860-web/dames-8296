#!/usr/bin/env python3
"""Relit une capture d'ecran de VICE et en extrait la grille 80x25 de codes ecran.

Principe : chaque cellule de l'image est comparee aux 256 glyphes du generateur
de caracteres (en video normale et en video inverse). On retrouve ainsi
exactement ce que le programme a ecrit dans la memoire ecran, ce qui permet de
verifier l'affichage automatiquement, sans avoir a regarder l'image.

Un glyphe fait 8x8 pixels, mais le CRTC du 8296 espace les lignes : sur les
captures de VICE une cellule occupe 9 pixels de haut (8 de dessin, 1 de blanc).
Le pas vertical est determine automatiquement.

Usage :
    python3 outils/lire_ecran.py capture.png            # rendu lisible
    python3 outils/lire_ecran.py capture.png --codes    # codes hexadecimaux
"""

import os
import sys
import zlib
import struct

def _chercher_chargen():
    """Trouve le generateur de caracteres du PET installe pour VICE.

    Les ROM ne sont pas fournies avec ce projet : le README dit ou les
    prendre. La variable d'environnement PET_CHARGEN permet d'en designer
    une autre, par exemple pour essayer une EPROM francaise.
    """
    force = os.environ.get("PET_CHARGEN")
    if force:
        return force
    candidats = [
        os.path.expanduser("~/.local/share/vice/PET/characters-2.901447-10.bin"),
        "/usr/share/vice/PET/characters-2.901447-10.bin",
        "/usr/local/share/vice/PET/characters-2.901447-10.bin",
    ]
    for chemin in candidats:
        if os.path.exists(chemin):
            return chemin
    raise SystemExit(
        "generateur de caracteres du PET introuvable.\n"
        "Installez les ROM de VICE (voir le README) ou indiquez le fichier\n"
        "par la variable d'environnement PET_CHARGEN.")


CHARGEN = _chercher_chargen()
COLONNES = 80
LIGNES = 25


# ---------------------------------------------------------------------------
#  Decodage PNG minimal (suffisant pour ce que produit VICE)
# ---------------------------------------------------------------------------
def lire_png(chemin):
    """Retourne (largeur, hauteur, pixels), pixels[y][x] vrai si le point est allume."""
    donnees = open(chemin, "rb").read()
    assert donnees[:8] == b"\x89PNG\r\n\x1a\n", "ce n'est pas un fichier PNG"
    pos = 8
    idat = b""
    palette = None
    largeur = hauteur = profondeur = type_couleur = None
    while pos < len(donnees):
        taille, nom = struct.unpack(">I4s", donnees[pos:pos + 8])
        corps = donnees[pos + 8:pos + 8 + taille]
        if nom == b"IHDR":
            largeur, hauteur, profondeur, type_couleur = struct.unpack(">IIBB", corps[:10])
        elif nom == b"PLTE":
            palette = corps
        elif nom == b"IDAT":
            idat += corps
        elif nom == b"IEND":
            break
        pos += 12 + taille

    brut = zlib.decompress(idat)
    canaux = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[type_couleur]
    assert profondeur == 8, "profondeur %d non geree" % profondeur
    pas = largeur * canaux
    lignes = []
    precedente = bytearray(pas)
    i = 0
    for _ in range(hauteur):
        filtre = brut[i]
        i += 1
        ligne = bytearray(brut[i:i + pas])
        i += pas
        for x in range(pas):
            a = ligne[x - canaux] if x >= canaux else 0
            b = precedente[x]
            c = precedente[x - canaux] if x >= canaux else 0
            if filtre == 1:
                ligne[x] = (ligne[x] + a) & 0xFF
            elif filtre == 2:
                ligne[x] = (ligne[x] + b) & 0xFF
            elif filtre == 3:
                ligne[x] = (ligne[x] + (a + b) // 2) & 0xFF
            elif filtre == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                ligne[x] = (ligne[x] + pr) & 0xFF
        lignes.append(ligne)
        precedente = ligne

    pixels = []
    for ligne in lignes:
        rang = []
        for x in range(largeur):
            if type_couleur == 3:
                idx = ligne[x]
                r, v, b = palette[idx * 3:idx * 3 + 3]
            elif type_couleur == 0:
                r = v = b = ligne[x]
            else:
                r, v, b = ligne[x * canaux:x * canaux + 3]
            rang.append((r + v + b) > 150)
        pixels.append(rang)
    return largeur, hauteur, pixels


# ---------------------------------------------------------------------------
#  Reconnaissance des caracteres
# ---------------------------------------------------------------------------
def charger_glyphes(jeu=0):
    """motif -> code ecran, en video normale et inverse.

    Le generateur de caracteres contient deux jeux de 128 glyphes :
    jeu 0 = majuscules + graphiques (POKE 59468,12, celui du jeu de dames),
    jeu 1 = minuscules / majuscules (POKE 59468,14, celui du BASIC).
    """
    rom = open(CHARGEN, "rb").read()
    base = jeu * 128
    table = {}
    for code in range(128):
        motif = tuple(rom[(base + code) * 8 + r] for r in range(8))
        table.setdefault(motif, code)
        table.setdefault(tuple(~o & 0xFF for o in motif), code | 0x80)
    return table


def plus_proche(motif, glyphes):
    """Glyphe le plus ressemblant, en nombre de pixels differents.

    VICE prend parfois sa capture au milieu d'un rafraichissement : quelques
    cellules sortent alors legerement deformees. Plutot que de les declarer
    illisibles, on retient le glyphe le plus proche et on signale l'ecart.
    """
    meilleur, distance = None, 65
    for reference, code in glyphes.items():
        d = 0
        for a, b in zip(motif, reference):
            d += bin(a ^ b).count("1")
            if d >= distance:
                break
        else:
            meilleur, distance = code, d
            if d == 0:
                break
    return meilleur, distance


def cellule(pixels, x, y):
    motif = []
    for r in range(8):
        octet = 0
        for c in range(8):
            if pixels[y + r][x + c]:
                octet |= 0x80 >> c
        motif.append(octet)
    return tuple(motif)


def trouver_grille(largeur, hauteur, pixels, glyphes):
    """Cherche l'origine de la grille et le pas vertical qui lisent le mieux l'ecran."""
    min_x, min_y = largeur, hauteur
    for y in range(hauteur):
        for x in range(largeur):
            if pixels[y][x]:
                if y < min_y:
                    min_y = y
                if x < min_x:
                    min_x = x
    if min_x == largeur:
        return None                     # image entierement noire
    meilleur = None
    for pas in range(8, 17):
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                x0, y0 = min_x + dx, min_y + dy
                if x0 < 0 or y0 < 0:
                    continue
                if x0 + COLONNES * 8 > largeur:
                    continue
                if y0 + (LIGNES - 1) * pas + 8 > hauteur:
                    continue
                score = 0
                for lig in range(LIGNES):
                    for col in range(COLONNES):
                        if cellule(pixels, x0 + col * 8, y0 + lig * pas) in glyphes:
                            score += 1
                if meilleur is None or score > meilleur[0]:
                    meilleur = (score, x0, y0, pas)
    return meilleur


def lire_grille(chemin):
    """Retourne (grille, infos) ; grille[ligne][colonne] = code ecran.

    Le jeu de caracteres actif est devine en essayant les deux et en gardant
    celui qui reconnait le plus de cellules.
    """
    largeur, hauteur, pixels = lire_png(chemin)
    meilleur = None
    for jeu in (0, 1):
        glyphes = charger_glyphes(jeu)
        trouve = trouver_grille(largeur, hauteur, pixels, glyphes)
        if trouve is not None and (meilleur is None or trouve[0] > meilleur[0][0]):
            meilleur = (trouve, glyphes)
    if meilleur is None:
        return [[0x20] * COLONNES for _ in range(LIGNES)], \
               (largeur, hauteur, 0, 0, 8, 0, 0)
    (score, x0, y0, pas), glyphes = meilleur
    grille = []
    approches = 0
    for lig in range(LIGNES):
        rang = []
        for col in range(COLONNES):
            motif = cellule(pixels, x0 + col * 8, y0 + lig * pas)
            code = glyphes.get(motif)
            if code is None:
                code, _ = plus_proche(motif, glyphes)
                approches += 1
            rang.append(code)
        grille.append(rang)
    return grille, (largeur, hauteur, x0, y0, pas, score, approches)


# ---------------------------------------------------------------------------
#  Rendu lisible en texte
# ---------------------------------------------------------------------------
SYMBOLES = {
    0x20: " ", 0xA0: "#",
    0x55: "/", 0x49: "\\", 0x4A: "\\", 0x4B: "/",
    0x40: "-", 0x5D: "|", 0x5A: "*",
    0x70: ",", 0x6E: ".", 0x6D: "`", 0x7D: "'",
    0x2D: "-", 0x27: "'", 0x3F: "?", 0x3A: ":",
    0x28: "(", 0x29: ")", 0x2E: ".", 0x2C: ",",
    0x3D: "=", 0x21: "!", 0x2F: "/", 0x3B: ";", 0x2A: "*",
}


def symbole(code):
    """Caractere ASCII representant un code ecran, en majuscule si video inverse."""
    if code is None:
        return "~"
    nu = code & 0x7F
    if nu in SYMBOLES:
        s = SYMBOLES[nu]
        return "#" if (code & 0x80 and nu == 0x20) else s
    if 1 <= nu <= 26:
        return chr(ord("A") + nu - 1)
    if 0x30 <= nu <= 0x39:
        return chr(nu)
    return "?"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    grille, (largeur, hauteur, x0, y0, pas, score, approches) = lire_grille(sys.argv[1])
    brut = "--codes" in sys.argv
    print("image %dx%d, grille en (%d,%d), cellule 8x%d, %d/%d cellules exactes"
          % (largeur, hauteur, x0, y0, pas, score, LIGNES * COLONNES))
    if approches:
        print("%d cellule(s) reconnue(s) par ressemblance (capture prise pendant "
              "un rafraichissement)" % approches)
    print("    " + "".join(str(c % 10) for c in range(COLONNES)))
    for i, rang in enumerate(grille):
        if brut:
            print("%2d: %s" % (i, " ".join("--" if c is None else "%02X" % c for c in rang)))
        else:
            print("%2d| %s" % (i, "".join(symbole(c) for c in rang)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

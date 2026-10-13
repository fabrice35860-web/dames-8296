#!/usr/bin/env python3
"""Compare le generateur de coups 6502 au prototype de reference.

Deroulement :
  1. une batterie de positions est tiree (cas construits a la main, puis
     positions aleatoires a germe fixe, pour couvrir large) ;
  2. elle est ecrite en assembleur dans test_positions.asm, puis
     test_coups.prg est assemble ;
  3. VICE execute ce programme, qui genere les coups de chaque position
     et depose les resultats en $3000 ;
  4. les resultats sont relus par le moniteur distant de VICE et compares,
     position par position, a ceux de outils/reference.py.

Usage :  python3 outils/test_coups.py [-v] [-n nombre_de_positions_aleatoires]
"""

import os
import random
import re
import socket
import subprocess
import sys
import time

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from reference import (plateau_depuis, plateau_initial, coups_legaux,     # noqa: E402
                       afficher, jouer, IDX_VERS_NUM, NUM_VERS_IDX,
                       VIDE, PION_B, DAME_B, PION_N, DAME_N, BLANC, NOIR)

PORT = 6511

# Les zones de travail du generateur sont a adresse fixe ($2000 et au-dela).
# La table des positions est embarquee dans le .prg, qui demarre en $0401 :
# au-dela d'une certaine taille elle viendrait mordre dessus. On traite donc
# la batterie par lots, chacun assemble et execute separement.
POSITIONS_PAR_LOT = 40
SORTIE = 0x6900
DRAPEAU = 0x68FF
TAILLE_TOT = 0x68FD


# ---------------------------------------------------------------------------
#  Batterie de positions
# ---------------------------------------------------------------------------
def positions_construites():
    """Cas choisis pour leur difficulte, chacun eprouvant une regle precise."""
    cas = [
        ("ouverture", plateau_initial(), BLANC),
        ("ouverture, trait aux Noirs", plateau_initial(), NOIR),
        ("prise simple obligatoire", {32: PION_B, 28: PION_N}, BLANC),
        ("rafle double", {32: PION_B, 28: PION_N, 19: PION_N}, BLANC),
        ("prise en arriere", {28: PION_B, 32: PION_N}, BLANC),
        ("prise majoritaire",
         {32: PION_B, 28: PION_N, 19: PION_N, 45: PION_B, 40: PION_N}, BLANC),
        ("prises de meme longueur",
         {31: PION_B, 27: PION_N, 35: PION_B, 30: PION_N}, BLANC),
        ("promotion", {7: PION_B}, BLANC),
        ("promotion des Noirs", {44: PION_N}, NOIR),
        ("traversee sans promotion", {14: PION_B, 9: PION_N, 8: PION_N}, BLANC),
        ("dame seule", {46: DAME_B}, BLANC),
        ("dame : prise a distance", {46: DAME_B, 23: PION_N}, BLANC),
        ("dame : arrivee bouchee", {46: DAME_B, 23: PION_N, 19: PION_N}, BLANC),
        ("dame : rafle en deux temps", {46: DAME_B, 23: PION_N, 14: PION_N}, BLANC),
        ("rafle en carre",
         {33: PION_B, 28: PION_N, 18: PION_N, 19: PION_N, 29: PION_N}, BLANC),
        ("dame bloquee par une prise", {50: DAME_B, 44: PION_N, 33: PION_N}, BLANC),
        ("aucun coup possible", {1: PION_B, 6: PION_N, 7: PION_N}, BLANC),
        ("plateau vide du camp au trait", {26: PION_N}, BLANC),
        ("quatre dames", {6: DAME_B, 16: DAME_B, 35: DAME_B, 45: DAME_B}, BLANC),
        # deux rafles de meme depart et meme arrivee, mais qui ne prennent
        # pas les memes pieces : c'est le cas que le joueur doit departager
        ("rafle ambigue",
         {8: PION_B, 10: DAME_N, 24: PION_N, 25: DAME_B, 38: PION_N,
          39: PION_N, 42: PION_N, 45: PION_B, 47: DAME_N, 50: DAME_N}, BLANC),
        ("dame contre pions",
         {28: DAME_B, 17: PION_N, 18: PION_N, 29: PION_N, 39: PION_N}, BLANC),
    ]
    sorties = []
    for nom, pos, trait in cas:
        pl = pos if isinstance(pos, list) else plateau_depuis(pos)
        sorties.append((nom, pl, trait))
    return sorties


def positions_aleatoires(nombre, germe=12345):
    """Positions tirees au hasard : c'est ce qui deniche les cas imprevus."""
    alea = random.Random(germe)
    sorties = []
    for i in range(nombre):
        cases = {}
        libres = list(range(1, 51))
        alea.shuffle(libres)
        nb_b = alea.randint(1, 8)
        nb_n = alea.randint(1, 8)
        for n in libres[:nb_b]:
            # un pion blanc ne peut pas stationner sur sa rangee de promotion
            choix = [PION_B, PION_B, PION_B, DAME_B]
            if n <= 5:
                choix = [DAME_B]
            cases[n] = alea.choice(choix)
        for n in libres[nb_b:nb_b + nb_n]:
            choix = [PION_N, PION_N, PION_N, DAME_N]
            if n >= 46:
                choix = [DAME_N]
            cases[n] = alea.choice(choix)
        trait = alea.choice([BLANC, NOIR])
        sorties.append(("aleatoire %d" % (i + 1), plateau_depuis(cases), trait))
    return sorties


def ecrire_positions(positions, chemin):
    lignes = ["; " + "=" * 69,
              ";  test_positions.asm - batterie de positions du banc d'essai",
              ";  FICHIER GENERE PAR outils/test_coups.py - NE PAS EDITER",
              "; " + "=" * 69,
              "",
              "nb_positions    .byte %d" % len(positions),
              "",
              "positions"]
    for nom, pl, trait in positions:
        contenu = [pl[NUM_VERS_IDX[n]] for n in range(1, 51)]
        lignes.append("        ; %s" % nom)
        lignes.append("        .byte %d" % trait)
        for debut in range(0, 50, 25):
            tranche = contenu[debut:debut + 25]
            lignes.append("        .byte " + ",".join(str(v) for v in tranche))
    open(chemin, "w").write("\n".join(lignes) + "\n")


# ---------------------------------------------------------------------------
#  Execution dans VICE et lecture de la memoire
# ---------------------------------------------------------------------------
class Moniteur:
    """Dialogue en texte avec le moniteur distant de VICE."""

    def __init__(self, port):
        self.s = socket.create_connection(("127.0.0.1", port), timeout=15)
        self.s.settimeout(10)
        self._vider()

    def _vider(self):
        self.s.settimeout(1.0)
        try:
            while True:
                if not self.s.recv(65536):
                    break
        except socket.timeout:
            pass
        self.s.settimeout(10)

    def commande(self, texte):
        """Envoie une commande sans rien attendre de precis en retour."""
        self.s.sendall((texte + "\n").encode("latin1"))
        time.sleep(0.4)
        try:
            return self.s.recv(65536).decode("latin1")
        except socket.timeout:
            return ""

    def lire(self, debut, longueur):
        """Lit la memoire de l'emulateur, une tranche a la fois.

        Le moniteur fait preceder ses reponses de l'invite de la commande
        precedente : attendre une invite decalerait tout le dialogue. On
        demande donc une tranche, puis on collecte les lignes
        ">C:adresse octets..." jusqu'a l'avoir couverte. Chaque octet etant
        range a l'adresse qu'il annonce, les reponses en retard se placent
        d'elles-memes et ne genent pas.
        """
        octets = {}
        adresse = debut
        restant = longueur
        while restant > 0:
            paquet = min(restant, 128)
            attendus = set(range(adresse, adresse + paquet))
            self.s.sendall(("m %04x %04x\n" % (adresse, adresse + paquet - 1))
                           .encode("latin1"))
            tampon = ""
            limite = time.time() + 20
            while time.time() < limite and not attendus <= set(octets):
                try:
                    bloc = self.s.recv(65536)
                except socket.timeout:
                    break
                if not bloc:
                    break
                tampon += bloc.decode("latin1")
                morceaux = tampon.split("\n")
                tampon = morceaux.pop()
                for ligne in morceaux:
                    for trouve in re.finditer(
                            r">C:([0-9a-fA-F]{4})\s\s([0-9a-fA-F ]+)", ligne):
                        base = int(trouve.group(1), 16)
                        hexa = re.split(r"\s{3,}", trouve.group(2))[0]
                        for rang, mot in enumerate(hexa.split()):
                            if len(mot) == 2:
                                octets[base + rang] = int(mot, 16)
            adresse += paquet
            restant -= paquet
        manquants = sorted(set(range(debut, debut + longueur)) - set(octets))
        if manquants:
            raise IOError("lecture incomplete : %d octet(s) absents a partir de $%04X"
                          % (len(manquants), manquants[0]))
        return [octets[debut + i] for i in range(longueur)]

    def fermer(self):
        try:
            self.s.sendall(b"quit\n")
        except OSError:
            pass
        self.s.close()


def executer(prg, taille_lecture):
    """Lance VICE, attend la fin du calcul, et rapporte la zone de sortie."""
    journal = os.path.join(RACINE, "vice_test.log")
    processus = subprocess.Popen(
        ["xpet", "-model", "8296", "-autostart", prg,
         "-remotemonitor", "-remotemonitoraddress", "ip4://127.0.0.1:%d" % PORT,
         "-warp", "+sound"],
        stdout=open(journal, "w"), stderr=subprocess.STDOUT)
    try:
        # laisse le temps au chargement puis au calcul
        time.sleep(14)
        mon = Moniteur(PORT)
        drapeau = mon.lire(DRAPEAU, 1)
        essais = 0
        # une recherche profonde peut occuper la machine plusieurs minutes
        while (not drapeau or drapeau[0] != 0x42) and essais < 120:
            mon.commande("x")        # rend la main a l'emulation
            time.sleep(3)
            drapeau = mon.lire(DRAPEAU, 1)
            essais += 1
        if not drapeau or drapeau[0] != 0x42:
            mon.fermer()
            return None
        # le programme a depose la longueur exacte : inutile de deviner,
        # et on ne risque pas de lire au-dela de ce qui a ete ecrit
        petit = mon.lire(TAILLE_TOT, 2)
        taille = petit[0] | (petit[1] << 8)
        if taille == 0 or taille > taille_lecture:
            mon.fermer()
            raise IOError("sortie de %d octets, au-dela des %d prevus : "
                          "reduire le nombre de positions par lot"
                          % (taille, taille_lecture))
        donnees = mon.lire(SORTIE, taille)
        mon.fermer()
        return donnees
    finally:
        processus.terminate()
        try:
            processus.wait(timeout=10)
        except subprocess.TimeoutExpired:
            processus.kill()


# ---------------------------------------------------------------------------
#  Comparaison
# ---------------------------------------------------------------------------
def decoder(donnees, nombre):
    """Decoupe la zone de sortie en une liste de coups par position."""
    resultats = []
    i = 0
    for _ in range(nombre):
        if i + 3 > len(donnees):
            resultats.append(None)
            continue
        nb_coups = donnees[i]
        taille = donnees[i + 1] | (donnees[i + 2] << 8)
        i += 3
        bloc = donnees[i:i + taille]
        i += taille
        coups = []
        j = 0
        for _ in range(nb_coups):
            if j + 3 > len(bloc):
                break
            depart, arrivee, nb = bloc[j], bloc[j + 1], bloc[j + 2]
            prises = bloc[j + 3:j + 3 + nb]
            j += 3 + nb
            coups.append((depart, arrivee, frozenset(prises)))
        # plateau obtenu apres application du premier coup
        plateau = None
        if i < len(donnees):
            present = donnees[i]
            i += 1
            if present:
                plateau = donnees[i:i + 50]
                i += 50
        resultats.append((coups, plateau))
    return resultats


def attendus(pl, trait):
    return set(c.cle() for c in coups_legaux(pl, trait))


def main():
    bavard = "-v" in sys.argv
    nb_alea = 40
    if "-n" in sys.argv:
        nb_alea = int(sys.argv[sys.argv.index("-n") + 1])

    positions = positions_construites() + positions_aleatoires(nb_alea)

    prg = os.path.join(RACINE, "test_coups.prg")

    print("%d positions a verifier, par lots de %d..."
          % (len(positions), POSITIONS_PAR_LOT))
    obtenus = []
    for debut in range(0, len(positions), POSITIONS_PAR_LOT):
        lot = positions[debut:debut + POSITIONS_PAR_LOT]
        ecrire_positions(lot, os.path.join(RACINE, "test_positions.asm"))
        assemblage = subprocess.run(
            ["64tass", "--cbm-prg", "-o", prg, "test_coups.asm"],
            cwd=RACINE, capture_output=True, text=True)
        if assemblage.returncode != 0:
            print(assemblage.stdout + assemblage.stderr)
            return 1
        donnees = executer(prg, 5632)
        if donnees is None:
            print("ECHEC : le programme de test ne s'est pas termine dans VICE")
            return 1
        obtenus += decoder(donnees, len(lot))
        print("   lot %d-%d traite" % (debut + 1, debut + len(lot)))

    echecs = 0
    for (nom, pl, trait), (coups, apres_coup) in zip(positions, obtenus):
        voulu = attendus(pl, trait)
        eu = set(coups) if coups is not None else None
        if eu == voulu and voulu:
            # le premier coup de la liste 6502 doit donner le meme plateau
            # que le meme coup joue par le prototype de reference
            premier = coups[0]
            modele = None
            for c in coups_legaux(pl, trait):
                if c.cle() == premier:
                    modele = [jouer(pl, c)[NUM_VERS_IDX[n]] for n in range(1, 51)]
                    break
            if modele is not None and apres_coup is not None and list(apres_coup) != modele:
                echecs += 1
                print("ECHEC  %s : plateau errone apres %s" % (nom, _texte(premier)))
                print("   attendu : %s" % " ".join(str(v) for v in modele))
                print("   obtenu  : %s" % " ".join(str(v) for v in apres_coup))
                print()
                continue
        if eu != voulu:
            echecs += 1
            print("ECHEC  %s (trait aux %s)" % (nom, "Blancs" if trait == BLANC else "Noirs"))
            print(afficher(pl))
            manquants = voulu - (eu or set())
            en_trop = (eu or set()) - voulu
            if manquants:
                print("   absents du 6502 : %s" % " ".join(_texte(c) for c in sorted(manquants)))
            if en_trop:
                print("   en trop dans le 6502 : %s" % " ".join(_texte(c) for c in sorted(en_trop)))
            print()
        elif bavard:
            print("ok     %-28s %d coup(s)" % (nom, len(voulu)))
    print()
    print("%d position(s), %d echec(s)" % (len(positions), echecs))
    return 1 if echecs else 0


def _texte(cle):
    depart, arrivee, prises = cle
    if prises:
        return "%dx%d(%s)" % (depart, arrivee, ",".join(str(p) for p in sorted(prises)))
    return "%d-%d" % (depart, arrivee)


if __name__ == "__main__":
    sys.exit(main())

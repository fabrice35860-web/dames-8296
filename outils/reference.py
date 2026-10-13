#!/usr/bin/env python3
"""Prototype de reference des regles du jeu de dames internationales.

Sert d'oracle : les coups produits par le code 6502 doivent etre exactement
ceux que genere ce module, sur toutes les positions de test.

La representation interne est la meme que celle du programme 6502, pour que
les deux raisonnent sur les memes indices : un plateau de 12x12 = 144 cases
avec une bordure d'une case tout autour, de sorte que les quatre directions
diagonales soient des decalages constants.

    case (r,c), r et c de 0 a 9  ->  index = 12*r + c + 13
    haut-gauche -13, haut-droit -11, bas-gauche +11, bas-droit +13

Les Noirs occupent les cases 1 a 20 (en haut), les Blancs les cases 31 a 50
(en bas). Les Blancs avancent vers les rangees decroissantes.
"""

VIDE, PION_B, DAME_B, PION_N, DAME_N = 0, 1, 2, 3, 4
BORD = 255

HG, HD, BG, BD = -13, -11, 11, 13
DIRECTIONS = (HG, HD, BG, BD)

BLANC, NOIR = 0, 1

BLANCHES = (PION_B, DAME_B)
NOIRES = (PION_N, DAME_N)
PIONS = (PION_B, PION_N)
DAMES = (DAME_B, DAME_N)


# ---------------------------------------------------------------------------
#  Conversions entre numerotation officielle (1..50) et index interne
# ---------------------------------------------------------------------------
def rc_depuis_num(n):
    r = (n - 1) // 5
    c = 2 * ((n - 1) % 5) + (1 if r % 2 == 0 else 0)
    return r, c


NUM_VERS_IDX = [0] * 51
IDX_VERS_NUM = [0] * 144
for _n in range(1, 51):
    _r, _c = rc_depuis_num(_n)
    _i = 12 * _r + _c + 13
    NUM_VERS_IDX[_n] = _i
    IDX_VERS_NUM[_i] = _n

# Derniere rangee de chaque camp, ou un pion qui s'arrete devient dame.
ARRIVEE_BLANC = set(NUM_VERS_IDX[n] for n in range(1, 6))
ARRIVEE_NOIR = set(NUM_VERS_IDX[n] for n in range(46, 51))


# ---------------------------------------------------------------------------
#  Construction d'un plateau
# ---------------------------------------------------------------------------
def plateau_vide():
    pl = [BORD] * 144
    for n in range(1, 51):
        pl[NUM_VERS_IDX[n]] = VIDE
    return pl


def plateau_depuis(cases):
    """cases : dictionnaire numero -> piece. Les autres cases sont vides."""
    pl = plateau_vide()
    for n, piece in cases.items():
        pl[NUM_VERS_IDX[n]] = piece
    return pl


def plateau_initial():
    cases = {}
    for n in range(1, 21):
        cases[n] = PION_N
    for n in range(31, 51):
        cases[n] = PION_B
    return plateau_depuis(cases)


def camp_de(piece):
    if piece in BLANCHES:
        return BLANC
    if piece in NOIRES:
        return NOIR
    return None


# ---------------------------------------------------------------------------
#  Generation des coups
# ---------------------------------------------------------------------------
class Coup:
    """Un coup legal : depart, arrivee, pieces prises, promotion eventuelle.

    Deux rafles qui prennent les memes pieces et finissent sur la meme case
    sont le meme coup, quel que soit le chemin suivi : l'egalite ne porte
    donc que sur (depart, arrivee, prises).
    """

    __slots__ = ("depart", "arrivee", "prises", "promotion")

    def __init__(self, depart, arrivee, prises, promotion):
        self.depart = depart
        self.arrivee = arrivee
        self.prises = frozenset(prises)
        self.promotion = promotion

    def cle(self):
        return (self.depart, self.arrivee, self.prises)

    def __eq__(self, autre):
        return self.cle() == autre.cle()

    def __hash__(self):
        return hash(self.cle())

    def __repr__(self):
        if self.prises:
            texte = "%dx%d" % (self.depart, self.arrivee)
            texte += "(%s)" % ",".join(str(p) for p in sorted(self.prises))
        else:
            texte = "%d-%d" % (self.depart, self.arrivee)
        return texte + ("D" if self.promotion else "")


def coups_legaux(pl, trait):
    """Tous les coups legaux du camp au trait, prise majoritaire appliquee."""
    rafles = []
    for idx in range(144):
        if camp_de(pl[idx]) == trait:
            _explorer(pl, idx, pl[idx], idx, [], rafles)
    if rafles:
        maxi = max(len(c.prises) for c in rafles)
        gardees = [c for c in rafles if len(c.prises) == maxi]
        # deux chemins menant au meme resultat ne font qu'un seul coup
        uniques = {}
        for c in gardees:
            uniques[c.cle()] = c
        return sorted(uniques.values(), key=lambda c: (c.depart, c.arrivee, sorted(c.prises)))
    return _deplacements_simples(pl, trait)


def _libre(pl, case, depart):
    """Une case est franchissable si elle est vide, ou si c'est la case de
    depart de la piece qui rafle : celle-ci l'a quittee des le debut."""
    return pl[case] == VIDE or case == depart


def _prenable(pl, case, capturees, trait):
    """Une piece adverse pas encore prise. Les pieces deja prises restent sur
    le plateau jusqu'a la fin de la rafle : elles bloquent le passage, mais
    ne peuvent pas etre sautees une seconde fois."""
    if case in capturees:
        return False
    camp = camp_de(pl[case])
    return camp is not None and camp != trait


def _explorer(pl, depart, piece, courant, capturees, resultats):
    """Parcourt toutes les rafles possibles depuis la case courante."""
    trait = camp_de(piece)
    suites = []

    if piece in PIONS:
        # le pion prend dans les quatre directions, en avant comme en arriere
        for d in DIRECTIONS:
            saute = courant + d
            arrivee = saute + d
            if _prenable(pl, saute, capturees, trait) and _libre(pl, arrivee, depart):
                suites.append((arrivee, saute))
    else:
        # dame volante : elle prend a distance et s'arrete ou elle veut
        # derriere la piece prise
        for d in DIRECTIONS:
            case = courant + d
            while _libre(pl, case, depart):
                case += d
            if _prenable(pl, case, capturees, trait):
                arrivee = case + d
                while _libre(pl, arrivee, depart):
                    suites.append((arrivee, case))
                    arrivee += d

    if not suites:
        if capturees:
            resultats.append(_fabriquer(pl, depart, courant, capturees, piece))
        return

    for arrivee, prise in suites:
        _explorer(pl, depart, piece, arrivee, capturees + [prise], resultats)


def _fabriquer(pl, depart, arrivee, capturees, piece):
    """Un pion n'est promu que s'il termine son coup sur la derniere rangee :
    le traverser pendant une rafle ne suffit pas."""
    promotion = False
    if piece == PION_B and arrivee in ARRIVEE_BLANC:
        promotion = True
    if piece == PION_N and arrivee in ARRIVEE_NOIR:
        promotion = True
    return Coup(IDX_VERS_NUM[depart], IDX_VERS_NUM[arrivee],
                [IDX_VERS_NUM[c] for c in capturees], promotion)


def _deplacements_simples(pl, trait):
    coups = []
    for idx in range(144):
        piece = pl[idx]
        if camp_de(piece) != trait:
            continue
        if piece in PIONS:
            avance = (HG, HD) if piece == PION_B else (BG, BD)
            for d in avance:
                if pl[idx + d] == VIDE:
                    coups.append(_fabriquer(pl, idx, idx + d, [], piece))
        else:
            for d in DIRECTIONS:
                case = idx + d
                while pl[case] == VIDE:
                    coups.append(_fabriquer(pl, idx, case, [], piece))
                    case += d
    return sorted(coups, key=lambda c: (c.depart, c.arrivee))


# ---------------------------------------------------------------------------
#  Application d'un coup (utile pour derouler une partie)
# ---------------------------------------------------------------------------
def jouer(pl, coup):
    """Retourne un nouveau plateau, le coup etant joue."""
    nouveau = list(pl)
    piece = nouveau[NUM_VERS_IDX[coup.depart]]
    nouveau[NUM_VERS_IDX[coup.depart]] = VIDE
    for n in coup.prises:
        nouveau[NUM_VERS_IDX[n]] = VIDE
    if coup.promotion:
        piece = DAME_B if piece == PION_B else DAME_N
    nouveau[NUM_VERS_IDX[coup.arrivee]] = piece
    return nouveau


def afficher(pl):
    """Rendu texte du plateau, pour inspecter une position de test."""
    symboles = {VIDE: ".", PION_B: "b", DAME_B: "B", PION_N: "n", DAME_N: "N"}
    lignes = []
    for r in range(10):
        ligne = []
        for c in range(10):
            idx = 12 * r + c + 13
            ligne.append(symboles[pl[idx]] if (r + c) % 2 else " ")
        lignes.append("%2d %s" % (r, " ".join(ligne)))
    return "\n".join(lignes)


if __name__ == "__main__":
    pl = plateau_initial()
    coups = coups_legaux(pl, BLANC)
    print(afficher(pl))
    print()
    print("position de depart, trait aux Blancs : %d coups" % len(coups))
    print("  " + "  ".join(str(c) for c in coups))

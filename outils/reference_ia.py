#!/usr/bin/env python3
"""Reference de l'evaluation et de la recherche, pour juger le code 6502.

Reproduit exactement le bareme et l'algorithme de ia.asm : meme valeurs de
pieces, memes tables de bonus, meme negamax alpha-beta parcourant les coups
dans l'ordre ou le generateur les produit. Les scores doivent coincider au
point pres, sans quoi c'est qu'un des deux se trompe.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reference import (coups_legaux, jouer, NUM_VERS_IDX, rc_depuis_num,   # noqa: E402
                       PION_B, DAME_B, PION_N, DAME_N, BLANC, NOIR)

VAL_PION = 100
VAL_DAME = 300
SCORE_MAT = 30000
SCORE_INF = 32000


def bonus_pion(n):
    r, c = rc_depuis_num(n)
    valeur = (9 - r) * 2
    if 2 <= c <= 7:
        valeur += 2
    if n >= 46:
        valeur += 3
    return valeur


def bonus_dame(n):
    r, c = rc_depuis_num(n)
    return 4 if (2 <= c <= 7 and 2 <= r <= 7) else 0


BONUS_PION = [bonus_pion(n) for n in range(1, 51)]
BONUS_DAME = [bonus_dame(n) for n in range(1, 51)]


def evaluer(pl, trait):
    """Note la position du point de vue du camp au trait."""
    score = 0
    for n in range(1, 51):
        piece = pl[NUM_VERS_IDX[n]]
        if piece == PION_B:
            score += VAL_PION + BONUS_PION[n - 1]
        elif piece == DAME_B:
            score += VAL_DAME + BONUS_DAME[n - 1]
        elif piece == PION_N:
            score -= VAL_PION + BONUS_PION[50 - n]
        elif piece == DAME_N:
            score -= VAL_DAME + BONUS_DAME[50 - n]
    return score if trait == BLANC else -score


def alphabeta(pl, trait, profondeur, alpha, beta, niveau=0):
    """Negamax avec elagage, dans l'ordre de generation des coups."""
    if profondeur == 0:
        return evaluer(pl, trait)
    coups = coups_legaux(pl, trait)
    if not coups:
        # perdre tard vaut mieux que perdre tot
        return -(SCORE_MAT - niveau)
    for coup in coups:
        suivant = jouer(pl, coup)
        score = -alphabeta(suivant, 1 - trait, profondeur - 1,
                           -beta, -alpha, niveau + 1)
        if score > alpha:
            alpha = score
            if alpha >= beta:
                break
    return alpha


def meilleur_coup(pl, trait, profondeur):
    """Retourne (score, coup retenu) a la racine, premier coup a egalite."""
    coups = coups_legaux(pl, trait)
    if not coups:
        # pas de coup a la racine : la partie est perdue, et c'est bien
        # cette valeur qu'il faut rendre, non la borne de la fenetre
        return -SCORE_MAT, None
    alpha = -SCORE_INF
    retenu = None
    for coup in coups:
        suivant = jouer(pl, coup)
        score = -alphabeta(suivant, 1 - trait, profondeur - 1,
                           -SCORE_INF, -alpha, 1)
        if score > alpha:
            alpha = score
            retenu = coup
    return alpha, retenu

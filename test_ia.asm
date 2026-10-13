; =====================================================================
;  test_ia.asm - banc d'essai de l'evaluation et de la recherche
;
;  Pour chaque position de la batterie, depose :
;    2 octets : evaluation de la position
;    2 octets : score rendu par la recherche
;    1 octet  : case de depart du coup retenu (0 si aucun)
;    1 octet  : case d'arrivee
;    2 octets : temps mis par la recherche, en images
;
;  Assemblage : 64tass --cbm-prg -o test_ia.prg test_ia.asm
; =====================================================================

.include "constantes.asm"

SORTIE      = $6900  ; au-dela de la pile d'annulation de partie
DRAPEAU     = $68FF
TAILLE_TOT  = $68FD

ptr_sortie  = $C4
ptr_pos     = $C6

* = $0401
        .word fin_basic
        .word 10
        .byte $9E
        .text "1040"
        .byte 0
fin_basic
        .word 0
        .fill $0410-*, 0

* = $0410
debut
        lda #0
        sta DRAPEAU
        jsr effacer_marques
        lda #<SORTIE
        sta ptr_sortie
        lda #>SORTIE
        sta ptr_sortie+1
        lda #<positions
        sta ptr_pos
        lda #>positions
        sta ptr_pos+1
        lda nb_positions
        sta compteur
boucle_pos
        jsr charger_position
        ; --- evaluation ---
        jsr evaluer
        lda score_lo
        jsr deposer
        lda score_hi
        jsr deposer
        ; --- recherche ---
        lda TI_MOYEN
        sta t_avant_h
        lda TI_BAS
        sta t_avant_b
.if UTILISER_TABLE
        jsr vider_table     ; chaque position repart d'une table vierge
.endif
        lda profondeur
        jsr chercher_meilleur_coup
        lda score_lo
        jsr deposer
        lda score_hi
        jsr deposer
        ; --- coup retenu ---
        lda meilleur_lo
        ora meilleur_hi
        beq bp_aucun
        lda meilleur_lo
        sta ptr_coup
        lda meilleur_hi
        sta ptr_coup+1
        ldy #0
        lda (ptr_coup),y
        jsr deposer
        ldy #1
        lda (ptr_coup),y
        jsr deposer
        jmp bp_temps
bp_aucun
        lda #0
        jsr deposer
        jsr deposer
bp_temps
        lda TI_MOYEN
        sec
        sbc t_avant_h
        sta tps_haut
        lda TI_BAS
        sec
        sbc t_avant_b
        jsr deposer
        lda tps_haut
        jsr deposer
        ; --- la clef doit etre revenue a sa valeur : le hachage est tenu
        ;     a jour au fil des coups, et doit se defaire aussi bien ---
        lda cle_lo
        jsr deposer
        lda cle_hi
        jsr deposer
        jsr calculer_cle
        lda cle_lo
        jsr deposer
        lda cle_hi
        jsr deposer
        ; --- le plateau doit etre intact : la recherche joue et defait ---
        ldx #0
bp_plateau
        stx pz_tmp
        ldy num_vers_idx,x
        lda plateau,y
        jsr deposer
        ldx pz_tmp
        inx
        cpx #50
        bne bp_plateau

        dec compteur
        beq +
        jmp boucle_pos
+       lda ptr_sortie
        sec
        sbc #<SORTIE
        sta TAILLE_TOT
        lda ptr_sortie+1
        sbc #>SORTIE
        sta TAILLE_TOT+1
        lda #$42
        sta DRAPEAU
fini
        jmp fini

deposer
        ldy #0
        sta (ptr_sortie),y
        inc ptr_sortie
        bne +
        inc ptr_sortie+1
+       rts

effacer_marques
        lda #0
        ldx #0
-       sta marques,x
        inx
        cpx #144
        bne -
        rts

charger_position
        lda #BORD
        ldx #0
-       sta plateau,x
        inx
        cpx #144
        bne -
        ldy #0
        lda (ptr_pos),y
        sta trait
        ldx #0
cp_case
        iny
        lda (ptr_pos),y
        sty pz_tmp
        ldy num_vers_idx,x
        sta plateau,y
        ldy pz_tmp
        inx
        cpx #50
        bne cp_case
        lda ptr_pos
        clc
        adc #51
        sta ptr_pos
        bcc +
        inc ptr_pos+1
+       rts

compteur    .byte 0
t_avant_h   .byte 0
t_avant_b   .byte 0
tps_haut      .byte 0
profondeur  .byte 2         ; remplace par le pilote

.include "coups.asm"
.include "ia.asm"
.include "donnees.asm"
.include "donnees_tables.asm"
.include "test_positions.asm"

.cerror * > DEBUT_ZONES, "le banc deborde sur les zones de travail"

; =====================================================================
;  test_vitesse.asm - mesure le cout du generateur de coups
;
;  Genere NB_TOURS fois les coups de chaque position de la batterie et
;  depose, pour chacune, le temps ecoule lu sur l'horloge systeme.
;  Sert a dimensionner la recherche : sur un 6502 a 1 MHz, c'est le cout
;  d'un noeud qui fixe la profondeur atteignable.
;
;  Assemblage : 64tass --cbm-prg -o test_vitesse.prg test_vitesse.asm
; =====================================================================

.include "constantes.asm"

SORTIE      = $6900  ; au-dela de la pile d'annulation de partie
DRAPEAU     = $68FF
TAILLE_TOT  = $68FD         ; longueur deposee, lue par le pilote
NB_TOURS    = 50            ; generations par position

TI_HAUT     = $8D           ; horloge systeme, poids fort
ptr_sortie  = $C0
ptr_pos     = $C2

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
        ; --- horloge avant ---
        jsr deposer_horloge
        ; --- NB_TOURS generations ---
        lda #NB_TOURS
        sta tours
bt_tour
        jsr generer_coups
        dec tours
        bne bt_tour
        ; --- horloge apres ---
        jsr deposer_horloge
        ; --- nombre de coups trouves, pour verifier qu'on mesure bien ---
        ldy #0
        lda nb_coups
        sta (ptr_sortie),y
        jsr avancer_sortie
        dec compteur
        bne boucle_pos
        lda ptr_sortie
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

; ---------------------------------------------------------------------
;  deposer_horloge : recopie les trois octets de l'horloge systeme
; ---------------------------------------------------------------------
deposer_horloge
        ldy #0
        lda TI_HAUT
        sta (ptr_sortie),y
        jsr avancer_sortie
        ldy #0
        lda TI_MOYEN
        sta (ptr_sortie),y
        jsr avancer_sortie
        ldy #0
        lda TI_BAS
        sta (ptr_sortie),y
        jmp avancer_sortie

avancer_sortie
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
tours       .byte 0

.include "coups.asm"
.include "donnees.asm"
.include "donnees_tables.asm"
.include "test_positions.asm"

.cerror * > DEBUT_ZONES, "le banc deborde sur les zones de travail"

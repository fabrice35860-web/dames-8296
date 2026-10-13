; =====================================================================
;  test_coups.asm - banc d'essai du generateur de coups
;
;  Ne sert qu'aux tests : il deroule une batterie de positions, genere
;  les coups de chacune et depose les resultats en $3000, ou le pilote
;  outils/test_coups.py vient les lire par le moniteur de VICE pour les
;  comparer au prototype de reference.
;
;  Assemblage : 64tass --cbm-prg -o test_coups.prg test_coups.asm
; =====================================================================

.include "constantes.asm"

SORTIE      = $6900  ; au-dela de la pile d'annulation de partie         ; zone de resultats lue par le pilote
DRAPEAU     = $68FF         ; passe a $42 quand tout est termine
TAILLE_TOT  = $68FD         ; longueur reellement deposee en sortie

; Pointeurs propres au banc d'essai. Ils sont places au-dela de la zone
; du jeu ($B0..$BF), que le moteur utilise : ptr_coup occupe $B9/$BA.
; Le sondage de l'etape 1 a montre $B0..$CA intacts sous interruption.
ptr_sortie  = $C0
ptr_pos     = $C2
ptr_src     = $C4

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
        jsr generer_coups
        jsr copier_resultat
        jsr copier_plateau_apres
        dec compteur
        bne boucle_pos
        ; longueur deposee, pour que le pilote sache exactement quoi lire
        lda ptr_sortie
        sec
        sbc #<SORTIE
        sta TAILLE_TOT
        lda ptr_sortie+1
        sbc #>SORTIE
        sta TAILLE_TOT+1
        lda #$42
        sta DRAPEAU         ; le pilote peut lire
fini
        jmp fini

; ---------------------------------------------------------------------
;  effacer_marques : aucune piece n'est prise au depart
; ---------------------------------------------------------------------
effacer_marques
        lda #0
        ldx #0
-       sta marques,x
        inx
        cpx #144
        bne -
        rts

; ---------------------------------------------------------------------
;  charger_position : installe la position pointee par ptr_pos
;  Format : 1 octet de trait, puis le contenu des cases 1 a 50.
; ---------------------------------------------------------------------
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

; ---------------------------------------------------------------------
;  copier_resultat : depose dans la zone de sortie le nombre de coups,
;  la longueur des donnees, puis les donnees elles-memes
; ---------------------------------------------------------------------
copier_resultat
        ldy #0
        lda nb_coups
        sta (ptr_sortie),y
        ; longueur utilisee de coups_zone
        lda coups_fin
        sec
        sbc #<coups_zone
        sta taille_lo
        lda coups_fin+1
        sbc #>coups_zone
        sta taille_hi
        iny
        lda taille_lo
        sta (ptr_sortie),y
        iny
        lda taille_hi
        sta (ptr_sortie),y
        lda ptr_sortie
        clc
        adc #3
        sta ptr_sortie
        bcc +
        inc ptr_sortie+1
+       lda #<coups_zone
        sta ptr_src
        lda #>coups_zone
        sta ptr_src+1
cr_copie
        lda taille_lo
        ora taille_hi
        beq cr_fin
        ldy #0
        lda (ptr_src),y
        sta (ptr_sortie),y
        inc ptr_src
        bne +
        inc ptr_src+1
+       inc ptr_sortie
        bne +
        inc ptr_sortie+1
+       lda taille_lo
        bne +
        dec taille_hi
+       dec taille_lo
        jmp cr_copie
cr_fin
        rts

; ---------------------------------------------------------------------
;  copier_plateau_apres : joue le premier coup de la liste, s'il existe,
;  et depose les 50 cases du plateau obtenu. C'est ainsi qu'on verifie le
;  retrait des pieces prises et la promotion.
;  Depose un octet de presence (0 ou 1) suivi, le cas echeant, des 50 cases.
; ---------------------------------------------------------------------
copier_plateau_apres
        ldy #0
        lda nb_coups
        beq cpa_aucun
        lda #1
        sta (ptr_sortie),y
        jsr avancer_sortie
        lda #0
        jsr appliquer_coup
        ldx #0
cpa_case
        stx pz_tmp
        ldy num_vers_idx,x
        lda plateau,y
        ldy #0
        sta (ptr_sortie),y
        jsr avancer_sortie
        ldx pz_tmp
        inx
        cpx #50
        bne cpa_case
        rts
cpa_aucun
        lda #0
        sta (ptr_sortie),y
        ; fallthrough

avancer_sortie
        inc ptr_sortie
        bne +
        inc ptr_sortie+1
+       rts

compteur    .byte 0
taille_lo   .byte 0
taille_hi   .byte 0

.include "coups.asm"
.include "donnees.asm"
.include "donnees_tables.asm"
.include "test_positions.asm"

.cerror * > DEBUT_ZONES, "le banc deborde sur les zones de travail"

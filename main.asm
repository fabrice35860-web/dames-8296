; =====================================================================
;  Jeu de dames internationales pour Commodore 8296
;  main.asm - amorce BASIC, initialisation et boucle principale
;
;  Etape 1 : affichage complet et saisie d'un coup au clavier, sans
;  verification des regles.
;
;  Assemblage :  64tass --cbm-prg -o dames.prg main.asm
;  Lancement  :  LOAD"DAMES",8  puis  RUN
; =====================================================================

.include "constantes.asm"

; ---------------------------------------------------------------------
;  Amorce BASIC : 10 SYS1040 ($0410)
; ---------------------------------------------------------------------
* = $0401
        .word basic_fin     ; lien vers la ligne suivante
        .word 10            ; numero de ligne
        .byte $9E           ; token SYS
        .text "1040"
        .byte 0             ; fin de ligne
basic_fin
        .word 0             ; fin de programme
        .fill $0410-*, 0    ; bourrage jusqu'au point d'entree

; ---------------------------------------------------------------------
;  Point d'entree
; ---------------------------------------------------------------------
* = $0410
debut
        jsr sauver_pz
        jsr effacer_marques
        ; le jeu de caracteres d'abord : tout l'affichage en depend
        jsr detecter_rom
        jsr appliquer_rom
        jsr choix_rom
nouvelle_depuis_menu
        jsr menu
        lda demande_fin
        bne sortie_jeu
        jsr init_ecran
        jsr afficher_fixes
        jsr dessiner_legende
        jsr nouvelle_partie
        lda #<t_m_nouvelle
        ldx #>t_m_nouvelle
        jsr message

; ---------------------------------------------------------------------
;  Boucle principale : clignotements puis lecture du clavier
; ---------------------------------------------------------------------
boucle
        jsr tour_ordinateur
        jsr clignoter
        jsr GETIN
        beq bc_suite
        jsr traiter_touche
bc_suite
        lda retour_menu
        beq +
        lda #0
        sta retour_menu
        jmp nouvelle_depuis_menu
+       lda demande_fin
        beq boucle
sortie_jeu

; ---------------------------------------------------------------------
;  Sortie : on rend la machine dans l'etat ou on l'a trouvee
; ---------------------------------------------------------------------
        jsr rendre_pz
        lda #MODE_MINUS
        sta REG_CARACT
        ; on passe par l'editeur plutot que d'effacer la RAM ecran a la main :
        ; cela replace aussi son curseur, sans quoi le BASIC ecrirait son
        ; "ready." n'importe ou.
        lda #PET_EFFACER
        jsr CHROUT
        rts                 ; retour au BASIC (SYS a empile l'adresse)

; ---------------------------------------------------------------------
;  sauver_pz / rendre_pz : emprunt de la fin de la page zero
; ---------------------------------------------------------------------
sauver_pz
        ldx #PZ_NOMBRE-1
-       lda PZ_BASE,x
        sta sauvegarde_pz,x
        dex
        bpl -
        rts

rendre_pz
        ldx #PZ_NOMBRE-1
-       lda sauvegarde_pz,x
        sta PZ_BASE,x
        dex
        bpl -
        rts

; ---------------------------------------------------------------------
;  effacer_marques : aucune piece n'est prise au depart
; ---------------------------------------------------------------------
effacer_marques
        lda #0
        ldx #0
        ; on compte en montant : 143 a son bit de signe a 1, une boucle
        ; terminee par BPL s'arreterait des le premier tour
-       sta marques,x
        inx
        cpx #144
        bne -
        rts

; ---------------------------------------------------------------------
;  afficher_fixes : bandeaux en video inverse puis textes immuables
; ---------------------------------------------------------------------
afficher_fixes
        ; bandeau de titre sur toute la ligne 0
        lda #LIG_TITRE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #LARGEUR
        jsr remplir
        ; bandeaux des deux en-tetes du panneau
        lda #7
        jsr bandeau_panneau
        lda #13
        jsr bandeau_panneau
        ; textes fixes decrits par la table
        lda #<textes_fixes
        sta ptr_aux
        lda #>textes_fixes
        sta ptr_aux+1
        jmp afficher_table

bandeau_panneau
        ldx #PAN_X
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #PAN_L
        jmp remplir

; ---------------------------------------------------------------------
;  dessiner_legende : les quatre exemples de pieces du panneau,
;  chacun pose sur un fond de case foncee comme sur le damier
; ---------------------------------------------------------------------
dessiner_legende
        ldx #0
dl_boucle
        lda legende_pieces,x
        cmp #$FF
        beq dl_fin
        sta tmp_ligne
        inx
        lda legende_pieces,x
        sta tmp_car
        inx
        stx tmp_index
        lda tmp_ligne
        ldx #PAN_X
        jsr pos_ecran
        ; fond de case foncee, 5 x 2 caracteres
        lda #CAR_ESP_INV
        ldy #CASE_L-1
-       sta (ptr_ecran),y
        dey
        bpl -
        ldy #LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #LARGEUR-1
        bne -
        lda tmp_car
        jsr dessiner_piece
        ldx tmp_index
        bne dl_boucle
dl_fin
        rts

; ---------------------------------------------------------------------
;  Modules
; ---------------------------------------------------------------------
.include "son.asm"
.include "ecran_rom.asm"
.include "menu.asm"
.include "coups.asm"
.include "ia.asm"
.include "ecran.asm"
.include "clavier.asm"
.include "regles.asm"
.include "donnees.asm"
.include "donnees_tables.asm"

; ---------------------------------------------------------------------
;  Garde-fou : le programme et ses donnees ne doivent pas rattraper les
;  zones de travail, qui sont a adresse fixe.
; ---------------------------------------------------------------------
.cerror * > DEBUT_ZONES, "le programme deborde sur les zones de travail"

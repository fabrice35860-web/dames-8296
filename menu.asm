; =====================================================================
;  menu.asm - ecran de reglages, affiche au lancement et sur la touche M
;
;  Deux reglages : le niveau, et le camp tenu par le joueur. Aux dames
;  les Blancs commencent toujours : choisir son camp revient donc a
;  decider qui joue en premier, ce que l'ecran rappelle.
; =====================================================================

MENU_COL    = 22            ; colonne des libelles
MENU_VAL    = 40            ; colonne des valeurs
MENU_L_NIV  = 7             ; ligne du reglage de niveau
MENU_L_CAMP = 9             ; ligne du reglage de camp
MENU_L_ROM  = 11            ; ligne du jeu de caracteres

; ---------------------------------------------------------------------
;  menu : boucle de reglages. Rend la main quand la partie doit commencer,
;  ou avec demande_fin a 1 si le joueur quitte.
; ---------------------------------------------------------------------
menu
        lda #MODE_GRAPH
        sta REG_CARACT
        jsr effacer_ecran
        jsr menu_fixe
        lda #0
        sta menu_ligne
mn_redessiner
        jsr dessiner_menu
mn_touche
        jsr GETIN
        beq mn_touche
        cmp #TOUCHE_ESP
        beq mn_go
        cmp #TOUCHE_RET
        beq mn_go
        cmp #TOUCHE_Q
        beq mn_fin
        jmp mn_fleches
mn_go
        jmp mn_commencer
mn_fin
        jmp mn_quitter
mn_fleches
        cmp #T_HAUT
        beq mn_haut
        cmp #T_PAV_HAUT
        beq mn_haut
        cmp #T_BAS
        beq mn_bas
        cmp #T_PAV_BAS
        beq mn_bas
        cmp #T_GAUCHE
        beq mn_moins
        cmp #T_PAV_GAUCHE
        beq mn_moins
        cmp #T_DROITE
        beq mn_plus
        cmp #T_PAV_DROITE
        beq mn_plus
        cmp #TOUCHE_CALIB
        beq mn_calibrer
        jmp mn_touche
mn_calibrer
        ; on revient a l'ecran de comparaison des deux jeux
        jsr choix_rom
        jsr effacer_ecran
        jsr menu_fixe
        jmp mn_redessiner

mn_haut
        lda menu_ligne
        beq mn_redessiner
        dec menu_ligne
        jmp mn_redessiner
mn_bas
        lda menu_ligne
        cmp #2
        bcs mn_redessiner
        inc menu_ligne
        jmp mn_redessiner

mn_moins
        lda menu_ligne
        cmp #2
        beq mn_rom_bascule
        lda menu_ligne
        bne mn_camp_moins
        ; niveau, de 1 a 3
        lda niveau
        cmp #2
        bcc mn_redessiner
        dec niveau
        jmp mn_redessiner
mn_camp_moins
        lda menu_camp
        beq mn_vers_redessin
        dec menu_camp
        jmp mn_poser_camp

mn_rom_bascule
        lda rom_choisie
        eor #1
        sta rom_choisie
        jsr appliquer_rom
        jmp mn_redessiner
mn_vers_redessin
        jmp mn_redessiner

mn_plus
        lda menu_ligne
        cmp #2
        beq mn_rom_bascule
        lda menu_ligne
        bne mn_camp_plus
        lda niveau
        cmp #3
        bcs mn_vers_redessin
        inc niveau
        jmp mn_redessiner
mn_camp_plus
        lda menu_camp
        cmp #2
        bcs mn_vers_redessin
        inc menu_camp
mn_poser_camp
        jsr menu_appliquer_camp
        jmp mn_redessiner

mn_commencer
        rts
mn_quitter
        lda #1
        sta demande_fin
        rts

; ---------------------------------------------------------------------
;  menu_appliquer_camp : traduit le reglage en camp tenu par la machine
;    0 = le joueur a les Blancs, la machine les Noirs
;    1 = le joueur a les Noirs, la machine commence
;    2 = deux joueurs, personne pour la machine
; ---------------------------------------------------------------------
menu_appliquer_camp
        lda menu_camp
        bne mac_noirs
        lda #NOIR
        sta camp_ordi
        rts
mac_noirs
        cmp #1
        bne mac_deux
        lda #BLANC
        sta camp_ordi
        rts
mac_deux
        lda #ORDI_AUCUN
        sta camp_ordi
        rts

; ---------------------------------------------------------------------
;  menu_fixe : le decor, qui ne change pas
; ---------------------------------------------------------------------
menu_fixe
        ; bandeau de titre, comme en partie
        lda #LIG_TITRE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #LARGEUR
        jsr remplir
        lda #<menu_textes
        sta ptr_aux
        lda #>menu_textes
        sta ptr_aux+1
        jmp afficher_table

; ---------------------------------------------------------------------
;  dessiner_menu : les deux reglages, celui qui est pointe en inverse
; ---------------------------------------------------------------------
dessiner_menu
        ; --- niveau ---
        lda #MENU_L_NIV
        sta tmp_ligne
        lda #0
        ldx menu_ligne
        bne +
        lda #INVERSE
+       sta attr_texte
        lda #<t_menu_niveau
        ldx #>t_menu_niveau
        jsr menu_libelle
        ; un seul chiffre : afficher_nb2 mettrait un espace devant
        lda #MENU_L_NIV
        ldx #MENU_VAL
        jsr pos_ecran
        lda niveau
        ora #CAR_ZERO
        ora attr_texte
        ldy #0
        sta (ptr_ecran),y

        ; --- camp du joueur ---
        lda #MENU_L_CAMP
        sta tmp_ligne
        lda #INVERSE
        ldx menu_ligne
        bne +
        lda #0
+       sta attr_texte
        lda #<t_menu_camp
        ldx #>t_menu_camp
        jsr menu_libelle
        ; la valeur, effacee puis reecrite : les trois libelles n'ont pas
        ; la meme longueur
        lda #MENU_L_CAMP
        ldx #MENU_VAL
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #36             ; la plus longue des trois valeurs
        jsr remplir
        ldx menu_camp
        lda menu_camp_lo,x
        sta ptr_texte
        lda menu_camp_hi,x
        sta ptr_texte+1
        lda #MENU_L_CAMP
        ldx #MENU_VAL
        jsr pos_ecran
        jsr afficher_texte
        ; --- jeu de caracteres ---
        lda #MENU_L_ROM
        sta tmp_ligne
        lda #0
        ldx menu_ligne
        cpx #2
        bne +
        lda #INVERSE
+       sta attr_texte
        lda #<t_menu_rom
        ldx #>t_menu_rom
        jsr menu_libelle
        lda #MENU_L_ROM
        ldx #MENU_VAL
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #36
        jsr remplir
        ldx rom_choisie
        lda rom_nom_lo,x
        sta ptr_texte
        lda rom_nom_hi,x
        sta ptr_texte+1
        lda #MENU_L_ROM
        ldx #MENU_VAL
        jsr pos_ecran
        jsr afficher_texte
        lda #0
        sta attr_texte
        rts

; ---------------------------------------------------------------------
;  menu_libelle : ecrit le libelle (A = poids faible, X = poids fort)
;  en colonne MENU_COL de la ligne tmp_ligne
; ---------------------------------------------------------------------
menu_libelle
        sta ptr_texte
        stx ptr_texte+1
        lda tmp_ligne
        ldx #MENU_COL
        jsr pos_ecran
        jmp afficher_texte

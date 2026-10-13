; =====================================================================
;  ecran_rom.asm - choix du jeu de caracteres de la machine
;
;  Le generateur de caracteres de la machine du proprietaire est une
;  EPROM francaise : ses formes graphiques n'ont pas les memes codes que
;  la ROM standard. Comme on ne peut pas deviner a coup sur, on montre
;  un echantillon de chaque et on laisse choisir. La ROM francaise est
;  le choix par defaut.
; =====================================================================

ROM_COL_G   = 10            ; colonne de l'echantillon ROM standard
ROM_COL_D   = 46            ; colonne de l'echantillon ROM francaise
ROM_L_TITRE = 7             ; ligne des deux libelles
ROM_L_ECH   = 9             ; premiere ligne des echantillons

; ---------------------------------------------------------------------
;  appliquer_rom : remplit les variables de forme depuis le prereglage
;  Les variables car_* et accents se suivent en memoire, dans l'ordre du
;  prereglage : une simple recopie suffit.
; ---------------------------------------------------------------------
appliquer_rom
        lda rom_choisie
        beq ar_standard
        lda #<rom_francaise
        ldx #>rom_francaise
        jmp ar_copier
ar_standard
        lda #<rom_standard
        ldx #>rom_standard
ar_copier
        sta ptr_aux
        stx ptr_aux+1
        ldy #0
ar_boucle
        lda (ptr_aux),y
        sta car_arc_hg,y
        iny
        cpy #NB_CAR_ROM+NB_ACCENTS
        bne ar_boucle
        rts

; ---------------------------------------------------------------------
;  detecter_rom : presélectionne un prereglage
;
;  On fait la somme sur 16 bits de toute la ROM de l'editeur ($E000-$E7FF)
;  et on la compare aux empreintes des editeurs standard connus. Celles
;  des versions 50 Hz et 60 Hz se trouvent etre identiques ($528A), ce qui
;  rend la reconnaissance robuste ; VICE charge une variante dont la somme
;  vaut $52AE, egalement admise. Toute autre somme est tenue pour une ROM
;  francaise, ce qui est le defaut voulu : au pire le joueur corrige d'une
;  touche.
; ---------------------------------------------------------------------
detecter_rom
        lda #0
        sta som_lo
        sta som_hi
        sta ptr_aux
        lda #$E0
        sta ptr_aux+1
        ldx #8              ; huit pages de 256 octets
dr_page
        ldy #0
dr_octet
        lda (ptr_aux),y
        clc
        adc som_lo
        sta som_lo
        bcc +
        inc som_hi
+       iny
        bne dr_octet
        inc ptr_aux+1
        dex
        bne dr_page
        ; comparaison aux empreintes connues
        ldx #0
dr_compare
        lda som_lo
        cmp empreintes_lo,x
        bne dr_suivante
        lda som_hi
        cmp empreintes_hi,x
        bne dr_suivante
        lda #0              ; editeur standard reconnu
        sta rom_choisie
        rts
dr_suivante
        inx
        cpx #NB_EMPREINTES
        bne dr_compare
        lda #1              ; inconnu : on presume l'EPROM francaise
        sta rom_choisie
        rts

; ---------------------------------------------------------------------
;  choix_rom : l'ecran de selection. Rend la main sur RETURN.
; ---------------------------------------------------------------------
choix_rom
        lda #MODE_GRAPH
        sta REG_CARACT
        jsr effacer_ecran
        lda #LIG_TITRE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESP_INV
        ldx #LARGEUR
        jsr remplir
        lda #<rom_textes
        sta ptr_aux
        lda #>rom_textes
        sta ptr_aux+1
        jsr afficher_table
        ; les deux echantillons, chacun trace avec son propre prereglage
        lda #0
        sta rom_choisie
        jsr appliquer_rom
        lda #ROM_COL_G
        sta tmp_colonne
        jsr echantillon
        lda #1
        sta rom_choisie
        jsr appliquer_rom
        lda #ROM_COL_D
        sta tmp_colonne
        jsr echantillon
        ; retablit la preselection
        jsr detecter_rom
        jsr appliquer_rom
cr_boucle
        jsr marquer_choix
cr_touche
        jsr GETIN
        beq cr_touche
        cmp #TOUCHE_RET
        beq cr_valider
        cmp #TOUCHE_ESP
        beq cr_valider
        cmp #$31            ; "1"
        beq cr_standard
        cmp #$32            ; "2"
        beq cr_francaise
        jmp cr_touche
cr_standard
        lda #0
        sta rom_choisie
        jsr appliquer_rom
        jmp cr_boucle
cr_francaise
        lda #1
        sta rom_choisie
        jsr appliquer_rom
        jmp cr_boucle
cr_valider
        rts

; ---------------------------------------------------------------------
;  marquer_choix : met en video inverse le libelle retenu
; ---------------------------------------------------------------------
marquer_choix
        lda #0
        ldx rom_choisie
        bne +
        lda #INVERSE
+       sta attr_texte
        lda #<t_rom_standard
        sta ptr_texte
        lda #>t_rom_standard
        sta ptr_texte+1
        lda #ROM_L_TITRE
        ldx #ROM_COL_G
        jsr pos_ecran
        jsr afficher_texte
        lda #INVERSE
        ldx rom_choisie
        bne +
        lda #0
+       sta attr_texte
        lda #<t_rom_francaise
        sta ptr_texte
        lda #>t_rom_francaise
        sta ptr_texte+1
        lda #ROM_L_TITRE
        ldx #ROM_COL_D
        jsr pos_ecran
        jsr afficher_texte
        lda #0
        sta attr_texte
        rts

; ---------------------------------------------------------------------
;  echantillon : un pion blanc, un pion noir et un bout de cadre, traces
;  avec le prereglage actif, a la colonne tmp_colonne
; ---------------------------------------------------------------------
echantillon
        ; --- pion blanc sur sa case foncee ---
        lda #ROM_L_ECH
        sta tmp_ligne
        jsr ech_case
        lda #PION_B
        jsr dessiner_piece
        ; --- pion noir ---
        lda #ROM_L_ECH+2
        sta tmp_ligne
        jsr ech_case
        lda #PION_N
        jsr dessiner_piece
        ; --- un petit cadre ferme, pour juger des traits et des coins ---
        lda #ROM_L_ECH+4
        ldx tmp_colonne
        jsr pos_ecran
        lda car_coin_hg
        ldy #0
        sta (ptr_ecran),y
        lda car_trait_h
        iny
        sta (ptr_ecran),y
        iny
        sta (ptr_ecran),y
        iny
        sta (ptr_ecran),y
        lda car_coin_hd
        iny
        sta (ptr_ecran),y
        lda #ROM_L_ECH+5
        ldx tmp_colonne
        jsr pos_ecran
        lda car_trait_v
        ldy #0
        sta (ptr_ecran),y
        ldy #4
        sta (ptr_ecran),y
        lda #ROM_L_ECH+6
        ldx tmp_colonne
        jsr pos_ecran
        lda car_coin_bg
        ldy #0
        sta (ptr_ecran),y
        lda car_trait_h
        iny
        sta (ptr_ecran),y
        iny
        sta (ptr_ecran),y
        iny
        sta (ptr_ecran),y
        lda car_coin_bd
        iny
        sta (ptr_ecran),y
        rts

; pose une case foncee de 5x2 a (tmp_ligne, tmp_colonne)
ech_case
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        lda #0
        sta attr_case
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
        rts

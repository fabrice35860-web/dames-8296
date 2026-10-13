; =====================================================================
;  son.asm - bruitages et animation des coups
;
;  Le haut-parleur du PET est branche sur CB2 du VIA, que le registre a
;  decalage peut faire osciller tout seul : on regle la hauteur dans le
;  compteur T2 et on laisse tourner. Attention, CB2 commande aussi le
;  jeu de caracteres ($E84C) : il faut le remettre apres chaque son,
;  sinon l'ecran repasse en minuscules.
; =====================================================================

VIA_T2      = $E848         ; compteur T2, poids faible : hauteur du son
VIA_SR      = $E84A         ; registre a decalage
VIA_ACR     = $E84B         ; registre auxiliaire

SR_LIBRE    = $10           ; registre a decalage en roue libre
SR_MOTIF    = $0F           ; motif envoye au haut-parleur

HAUT_DEPLAC = 100           ; son du simple deplacement
HAUT_PRISE  = 190           ; son de la prise, plus grave
DUREE_DEPLAC = 5            ; en images, soit un dixieme de seconde
DUREE_PRISE = 10
TEMPO_PRISE = 25            ; une demi-seconde entre deux prises

; ---------------------------------------------------------------------
;  jouer_son : A = hauteur, X = duree en images
; ---------------------------------------------------------------------
jouer_son
        sta VIA_T2
        stx son_duree
        lda #SR_MOTIF
        sta VIA_SR
        lda #SR_LIBRE
        sta VIA_ACR
        lda son_duree
        jsr attendre
        ; silence, puis on rend CB2 au jeu de caracteres
        lda #0
        sta VIA_ACR
        lda #MODE_GRAPH
        sta REG_CARACT
        rts

son_deplacement
        lda #HAUT_DEPLAC
        ldx #DUREE_DEPLAC
        jmp jouer_son

son_prise
        lda #HAUT_PRISE
        ldx #DUREE_PRISE
        jmp jouer_son

; ---------------------------------------------------------------------
;  attendre : A images d'ecran, soit A cinquantiemes de seconde
; ---------------------------------------------------------------------
attendre
        clc
        adc TI_BAS
        sta att_fin
att_boucle
        lda TI_BAS
        cmp att_fin
        bne att_boucle
        rts

; ---------------------------------------------------------------------
;  animer_coup : montre le coup avant de l'appliquer
;  Entree  ptr_coup pointe le coup, le plateau est encore intact.
;  Les pieces prises sont marquees l'une apres l'autre, dans l'ordre de
;  la rafle, avec une demi-seconde entre chacune : on suit ainsi le
;  trajet de la piece qui mange.
; ---------------------------------------------------------------------
animer_coup
        lda animation
        bne anim_active
        rts                     ; animation coupee : on joue sans attendre
anim_active
        ldy #2
        lda (ptr_coup),y
        sta anim_nb
        bne anim_prises
        jmp son_deplacement     ; simple deplacement : un bip suffit
anim_prises
        ldx #0
anim_boucle
        cpx anim_nb
        beq anim_fin
        stx anim_index
        txa
        clc
        adc #3
        tay
        lda (ptr_coup),y
        sta anim_case
        jsr dessiner_case_prise
        jsr son_prise
        lda #TEMPO_PRISE
        jsr attendre
        ldx anim_index
        inx
        bne anim_boucle
anim_fin
        rts

; ---------------------------------------------------------------------
;  dessiner_case_prise : redessine la piece de la case anim_case sous une
;  forme barree, pour montrer qu'elle est mangee
; ---------------------------------------------------------------------
dessiner_case_prise
        lda anim_case
        sta num_courant
        jsr pos_case
        lda #0
        sta attr_case
        ; fond de la case
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
        ; la piece garde sa video, donc sa couleur, mais son centre est
        ; remplace par une croix
        lda anim_case
        jsr contenu_case
        ldx #0
        cmp #PION_N
        bcs +
        ldx #INVERSE
+       stx attr_piece
        lda car_arc_hg
        ora attr_piece
        ldy #PIECE_DX
        sta (ptr_ecran),y
        lda #CAR_PRISE
        ora attr_piece
        iny
        sta (ptr_ecran),y
        lda car_arc_hd
        ora attr_piece
        iny
        sta (ptr_ecran),y
        lda car_arc_bg
        ora attr_piece
        ldy #LARGEUR+PIECE_DX
        sta (ptr_ecran),y
        lda #CAR_PRISE
        ora attr_piece
        iny
        sta (ptr_ecran),y
        lda car_arc_bd
        ora attr_piece
        iny
        sta (ptr_ecran),y
        rts

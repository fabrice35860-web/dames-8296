; =====================================================================
;  ecran.asm - affichage du damier, des pieces et du panneau
; =====================================================================

; ---------------------------------------------------------------------
;  init_ecran : passe en majuscules + graphiques et efface tout l'ecran
; ---------------------------------------------------------------------
init_ecran
        lda #MODE_GRAPH
        sta REG_CARACT
        ; fallthrough

; ---------------------------------------------------------------------
;  effacer_ecran : remplit la RAM ecran d'espaces
;  On ecrit les 2048 octets de la RAM ecran (les 48 derniers ne sont pas
;  affiches, cela evite un comptage sur 16 bits).
; ---------------------------------------------------------------------
effacer_ecran
        lda #CAR_ESPACE
        ldx #0
-       sta ECRAN+$000,x
        sta ECRAN+$100,x
        sta ECRAN+$200,x
        sta ECRAN+$300,x
        sta ECRAN+$400,x
        sta ECRAN+$500,x
        sta ECRAN+$600,x
        sta ECRAN+$700,x
        inx
        bne -
        rts

; ---------------------------------------------------------------------
;  pos_ecran : calcule l'adresse ecran d'une position
;  Entree  A = ligne (0..24), X = colonne (0..79)
;  Sortie  ptr_ecran pointe ce caractere. A et Y sont detruits.
; ---------------------------------------------------------------------
pos_ecran
        tay
        txa
        clc
        adc lignes_lo,y
        sta ptr_ecran
        lda lignes_hi,y
        adc #0
        sta ptr_ecran+1
        rts

; ---------------------------------------------------------------------
;  remplir : ecrit X fois le caractere A a partir de ptr_ecran
;  Entree  A = caractere, X = nombre (1..255)
; ---------------------------------------------------------------------
remplir
        ldy #0
-       sta (ptr_ecran),y
        iny
        dex
        bne -
        rts

; ---------------------------------------------------------------------
;  afficher_texte : copie la chaine pointee par ptr_texte vers ptr_ecran
;  La chaine est en codes ecran et se termine par 0.
;  attr_texte ($00 ou $80) est combine a chaque caractere.
; ---------------------------------------------------------------------
afficher_texte
        ldy #0
at_car
        lda (ptr_texte),y
        beq at_fini
        ; un marqueur d'accent prend la forme que lui donne la ROM active
        cmp #ACC_E_AIGU
        bcc at_pose
        cmp #ACC_C_CEDIL+1
        bcs at_pose
        sty sauve_y
        sec
        sbc #ACC_E_AIGU
        tay
        lda accents,y
        ldy sauve_y
at_pose
        ora attr_texte
        sta (ptr_ecran),y
        iny
        bne at_car
at_fini
        rts

; ---------------------------------------------------------------------
;  afficher_table : affiche une suite de textes fixes
;  Entree  ptr_aux pointe une table d'entrees de 5 octets :
;          ligne, colonne, attribut, adresse (poids faible, poids fort)
;          La table se termine par l'octet $FF.
; ---------------------------------------------------------------------
afficher_table
        ldy #0
at_boucle
        lda (ptr_aux),y
        cmp #$FF
        beq at_fin
        sta tmp_ligne
        iny
        lda (ptr_aux),y
        sta tmp_colonne
        iny
        lda (ptr_aux),y
        sta attr_texte
        iny
        lda (ptr_aux),y
        sta ptr_texte
        iny
        lda (ptr_aux),y
        sta ptr_texte+1
        iny
        sty tmp_index
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        jsr afficher_texte
        ldy tmp_index
        bne at_boucle       ; la table fait moins de 256 octets
at_fin
        lda #0
        sta attr_texte
        rts

; ---------------------------------------------------------------------
;  dessiner_cadre : trace le cadre autour du damier
; ---------------------------------------------------------------------
dessiner_cadre
        ; bord superieur
        lda #CADRE_Y1
        ldx #CADRE_X1
        jsr pos_ecran
        lda car_trait_h
        ldx #CADRE_X2-CADRE_X1+1
        jsr remplir
        lda car_coin_hg
        ldy #0
        sta (ptr_ecran),y
        lda car_coin_hd
        ldy #CADRE_X2-CADRE_X1
        sta (ptr_ecran),y
        ; bord inferieur
        lda #CADRE_Y2
        ldx #CADRE_X1
        jsr pos_ecran
        lda car_trait_h
        ldx #CADRE_X2-CADRE_X1+1
        jsr remplir
        lda car_coin_bg
        ldy #0
        sta (ptr_ecran),y
        lda car_coin_bd
        ldy #CADRE_X2-CADRE_X1
        sta (ptr_ecran),y
        ; montants gauche et droit
        lda #CADRE_Y1+1
        sta tmp_ligne
dc_montant
        lda tmp_ligne
        ldx #CADRE_X1
        jsr pos_ecran
        lda car_trait_v
        ldy #0
        sta (ptr_ecran),y
        ldy #CADRE_X2-CADRE_X1
        sta (ptr_ecran),y
        inc tmp_ligne
        lda tmp_ligne
        cmp #CADRE_Y2
        bne dc_montant
        rts

; ---------------------------------------------------------------------
;  dessiner_fond : pose le fond du damier (cases claires et foncees)
;  Les cases foncees recoivent ensuite leur contenu via dessiner_case.
; ---------------------------------------------------------------------
dessiner_fond
        lda #0
        sta tmp_rangee
df_rangee
        lda #0
        sta tmp_colonne     ; colonne logique c de 0 a 9
df_case
        ; attribut : case foncee si (r + c) est impair
        lda tmp_rangee
        clc
        adc tmp_colonne
        and #1
        beq df_claire
        lda #CAR_ESP_INV
        bne df_pose
df_claire
        lda #CAR_ESPACE
df_pose
        sta tmp_car
        ; ligne haute de la case
        lda tmp_rangee
        asl a
        clc
        adc #DAM_Y
        sta tmp_ligne
        lda tmp_colonne
        asl a
        asl a
        clc
        adc tmp_colonne     ; 5 * c
        clc
        adc #DAM_X
        tax
        lda tmp_ligne
        jsr pos_ecran
        ldy #CASE_L-1
        lda tmp_car
-       sta (ptr_ecran),y
        dey
        bpl -
        ; ligne basse de la case
        ldy #LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #LARGEUR-1
        bne -
        inc tmp_colonne
        lda tmp_colonne
        cmp #10
        bne df_case
        inc tmp_rangee
        lda tmp_rangee
        cmp #10
        bne df_rangee
        rts

; ---------------------------------------------------------------------
;  pos_case : place ptr_ecran sur le coin haut-gauche de la case A
;  Entree  A = numero officiel de la case (1..50)
; ---------------------------------------------------------------------
pos_case
        tax
        dex
        lda case_adr_lo,x
        sta ptr_ecran
        lda case_adr_hi,x
        sta ptr_ecran+1
        rts

; ---------------------------------------------------------------------
;  contenu_case : lit le plateau pour la case A
;  Entree  A = numero officiel (1..50)
;  Sortie  A = contenu (VIDE, PION_B, ...)
; ---------------------------------------------------------------------
contenu_case
        tax
        dex
        ldy num_vers_idx,x
        lda plateau,y
        rts

; ---------------------------------------------------------------------
;  dessiner_case : redessine entierement une case jouable
;  Entree  A = numero officiel (1..50)
; ---------------------------------------------------------------------
dessiner_case
        sta num_courant
        jsr pos_case
        ; Attribut du fond de la case : le curseur se signale en inversant
        ; une phase de battement sur deux. La case foncee passe alors au
        ; noir et semble disparaitre, ce qui se voit bien, tandis que la
        ; piece garde sa propre video et donc sa couleur.
        ldx #0
        lda num_courant
        cmp curseur
        bne dc_attr
        lda clign_phase
        beq dc_attr
        ldx #INVERSE
dc_attr
        stx attr_case
        ; fond de la case : 5 caracteres sur chacune des 2 lignes
        lda #CAR_ESP_INV
        eor attr_case
        ldy #CASE_L-1
-       sta (ptr_ecran),y
        dey
        bpl -
        ldy #LARGEUR+CASE_L-1
-       sta (ptr_ecran),y
        dey
        cpy #LARGEUR-1
        bne -
        ; Piece choisie : les colonnes 0 et 4 repassent en video normale,
        ; ce qui encadre la piece de deux barres sombres (effet de crochets).
        ; Marquage fixe, qui ne clignote pas de lui-meme.
        lda num_courant
        cmp selection
        bne dc_contenu
        lda #CAR_ESPACE
        eor attr_case
        ldy #0
        sta (ptr_ecran),y
        ldy #CASE_L-1
        sta (ptr_ecran),y
        ldy #LARGEUR
        sta (ptr_ecran),y
        ldy #LARGEUR+CASE_L-1
        sta (ptr_ecran),y
dc_contenu
        lda num_courant
        jsr contenu_case
        bne dessiner_piece
        ; case vide : numero de reperage si l'option est active
        jmp afficher_numero

; ---------------------------------------------------------------------
;  dessiner_piece : trace la piece A dans la case pointee par ptr_ecran
;    pion  arc_hg trait_h arc_hd      dame  arc_hg car_dame arc_hd
;          arc_bg trait_h arc_bd            arc_bg trait_h arc_bd
;  Les pieces blanches sont tracees en video inverse (anneau sombre),
;  les noires en video normale (bloc sombre a anneau lumineux).
; ---------------------------------------------------------------------
dessiner_piece
        sta car_type
        ldx #0              ; noir : video normale
        cmp #PION_N
        bcs +
        ldx #INVERSE        ; blanc : video inverse
+       stx attr_piece
        ; La piece echappe volontairement a l'attribut de case : c'est la
        ; video inverse qui distingue un Blanc d'un Noir, si bien que le
        ; curseur, en inversant la case entiere, echangeait les deux
        ; couleurs. Une piece blanche sous le curseur paraissait noire.
        lda car_type
        ; marque centrale : losange pour une dame, trait pour un pion
        ldy car_trait_h
        cmp #DAME_B
        beq dp_dame
        cmp #DAME_N
        bne dp_marque
dp_dame
        ldy car_dame
dp_marque
        sty car_milieu
        ; ligne du haut
        lda car_arc_hg
        ora attr_piece
        ldy #PIECE_DX
        sta (ptr_ecran),y
        lda car_milieu
        ora attr_piece
        iny
        sta (ptr_ecran),y
        lda car_arc_hd
        ora attr_piece
        iny
        sta (ptr_ecran),y
        ; ligne du bas
        lda car_arc_bg
        ora attr_piece
        ldy #LARGEUR+PIECE_DX
        sta (ptr_ecran),y
        lda car_trait_h
        ora attr_piece
        iny
        sta (ptr_ecran),y
        lda car_arc_bd
        ora attr_piece
        iny
        sta (ptr_ecran),y
        rts

; ---------------------------------------------------------------------
;  afficher_numero : numero de reperage d'une case vide, en video inverse
;  Entree  num_courant = numero, ptr_ecran = coin de la case
; ---------------------------------------------------------------------
afficher_numero
        lda montrer_numeros
        beq an_fin
        lda num_courant
        jsr decimal          ; -> v_dizaine, v_unite
        lda v_dizaine
        beq an_espace
        ora #CAR_ZERO|INVERSE
        bne an_pose
an_espace
        lda #CAR_ESP_INV
an_pose
        eor attr_case
        ldy #LARGEUR+PIECE_DX
        sta (ptr_ecran),y
        lda v_unite
        ora #CAR_ZERO|INVERSE
        eor attr_case
        iny
        sta (ptr_ecran),y
an_fin
        rts

; ---------------------------------------------------------------------
;  decimal : decompose A (0..99) en v_dizaine et v_unite
; ---------------------------------------------------------------------
decimal
        ldx #$FF
        sec
-       inx
        sbc #10
        bcs -
        adc #10
        sta v_unite
        stx v_dizaine
        rts

; ---------------------------------------------------------------------
;  div5 : decompose A en v_dizaine = A/5 et v_unite = A mod 5
;  Sert a situer une case dans sa rangee : pour la case n, appeler avec
;  n-1 donne la rangee dans v_dizaine et le rang dans la rangee (0..4)
;  dans v_unite.
; ---------------------------------------------------------------------
div5
        ldx #$FF
        sec
-       inx
        sbc #5
        bcs -
        adc #5
        sta v_unite
        stx v_dizaine
        rts

; ---------------------------------------------------------------------
;  afficher_nb2 : ecrit A (0..99) sur 2 caracteres en (tmp_ligne, X)
;  Entree  A = valeur, X = colonne, tmp_ligne = ligne
;          attr_texte combine aux caracteres
; ---------------------------------------------------------------------
afficher_nb2
        sta pz_tmp
        lda tmp_ligne
        jsr pos_ecran
        lda pz_tmp
        jsr decimal
        lda v_dizaine
        bne an2_dizaine
        lda #CAR_ESPACE     ; pas de zero de tete : "1" et non "01"
        ora attr_texte
        bne an2_pose        ; CAR_ESPACE n'est jamais nul
an2_dizaine
        ora #CAR_ZERO
        ora attr_texte
an2_pose
        ldy #0
        sta (ptr_ecran),y
        lda v_unite
        ora #CAR_ZERO
        ora attr_texte
        iny
        sta (ptr_ecran),y
        rts

; ---------------------------------------------------------------------
;  dessiner_damier : fond, cadre et les 50 cases jouables
; ---------------------------------------------------------------------
dessiner_damier
        jsr dessiner_cadre
        jsr dessiner_fond
        lda #1
        sta tmp_num
dd_boucle
        lda tmp_num
        jsr dessiner_case
        inc tmp_num
        lda tmp_num
        cmp #51
        bne dd_boucle
        rts

; ---------------------------------------------------------------------
;  effacer_ligne : remplit la ligne A d'espaces (80 colonnes)
; ---------------------------------------------------------------------
effacer_ligne
        ldx #0
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #LARGEUR
        jmp remplir

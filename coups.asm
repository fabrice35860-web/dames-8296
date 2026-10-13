; =====================================================================
;  coups.asm - generateur de coups legaux (dames internationales)
;
;  Marche a suivre : on cherche d'abord toutes les rafles, puisque la
;  prise est obligatoire ; s'il n'y en a aucune, on produit les
;  deplacements simples. La prise majoritaire est appliquee au fil de
;  l'eau : des qu'une rafle plus longue apparait, la liste est videe.
;
;  Les coups sont ranges bout a bout dans coups_zone, chacun sous la
;  forme   [depart][arrivee][nombre de prises][cases prises...]
;  avec les numeros officiels 1 a 50. coups_index pointe le debut de
;  chaque coup, pour y acceder directement.
; =====================================================================

; ---------------------------------------------------------------------
;  generer_coups : remplit la liste des coups legaux du camp au trait
; ---------------------------------------------------------------------
generer_coups
        lda trait
        sta trait_gen
        ; l'interface repart toujours du debut de la zone
        lda #<coups_zone
        sta coups_fin
        lda #>coups_zone
        sta coups_fin+1
        ; fallthrough

; Variante utilisee par la recherche : le camp est deja dans trait_gen et
; les coups se rangent a la suite de ce qui s'y trouve deja. Chaque niveau
; de la recherche reserve ainsi sa tranche, puis la rend en repartant.
generer_pour_trait
        lda #0
        sta debordement
        ; la tranche de ce niveau commence ou en est le pointeur d'ecriture
        lda coups_fin
        sta coups_debut
        lda coups_fin+1
        sta coups_debut+1
        jsr vider_coups
        lda #0
        sta meilleure_prise
        lda #1
        sta num_gen
gc_rafles
        ldx num_gen
        dex
        ldy num_vers_idx,x
        lda plateau,y
        sta piece_courante
        jsr est_ami
        bne gc_suivant
        sty depart_courant
        ; la piece quitte sa case des le debut de la rafle : la case
        ; redevient libre, elle pourra donc etre traversee ou meme servir
        ; d'arrivee si la rafle fait le tour
        lda #VIDE
        sta plateau,y
        lda #0
        sta prof
        lda depart_courant
        jsr explorer_rafles
        ldy depart_courant
        lda piece_courante
        sta plateau,y
gc_suivant
        inc num_gen
        lda num_gen
        cmp #51
        bne gc_rafles
        ; une rafle existe : elle est obligatoire, les deplacements
        ; simples ne sont meme pas examines
        lda meilleure_prise
        bne gc_fin
        jsr coups_simples
gc_fin
        rts

; ---------------------------------------------------------------------
;  vider_coups : repart d'une liste vide
; ---------------------------------------------------------------------
vider_coups
        ; repart au debut de la tranche du niveau courant, et non au debut
        ; de la zone : les niveaux superieurs gardent leurs coups
        lda #0
        sta nb_coups
        lda coups_debut
        sta coups_fin
        lda coups_debut+1
        sta coups_fin+1
        rts

; ---------------------------------------------------------------------
;  est_ami / est_ennemi : nature de la piece A vis-a-vis de trait_gen
;  Sortie  Z = 1 si la reponse est oui
;  Les cases vides et les cases fantomes de la bordure repondent non.
; ---------------------------------------------------------------------
est_ami
        beq ea_non
        cmp #BORD
        beq ea_non
        sec
        sbc #1
        lsr a               ; 0 = piece blanche, 1 = piece noire
        cmp trait_gen
        beq ea_oui
ea_non
        lda #1
        rts
ea_oui
        lda #0
        rts

est_ennemi
        beq ea_non
        cmp #BORD
        beq ea_non
        sec
        sbc #1
        lsr a
        cmp trait_gen
        beq ea_non          ; c'est une des notres
        lda #0
        rts

; ---------------------------------------------------------------------
;  explorer_rafles : toutes les rafles depuis la case A
;  Entree  A = case courante (index plateau), prof = prises deja faites
;  L'etat propre a chaque niveau est range dans des tables indexees par
;  prof, la pile du 6502 ne portant que l'adresse de retour.
; ---------------------------------------------------------------------
explorer_rafles
        ldx prof
        sta loc_courant,x
        lda #0
        sta loc_suites,x
        sta loc_dir,x
er_dir
        ldx prof
        lda loc_dir,x
        cmp #4
        beq er_feuille
        tay
        lda dir_decalage,y
        sta loc_delta,x
        lda piece_courante
        cmp #DAME_B
        beq er_dame
        cmp #DAME_N
        beq er_dame
        jsr prise_pion
        jmp er_suivant
er_dame
        jsr prise_dame
er_suivant
        ldx prof
        inc loc_dir,x
        jmp er_dir

er_feuille
        ; aucune continuation depuis ici : la rafle s'arrete, on la garde
        lda loc_suites,x
        bne er_fin
        lda prof
        beq er_fin          ; pas la moindre prise : rien a enregistrer
        lda loc_courant,x
        jsr enregistrer_rafle
er_fin
        rts

; ---------------------------------------------------------------------
;  prise_pion : saut par-dessus la case voisine, dans les 4 directions
;  Le pion prend en avant comme en arriere.
; ---------------------------------------------------------------------
prise_pion
        ldx prof
        lda loc_courant,x
        clc
        adc loc_delta,x
        sta loc_prise,x     ; case sautee
        tay
        lda plateau,y
        jsr est_ennemi
        bne pp_non
        lda marques,y       ; Y porte toujours la case sautee
        bne pp_non          ; deja prise dans cette rafle
        lda loc_prise,x
        clc
        adc loc_delta,x
        sta loc_arrivee,x
        tay
        lda plateau,y
        bne pp_non          ; la case d'arrivee doit etre libre
        lda loc_arrivee,x
        ldy loc_prise,x
        jmp descendre
pp_non
        rts

; ---------------------------------------------------------------------
;  prise_dame : la dame prend a distance et s'arrete ou elle veut
;  derriere la piece prise, sur n'importe quelle case libre.
; ---------------------------------------------------------------------
prise_dame
        ldx prof
        lda loc_courant,x
pd_avance
        clc
        adc loc_delta,x
        tay
        lda plateau,y
        beq pd_vide         ; case libre : on continue a glisser
        jsr est_ennemi
        bne pd_non
        lda marques,y       ; Y porte toujours la case examinee
        bne pd_non          ; deja prise dans cette rafle
        tya
        sta loc_prise,x
        sta loc_arrivee,x
pd_arrivees
        ldx prof
        lda loc_arrivee,x
        clc
        adc loc_delta,x
        sta loc_arrivee,x
        tay
        lda plateau,y
        bne pd_non          ; plus de case libre derriere
        lda loc_arrivee,x
        ldy loc_prise,x
        jsr descendre
        jmp pd_arrivees
pd_vide
        tya
        jmp pd_avance
pd_non
        rts

; ---------------------------------------------------------------------
;  descendre : empile la prise et poursuit la rafle d'un cran plus bas
;  Entree  A = case d'arrivee, Y = case prise (index plateau)
; ---------------------------------------------------------------------
descendre
        sta loc_suivante
        ldx prof
        tya
        sta pile_prises,x
        tay
        lda #1
        sta marques,y       ; la piece est prise, mais reste sur le plateau
        inc loc_suites,x    ; une continuation de plus a ce niveau
        inc prof
        lda loc_suivante
        jsr explorer_rafles
        dec prof
        ldx prof
        ldy pile_prises,x
        lda #0
        sta marques,y
        rts

; ---------------------------------------------------------------------
;  enregistrer_rafle : garde la rafle courante si elle est assez longue
;  Entree  A = case d'arrivee (index plateau)
; ---------------------------------------------------------------------
enregistrer_rafle
        sta loc_suivante
        lda prof
        cmp meilleure_prise
        bcc err_fin         ; plus courte que la meilleure connue
        beq err_ajouter
        ; plus longue : tout ce qui precede devient caduc
        sta meilleure_prise
        jsr vider_coups
err_ajouter
        ; deux chemins differents qui prennent les memes pieces et
        ; finissent sur la meme case ne font qu'un seul coup
        jsr coup_deja_connu
        beq err_fin
        lda loc_suivante
        jsr ajouter_coup
err_fin
        rts

; ---------------------------------------------------------------------
;  ajouter_coup : range un coup dans la zone et l'indexe
;  Entree  A = case d'arrivee (index plateau), prof = nombre de prises,
;          pile_prises = cases prises, depart_courant = case de depart
; ---------------------------------------------------------------------
ajouter_coup
        tax
        lda idx_vers_num,x
        sta loc_suivante    ; numero officiel de la case d'arrivee
        ; garde-fou : plutot que de deborder sur la zone voisine, on
        ; laisse tomber le coup et on le signale
        lda nb_coups
        cmp #MAX_COUPS
        bcc ac_place
        inc debordement
        rts
ac_place
        ; index du nouveau coup
        ldx nb_coups
        lda coups_fin
        sta coups_index_lo,x
        lda coups_fin+1
        sta coups_index_hi,x
        inc nb_coups
        ; depart
        ldx depart_courant
        lda idx_vers_num,x
        ldy #0
        sta (coups_fin),y
        ; arrivee
        iny
        lda loc_suivante
        sta (coups_fin),y
        ; nombre de prises
        iny
        lda prof
        sta (coups_fin),y
        ; cases prises
        ldx #0
ac_prises
        cpx prof
        beq ac_fin
        iny
        stx pz_tmp
        lda pile_prises,x
        tax
        lda idx_vers_num,x
        sta (coups_fin),y
        ldx pz_tmp
        inx
        bne ac_prises
ac_fin
        ; avance le pointeur d'ecriture de 3 + nombre de prises
        iny
        tya
        clc
        adc coups_fin
        sta coups_fin
        bcc ac_sortie
        inc coups_fin+1
ac_sortie
        rts

; ---------------------------------------------------------------------
;  coup_deja_connu : la rafle courante figure-t-elle deja dans la liste ?
;  Sortie  Z = 1 si oui
; ---------------------------------------------------------------------
coup_deja_connu
        lda nb_coups
        beq cdc_non
        lda #0
        sta cmp_num
cdc_boucle
        ldx cmp_num
        lda coups_index_lo,x
        sta ptr_aux
        lda coups_index_hi,x
        sta ptr_aux+1
        ; meme depart ?
        ldx depart_courant
        lda idx_vers_num,x
        ldy #0
        cmp (ptr_aux),y
        bne cdc_suivant
        ; meme arrivee ?
        ldx loc_suivante
        lda idx_vers_num,x
        iny
        cmp (ptr_aux),y
        bne cdc_suivant
        ; meme nombre de prises ?
        iny
        lda prof
        cmp (ptr_aux),y
        bne cdc_suivant
        ; memes pieces prises ? on verifie que chacune des notres figure
        ; dans le coup deja range, l'ordre n'important pas
        jsr memes_prises
        beq cdc_oui
cdc_suivant
        inc cmp_num
        lda cmp_num
        cmp nb_coups
        bne cdc_boucle
cdc_non
        lda #1
        rts
cdc_oui
        lda #0
        rts

; ---------------------------------------------------------------------
;  memes_prises : compare l'ensemble des prises courantes a celui du
;  coup pointe par ptr_aux. Sortie Z = 1 si les ensembles coincident.
; ---------------------------------------------------------------------
memes_prises
        lda #0
        sta cmp_i
mp_notre
        lda cmp_i
        cmp prof
        beq mp_oui          ; toutes retrouvees
        tax
        lda pile_prises,x
        tax
        lda idx_vers_num,x
        sta cmp_valeur
        ; cherche cette case parmi les prises du coup range
        lda #0
        sta cmp_j
mp_leur
        lda cmp_j
        cmp prof
        beq mp_non          ; absente : les ensembles different
        clc
        adc #3              ; les prises commencent au 4e octet
        tay
        lda (ptr_aux),y
        cmp cmp_valeur
        beq mp_trouvee
        inc cmp_j
        jmp mp_leur
mp_trouvee
        inc cmp_i
        jmp mp_notre
mp_oui
        lda #0
        rts
mp_non
        lda #1
        rts

; ---------------------------------------------------------------------
;  coups_simples : deplacements d'une case pour les pions, glissements
;  sur toute la diagonale pour les dames
; ---------------------------------------------------------------------
coups_simples
        lda #0
        sta prof            ; aucun coup simple ne prend de piece
        lda #1
        sta num_gen
cs_boucle
        ldx num_gen
        dex
        ldy num_vers_idx,x
        lda plateau,y
        sta piece_courante
        jsr est_ami
        bne cs_suivant
        sty depart_courant
        lda piece_courante
        cmp #DAME_B
        beq cs_dame
        cmp #DAME_N
        beq cs_dame

        ; --- pion : il n'avance que vers le camp adverse ---
        ldx #0              ; Blancs : HG et HD
        lda trait_gen
        beq cs_pion
        ldx #2              ; Noirs : BG et BD
cs_pion
        stx cs_dir
cs_pion_boucle
        ldx cs_dir
        lda dir_decalage,x
        clc
        adc depart_courant
        tay
        lda plateau,y
        bne cs_pion_suivant ; occupee ou bordure
        tya
        jsr ajouter_coup
cs_pion_suivant
        inc cs_dir
        ldx cs_dir
        txa
        and #1
        beq +               ; la paire de directions est epuisee
        jmp cs_pion_boucle
+       jmp cs_suivant

        ; --- dame : elle glisse tant que la diagonale est libre ---
cs_dame
        lda #0
        sta cs_dir
cs_dame_dir
        ldx cs_dir
        lda dir_decalage,x
        sta cs_delta
        lda depart_courant
cs_dame_glisse
        clc
        adc cs_delta
        sta cs_case
        tay
        lda plateau,y
        bne cs_dame_suivant
        lda cs_case
        jsr ajouter_coup
        lda cs_case
        jmp cs_dame_glisse
cs_dame_suivant
        inc cs_dir
        lda cs_dir
        cmp #4
        bne cs_dame_dir

cs_suivant
        inc num_gen
        lda num_gen
        cmp #51
        beq +
        jmp cs_boucle
+       rts

; ---------------------------------------------------------------------
;  pointer_coup : place ptr_coup sur le coup numero A de la liste
; ---------------------------------------------------------------------
pointer_coup
        tax
        lda coups_index_lo,x
        sta ptr_coup
        lda coups_index_hi,x
        sta ptr_coup+1
        rts

; ---------------------------------------------------------------------
;  compter_coups_piece : combien de coups partent de la case A ?
;  Sert a refuser le choix d'une piece qui n'a rien a jouer, ce qui est
;  frequent : la prise etant obligatoire, les autres pieces sont muettes.
; ---------------------------------------------------------------------
compter_coups_piece
        sta cmp_valeur
        lda #0
        sta cmp_resultat
        ldx #0
ccp_boucle
        cpx nb_coups
        beq ccp_fin
        stx cmp_num
        txa
        jsr pointer_coup
        ldy #0
        lda (ptr_coup),y
        cmp cmp_valeur
        bne ccp_suivant
        inc cmp_resultat
ccp_suivant
        ldx cmp_num
        inx
        bne ccp_boucle
ccp_fin
        lda cmp_resultat
        rts

; ---------------------------------------------------------------------
;  appliquer_coup : joue sur le plateau le coup numero A
;  Les pieces prises sont retirees maintenant : la regle qui veut qu'on
;  les enleve en fin de rafle ne concerne que la generation du coup.
; ---------------------------------------------------------------------
appliquer_coup
        jsr pointer_coup
        ; fallthrough

; Variante : le coup est deja pointe par ptr_coup. C'est par la que passe
; le coup choisi par la machine, recopie a part parce que la recherche
; reutilise la zone des coups.
appliquer_coup_ptr
        ldy #0
        lda (ptr_coup),y
        sta coup_depart
        iny
        lda (ptr_coup),y
        sta coup_arrivee
        iny
        lda (ptr_coup),y
        sta coup_nb_prises
        ; la piece quitte sa case
        ldx coup_depart
        dex
        ldy num_vers_idx,x
        lda plateau,y
        sta coup_piece
        sta coup_origine    ; nature d'avant promotion, pour le retour arriere
        lda #VIDE
        sta plateau,y
        ; retrait des pieces prises, dont on garde la liste pour le redessin
        ldx #0
ap_prises
        cpx coup_nb_prises
        beq ap_promotion
        stx pz_tmp
        txa
        clc
        adc #3
        tay
        lda (ptr_coup),y
        sta prises_cases,x
        tax
        dex
        ldy num_vers_idx,x
        lda plateau,y
        ldx pz_tmp
        sta prises_pieces,x ; on garde aussi ce qu'on retire
        lda prises_cases,x
        tax
        dex
        ldy num_vers_idx,x
        lda #VIDE
        sta plateau,y
        ldx pz_tmp
        inx
        bne ap_prises
ap_promotion
        ; un pion n'est promu que s'il termine son coup sur la derniere
        ; rangee : la traverser pendant une rafle ne suffit pas, et le
        ; generateur a deja refuse de s'y arreter en cours de route
        lda coup_piece
        cmp #PION_B
        bne ap_noir
        lda coup_arrivee
        cmp #6
        bcs ap_placer
        lda #DAME_B
        sta coup_piece
        jmp ap_placer
ap_noir
        cmp #PION_N
        bne ap_placer
        lda coup_arrivee
        cmp #46
        bcc ap_placer
        lda #DAME_N
        sta coup_piece
ap_placer
        ldx coup_arrivee
        dex
        ldy num_vers_idx,x
        lda coup_piece
        sta plateau,y
        rts


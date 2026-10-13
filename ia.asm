; =====================================================================
;  ia.asm - evaluation et recherche alpha-beta
;
;  Les scores sont sur 16 bits signes, du point de vue du camp au trait
;  (negamax) : une position est evaluee a +N pour celui qui joue, et la
;  meme position vue d'en face vaut -N.
;
;  La recherche ne recopie jamais le plateau : chaque coup est joue sur
;  place puis defait, l'ensemble des renseignements necessaires a son
;  annulation etant empile dans annul_zone.
;
;  Les coups de chaque niveau sont ranges a la suite dans coups_zone :
;  chaque appel reserve sa tranche a partir de coups_fin et la rend en
;  repartant. Au sein d'un niveau on parcourt les coups en sequence, un
;  coup occupant 3 + nombre de prises octets.
; =====================================================================

; ---------------------------------------------------------------------
;  evaluer : note la position du point de vue du camp au trait
;  Sortie  score_lo / score_hi (16 bits signes)
; ---------------------------------------------------------------------
evaluer
        lda #0
        sta score_lo
        sta score_hi
        lda #1
        sta num_eval
ev_boucle
        ldx num_eval
        dex
        ldy num_vers_idx,x
        lda plateau,y
        beq ev_suivant
        cmp #PION_B
        beq ev_pion_b
        cmp #DAME_B
        beq ev_dame_b
        cmp #PION_N
        beq ev_pion_n
        cmp #DAME_N
        beq ev_dame_n
        jmp ev_suivant

        ; --- pieces blanches : on ajoute ---
ev_pion_b
        lda bonus_pion,x
        clc
        adc #VAL_PION
        jsr ajouter_score
        jmp ev_suivant
ev_dame_b
        lda bonus_dame,x
        jsr ajouter_score
        jsr ajouter_dame
        jmp ev_suivant

        ; --- pieces noires : meme bareme, par symetrie, puis on retranche ---
ev_pion_n
        jsr case_miroir
        lda bonus_pion,x
        clc
        adc #VAL_PION
        jsr retrancher_score
        jmp ev_suivant
ev_dame_n
        jsr case_miroir
        lda bonus_dame,x
        jsr retrancher_score
        jsr retrancher_dame

ev_suivant
        inc num_eval
        lda num_eval
        cmp #51
        bne ev_boucle
        ; le score est compte pour les Blancs : on le retourne si les
        ; Noirs sont au trait, pour rester en negamax
        lda trait
        beq ev_fin
        jsr nier_score
ev_fin
        rts

; ---------------------------------------------------------------------
;  case_miroir : X = index de la case symetrique (case n <-> 51-n)
;  Entree  num_eval = numero de la case, Sortie X = (51-n)-1 = 50-n
; ---------------------------------------------------------------------
case_miroir
        lda #50
        sec
        sbc num_eval
        tax
        rts

; ---------------------------------------------------------------------
;  ajouter_score / retrancher_score : score +/- A (non signe, 0..255)
; ---------------------------------------------------------------------
ajouter_score
        clc
        adc score_lo
        sta score_lo
        bcc +
        inc score_hi
+       rts

retrancher_score
        sta pz_tmp
        lda score_lo
        sec
        sbc pz_tmp
        sta score_lo
        bcs +
        dec score_hi
+       rts

; ---------------------------------------------------------------------
;  ajouter_dame / retrancher_dame : la valeur d'une dame depasse un octet
; ---------------------------------------------------------------------
ajouter_dame
        lda score_lo
        clc
        adc #<VAL_DAME
        sta score_lo
        lda score_hi
        adc #>VAL_DAME
        sta score_hi
        rts

retrancher_dame
        lda score_lo
        sec
        sbc #<VAL_DAME
        sta score_lo
        lda score_hi
        sbc #>VAL_DAME
        sta score_hi
        rts

; ---------------------------------------------------------------------
;  nier_score : score = -score (complement a deux sur 16 bits)
; ---------------------------------------------------------------------
nier_score
        sec
        lda #0
        sbc score_lo
        sta score_lo
        lda #0
        sbc score_hi
        sta score_hi
        rts

; ---------------------------------------------------------------------
;  jouer_rech : joue le coup pointe par ptr_coup et empile de quoi le
;  defaire. Le trait passe a l'adversaire.
; ---------------------------------------------------------------------
jouer_rech
        ; retient ou commence l'annulation de ce niveau
        ldx prof_rech
        lda annul_ptr
        sta annul_debut_lo,x
        lda annul_ptr+1
        sta annul_debut_hi,x
        ; depart, arrivee, nombre de prises
        ldy #0
        lda (ptr_coup),y
        sta jr_depart
        iny
        lda (ptr_coup),y
        sta jr_arrivee
        iny
        lda (ptr_coup),y
        sta jr_nb
        ; la piece quitte sa case ; on empile sa nature, qui peut changer
        ; par promotion
        ldx jr_depart
        dex
        ldy num_vers_idx,x
        lda plateau,y
        sta jr_piece
        sta jr_origine      ; nature d'avant promotion, pour le hachage
        jsr empiler
        lda #VIDE
        sta plateau,y
        ; retrait des pieces prises, chacune empilee avec sa case
        ldx #0
jr_prises
        cpx jr_nb
        beq jr_promotion
        stx pz_tmp
        txa
        clc
        adc #3
        tay
        lda (ptr_coup),y
        sta pz_tmp2
        jsr empiler         ; la case prise
        ldx pz_tmp2
        dex
        ldy num_vers_idx,x
        lda plateau,y
        jsr empiler         ; la piece qui s'y trouvait
        ; la piece prise quitte le plateau : on l'ote de la clef
        sta xp_type
        lda pz_tmp2
        sta xp_case
        jsr xor_piece
        ldx pz_tmp2
        dex
        ldy num_vers_idx,x
        lda #VIDE
        sta plateau,y
        ldx pz_tmp
        inx
        bne jr_prises
jr_promotion
        lda jr_piece
        cmp #PION_B
        bne jr_noir
        lda jr_arrivee
        cmp #6
        bcs jr_placer
        lda #DAME_B
        sta jr_piece
        jmp jr_placer
jr_noir
        cmp #PION_N
        bne jr_placer
        lda jr_arrivee
        cmp #46
        bcc jr_placer
        lda #DAME_N
        sta jr_piece
jr_placer
        ldx jr_arrivee
        dex
        ldy num_vers_idx,x
        lda jr_piece
        sta plateau,y
        ; la clef suit : la piece quitte sa case de depart et parait a
        ; l'arrivee, sous la nature qu'elle y prend
        lda jr_origine
        sta xp_type
        lda jr_depart
        sta xp_case
        jsr xor_piece
        lda jr_piece
        sta xp_type
        lda jr_arrivee
        sta xp_case
        jsr xor_piece
        ; nombre de prises et cases, pour l'annulation
        lda jr_nb
        jsr empiler
        lda jr_depart
        jsr empiler
        lda jr_arrivee
        jsr empiler
        ; le trait change de camp, la clef aussi
        lda trait
        eor #1
        sta trait
        jmp xor_trait

; ---------------------------------------------------------------------
;  annuler_rech : defait le dernier coup joue a ce niveau
; ---------------------------------------------------------------------
annuler_rech
        lda trait
        eor #1
        sta trait
        jsr xor_trait
        ; on depile dans l'ordre inverse de l'empilement
        jsr depiler
        sta jr_arrivee
        jsr depiler
        sta jr_depart
        jsr depiler
        sta jr_nb
        ; la piece quitte l'arrivee : on l'ote de la clef, puis la case
        ; redevient vide
        ldx jr_arrivee
        dex
        ldy num_vers_idx,x
        lda plateau,y
        sta xp_type
        lda jr_arrivee
        sta xp_case
        jsr xor_piece
        ldx jr_arrivee
        dex
        ldy num_vers_idx,x
        lda #VIDE
        sta plateau,y
        ; les pieces prises reviennent, dans l'ordre inverse
        ldx jr_nb
ar_prises
        cpx #0
        beq ar_piece
        dex
        stx pz_tmp
        jsr depiler         ; la piece
        sta pz_tmp2
        jsr depiler         ; sa case
        sta pz_tmp3         ; la case ou la piece revient
        tax
        dex
        ldy num_vers_idx,x
        lda pz_tmp2
        sta plateau,y
        ; la piece reparait : on la remet dans la clef
        sta xp_type
        lda pz_tmp3
        sta xp_case
        jsr xor_piece
        ldx pz_tmp
        jmp ar_prises
ar_piece
        ; la piece retrouve sa case et sa nature d'avant promotion
        jsr depiler
        sta pz_tmp2
        ldx jr_depart
        dex
        ldy num_vers_idx,x
        lda pz_tmp2
        sta plateau,y
        ; et reparait dans la clef sous cette nature
        sta xp_type
        lda jr_depart
        sta xp_case
        jmp xor_piece

; ---------------------------------------------------------------------
;  xor_trait : combine a la clef le camp au trait
; ---------------------------------------------------------------------
xor_trait
        lda zob_trait
        eor cle_lo
        sta cle_lo
        lda zob_trait+1
        eor cle_hi
        sta cle_hi
        rts

; ---------------------------------------------------------------------
;  empiler / depiler : pile d'annulation
; ---------------------------------------------------------------------
; Ces deux routines preservent Y : l'appelant s'en sert pour designer la
; case du plateau qu'il est en train de traiter, et le perdre reviendrait
; a ecrire a cote.
empiler
        sty sauve_y
        ldy #0
        sta (annul_ptr),y
        inc annul_ptr
        bne +
        inc annul_ptr+1
+       ldy sauve_y
        rts

depiler
        sty sauve_y
        lda annul_ptr
        bne +
        dec annul_ptr+1
+       dec annul_ptr
        ldy #0
        lda (annul_ptr),y
        ldy sauve_y
        rts

; ---------------------------------------------------------------------
;  comparer_scores : compare (cmp_a) et (cmp_b), 16 bits signes
;  Sortie  A = 0 si a = b, 1 si a > b, $FF si a < b.
;          Les indicateurs suivent A : Z pour l'egalite, N pour a < b.
; ---------------------------------------------------------------------
comparer_scores
        ; L'egalite se teste sur les deux octets : la soustraction seule ne
        ; positionne Z que d'apres le poids fort, et deux scores de meme
        ; poids fort passeraient pour egaux.
        lda cmp_a_lo
        cmp cmp_b_lo
        bne cs_different
        lda cmp_a_hi
        cmp cmp_b_hi
        bne cs_different
        lda #0              ; a = b
        rts
cs_different
        lda cmp_a_lo
        cmp cmp_b_lo
        lda cmp_a_hi
        sbc cmp_b_hi
        bvc +
        eor #$80            ; debordement : le signe est inverse
+       bmi cs_inferieur
        lda #1              ; a > b
        rts
cs_inferieur
        lda #$FF            ; a < b
        rts

; ---------------------------------------------------------------------
;  alphabeta : recherche negamax avec elagage alpha-beta
;  Entree  prof_rech  = niveau courant (0 a la racine)
;          prof_reste = demi-coups restants a explorer
;          rech_alpha / rech_beta du niveau = fenetre de recherche
;  Sortie  score_lo / score_hi
; ---------------------------------------------------------------------
alphabeta
        jsr tester_temps
        lda temps_ecoule
        beq ab_profondeur
        ; le delai est epuise : on remonte sans rien evaluer, le resultat
        ; de cette iteration sera jete de toute facon
        lda #0
        sta score_lo
        sta score_hi
        rts
ab_profondeur
        lda prof_reste
        bne ab_generer
        jmp evaluer

ab_generer
        ; On retient alpha tel qu'il arrive : il dira, a la fin, si le
        ; score obtenu est la vraie valeur du noeud ou seulement une borne.
        ldx prof_rech
        lda rech_alpha_lo,x
        sta rech_alpha0_lo,x
        lda rech_alpha_hi,x
        sta rech_alpha0_hi,x
.if UTILISER_TABLE
        ; la clef est tenue a jour par jouer_rech et annuler_rech
        ; On ne consulte pas la table a la racine : il y faut le coup, et
        ; non seulement son score.
        lda prof_rech
        bne +
        jmp ab_sans_table
+       jsr sonder_table
        bne +
        jmp ab_sans_table
+       cmp #VAL_EXACTE
        bne +
        jmp ab_rendre       ; la valeur est deja dans score_lo / score_hi
+       cmp #VAL_MINOREE
        bne ab_majoree
        ; borne inferieure : elle ne peut que relever alpha
        ldx prof_rech
        lda score_lo
        sta cmp_a_lo
        lda score_hi
        sta cmp_a_hi
        lda rech_alpha_lo,x
        sta cmp_b_lo
        lda rech_alpha_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bmi ab_test_coupure
        beq ab_test_coupure
        ldx prof_rech
        lda score_lo
        sta rech_alpha_lo,x
        lda score_hi
        sta rech_alpha_hi,x
        jmp ab_test_coupure
ab_majoree
        ; borne superieure : elle ne peut qu'abaisser beta
        ldx prof_rech
        lda score_lo
        sta cmp_a_lo
        lda score_hi
        sta cmp_a_hi
        lda rech_beta_lo,x
        sta cmp_b_lo
        lda rech_beta_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bpl ab_test_coupure
        ldx prof_rech
        lda score_lo
        sta rech_beta_lo,x
        lda score_hi
        sta rech_beta_hi,x
ab_test_coupure
        ; la fenetre s'est-elle refermee ?
        ldx prof_rech
        lda rech_alpha_lo,x
        sta cmp_a_lo
        lda rech_alpha_hi,x
        sta cmp_a_hi
        lda rech_beta_lo,x
        sta cmp_b_lo
        lda rech_beta_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bpl +
        jmp ab_sans_table
+       ldx prof_rech
        lda rech_alpha_lo,x
        sta score_lo
        lda rech_alpha_hi,x
        sta score_hi
        jmp ab_rendre
.endif

ab_sans_table
        ; la tranche de coups de ce niveau commence ici ; on la rendra
        ; en repartant, pour que les niveaux superieurs gardent les leurs
        ldx prof_rech
        lda coups_fin
        sta rech_debut_lo,x
        lda coups_fin+1
        sta rech_debut_hi,x
        lda trait
        sta trait_gen
        jsr generer_pour_trait
        lda nb_coups
        bne ab_depart
        ; aucun coup : le camp au trait a perdu. On compte la defaite
        ; d'autant moins lourde qu'elle est lointaine, pour que la machine
        ; prefere resister plutot que d'abandonner tout de suite
        lda #<SCORE_MAT
        sec
        sbc prof_rech
        sta score_lo
        lda #>SCORE_MAT
        sbc #0
        sta score_hi
        jsr nier_score
        jmp ab_rendre

ab_depart
        ldx prof_rech
        sta rech_reste,x
        lda #$FF
        sta rech_rang,x     ; incremente avant chaque coup : 0 au premier
        lda coups_debut
        sta rech_ptr_lo,x
        lda coups_debut+1
        sta rech_ptr_hi,x
        ; a la racine, on range les coups dans une table pour pouvoir
        ; commencer par celui que l'iteration precedente a retenu
        lda prof_rech
        bne ab_boucle
        jsr construire_ordre

ab_boucle
        ; abandonner ne suffit pas a remonter : sans ce test, chaque niveau
        ; continuerait a parcourir tous ses coups, et la reflexion durerait
        ; bien au-dela du delai accorde
        lda temps_ecoule
        bne ab_fini_tot
        ldx prof_rech
        lda rech_reste,x
        bne ab_essayer
ab_fini_tot
        jmp ab_fini

ab_essayer
        inc rech_rang,x
        ; On garde le coup examine a ce niveau : les appels recursifs se
        ; servent de ptr_coup pour les leurs, et l'auraient ecrase au retour.
        lda prof_rech
        bne ab_sequentiel
        ; racine : l'ordre d'examen vient de la table
        ldy rech_rang,x
        lda ordre_lo,y
        sta ptr_coup
        sta rech_courant_lo,x
        lda ordre_hi,y
        sta ptr_coup+1
        sta rech_courant_hi,x
        dec rech_reste,x
        jmp ab_jouer
ab_sequentiel
        lda rech_ptr_lo,x
        sta ptr_coup
        sta rech_courant_lo,x
        lda rech_ptr_hi,x
        sta ptr_coup+1
        sta rech_courant_hi,x
        ; avance deja le pointeur sur le coup suivant : un coup occupe
        ; 3 octets plus une case par piece prise
        ldy #2
        lda (ptr_coup),y
        clc
        adc #3
        clc
        adc rech_ptr_lo,x
        sta rech_ptr_lo,x
        bcc +
        inc rech_ptr_hi,x
+       dec rech_reste,x
ab_jouer

        jsr jouer_rech
        ; la fenetre du niveau inferieur est celle-ci, retournee
        jsr descendre_fenetre
        inc prof_rech
        dec prof_reste
        jsr alphabeta
        dec prof_rech
        inc prof_reste
        jsr nier_score      ; le score revient du point de vue adverse
        jsr annuler_rech

        ; score > alpha ?
        ldx prof_rech
        lda score_lo
        sta cmp_a_lo
        lda score_hi
        sta cmp_a_hi
        lda rech_alpha_lo,x
        sta cmp_b_lo
        lda rech_alpha_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bmi ab_boucle_suite ; score <= alpha : ce coup n'apporte rien
        beq ab_boucle_suite
        ; nouveau meilleur score
        ldx prof_rech
        lda score_lo
        sta rech_alpha_lo,x
        lda score_hi
        sta rech_alpha_hi,x
        ; a la racine, on retient aussi le coup
        lda prof_rech
        bne ab_coupure
        ldx prof_rech
        lda rech_courant_lo,x
        sta meilleur_lo
        lda rech_courant_hi,x
        sta meilleur_hi
ab_coupure
        ; alpha >= beta : l'adversaire ne laissera jamais venir ici
        ldx prof_rech
        lda rech_alpha_lo,x
        sta cmp_a_lo
        lda rech_alpha_hi,x
        sta cmp_a_hi
        lda rech_beta_lo,x
        sta cmp_b_lo
        lda rech_beta_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bmi ab_boucle_suite
        jmp ab_fini         ; coupure
ab_boucle_suite
        jmp ab_boucle

ab_fini
        ; rend la tranche de coups et renvoie alpha
        ldx prof_rech
        lda rech_debut_lo,x
        sta coups_fin
        lda rech_debut_hi,x
        sta coups_fin+1
        lda rech_alpha_lo,x
        sta score_lo
        lda rech_alpha_hi,x
        sta score_hi
        ; on retient le resultat, sauf a la racine et sauf si le temps a
        ; interrompu la recherche : un score incomplet n'a pas de valeur
.if UTILISER_TABLE
        lda prof_rech
        beq ab_rendre
        lda temps_ecoule
        bne ab_rendre
        jsr nature_valeur
        jsr ranger_table
.endif
ab_rendre
        rts

; ---------------------------------------------------------------------
;  nature_valeur : le score obtenu est-il exact, ou seulement une borne ?
;  Un noeud dont aucun coup n'a depasse alpha ne livre qu'un majorant ;
;  un noeud coupe sur beta ne livre qu'un minorant.
; ---------------------------------------------------------------------
nature_valeur
        ldx prof_rech
        lda rech_alpha_lo,x
        sta cmp_a_lo
        lda rech_alpha_hi,x
        sta cmp_a_hi
        lda rech_alpha0_lo,x
        sta cmp_b_lo
        lda rech_alpha0_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        cmp #1
        beq nv_pas_majoree
        lda #VAL_MAJOREE
        rts
nv_pas_majoree
        ldx prof_rech
        lda rech_alpha_lo,x
        sta cmp_a_lo
        lda rech_alpha_hi,x
        sta cmp_a_hi
        lda rech_beta_lo,x
        sta cmp_b_lo
        lda rech_beta_hi,x
        sta cmp_b_hi
        jsr comparer_scores
        bmi nv_exacte
        lda #VAL_MINOREE
        rts
nv_exacte
        lda #VAL_EXACTE
        rts

; ---------------------------------------------------------------------
;  descendre_fenetre : prepare la fenetre du niveau inferieur
;  alpha' = -beta, beta' = -alpha
; ---------------------------------------------------------------------
descendre_fenetre
        ldx prof_rech
        lda rech_beta_lo,x
        sta score_lo
        lda rech_beta_hi,x
        sta score_hi
        jsr nier_score
        ldx prof_rech
        inx
        lda score_lo
        sta rech_alpha_lo,x
        lda score_hi
        sta rech_alpha_hi,x
        ldx prof_rech
        lda rech_alpha_lo,x
        sta score_lo
        lda rech_alpha_hi,x
        sta score_hi
        jsr nier_score
        ldx prof_rech
        inx
        lda score_lo
        sta rech_beta_lo,x
        lda score_hi
        sta rech_beta_hi,x
        rts

; ---------------------------------------------------------------------
;  chercher_meilleur_coup : lance la recherche a la profondeur A
;  Sortie  meilleur_lo / meilleur_hi pointent le coup retenu,
;          score_lo / score_hi donnent sa valeur.
; ---------------------------------------------------------------------
chercher_meilleur_coup
        sta prof_reste
        jsr calculer_cle    ; point de depart du hachage incremental
        lda #0
        sta prof_rech
        sta meilleur_lo
        sta meilleur_hi
        ; la pile d'annulation repart a vide
        lda #<annul_zone
        sta annul_ptr
        lda #>annul_zone
        sta annul_ptr+1
        ; la zone des coups aussi
        lda #<coups_zone
        sta coups_fin
        lda #>coups_zone
        sta coups_fin+1
        ; fenetre ouverte en grand
        ldx #0
        lda #<-SCORE_INF
        sta rech_alpha_lo,x
        lda #>-SCORE_INF
        sta rech_alpha_hi,x
        lda #<SCORE_INF
        sta rech_beta_lo,x
        lda #>SCORE_INF
        sta rech_beta_hi,x
        jmp alphabeta

; ---------------------------------------------------------------------
;  tester_temps : leve temps_ecoule quand le delai imparti est depasse
;  On ne compare que les deux octets de poids faible de l'horloge, ce qui
;  couvre 65536 images, soit plus de vingt minutes : largement de quoi.
;  Travailler sur la duree ecoulee plutot que sur une echeance absolue
;  rend le passage par zero de l'horloge sans consequence.
; ---------------------------------------------------------------------
tester_temps
        ; une limite nulle vaut "pas de limite" : c'est ainsi que le banc
        ; d'essai fait tourner la recherche jusqu'au bout
        lda limite_lo
        ora limite_hi
        beq tt_fin
        lda TI_BAS
        sec
        sbc debut_tps_lo
        sta pz_tmp
        lda TI_MOYEN
        sbc debut_tps_hi
        cmp limite_hi
        bcc tt_fin
        bne tt_depasse
        lda pz_tmp
        cmp limite_lo
        bcc tt_fin
tt_depasse
        lda #1
        sta temps_ecoule
tt_fin
        rts

; ---------------------------------------------------------------------
;  reflechir : approfondissement iteratif limite par le temps
;  Entree  limite_lo / limite_hi = duree accordee, en images (50 par
;          seconde), prof_max = profondeur a ne pas depasser.
;  Sortie  coup_ia_depart / coup_ia_arrivee = coup retenu, 0 si aucun,
;          prof_atteinte = derniere profondeur menee a terme.
;
;  On repart de zero a chaque profondeur, mais en examinant d'abord le
;  coup retenu la fois precedente : c'est tres souvent le meilleur, et
;  l'elaguer en premier fait tomber le reste beaucoup plus vite. Une
;  iteration interrompue par le temps est jetee : seul compte le dernier
;  resultat complet.
; ---------------------------------------------------------------------
reflechir
.if UTILISER_TABLE
        jsr vider_table
.endif     ; les scores d'une position passee ne valent
                            ; plus rien pour la suivante
        lda #0
        sta temps_ecoule
        sta prof_atteinte
        sta coup_ia_depart
        sta coup_ia_arrivee
        sta rang_prefere_actif
        lda TI_BAS
        sta debut_tps_lo
        lda TI_MOYEN
        sta debut_tps_hi
        lda #1
        sta prof_iter
ri_boucle
        lda prof_iter
        jsr chercher_meilleur_coup
        lda temps_ecoule
        bne ri_fin          ; iteration incomplete : on la jette
        ; on retient le coup de cette profondeur
        lda meilleur_lo
        ora meilleur_hi
        beq ri_fin          ; aucun coup legal
        lda meilleur_lo
        sta ptr_coup
        lda meilleur_hi
        sta ptr_coup+1
        ldy #0
        lda (ptr_coup),y
        sta coup_ia_depart
        iny
        lda (ptr_coup),y
        sta coup_ia_arrivee
        ; on recopie le coup entier : la zone sera reutilisee par
        ; l'iteration suivante, et deux rafles peuvent relier les memes
        ; cases sans prendre les memes pieces
        ldy #2
        lda (ptr_coup),y
        clc
        adc #3
        tay
        dey
ri_copie
        lda (ptr_coup),y
        sta coup_ia,y
        dey
        bpl ri_copie
        lda prof_iter
        sta prof_atteinte
        ; ce coup sera essaye en premier a la profondeur suivante
        lda #1
        sta rang_prefere_actif
        inc prof_iter
        lda prof_iter
        cmp prof_max
        beq ri_derniere
        bcs ri_fin
ri_derniere
        jmp ri_boucle
ri_fin
        rts

; ---------------------------------------------------------------------
;  avancer_ptr_coup : passe au coup suivant dans la liste
;  Un coup occupe 3 octets plus une case par piece prise.
; ---------------------------------------------------------------------
avancer_ptr_coup
        ldy #2
        lda (ptr_coup),y
        clc
        adc #3
        clc
        adc ptr_coup
        sta ptr_coup
        bcc +
        inc ptr_coup+1
+       rts

; ---------------------------------------------------------------------
;  construire_ordre : table des coups de la racine, dans l'ordre d'examen
;
;  Les coups n'ayant pas tous la meme longueur, les deplacer dans la zone
;  couterait cher ; on range donc leurs adresses dans une table, ou il
;  suffit d'echanger deux entrees. Le coup retenu a l'iteration precedente
;  passe en tete : c'est tres souvent le meilleur, et l'examiner d'abord
;  resserre la fenetre aussitot, ce qui elague tout le reste bien plus vite.
; ---------------------------------------------------------------------
construire_ordre
        lda coups_debut
        sta ptr_coup
        lda coups_debut+1
        sta ptr_coup+1
        ldx #0
co_remplir
        cpx nb_coups
        beq co_prefere
        lda ptr_coup
        sta ordre_lo,x
        lda ptr_coup+1
        sta ordre_hi,x
        jsr avancer_ptr_coup
        inx
        bne co_remplir
co_prefere
        lda rang_prefere_actif
        beq co_fin
        ldx #0
co_chercher
        cpx nb_coups
        beq co_fin          ; le coup n'existe plus dans cette position
        lda ordre_lo,x
        sta ptr_coup
        lda ordre_hi,x
        sta ptr_coup+1
        ldy #0
        lda (ptr_coup),y
        cmp coup_ia_depart
        bne co_suivant
        iny
        lda (ptr_coup),y
        cmp coup_ia_arrivee
        beq co_echanger
co_suivant
        inx
        bne co_chercher
co_echanger
        lda ordre_lo,x
        pha
        lda ordre_hi,x
        pha
        lda ordre_lo
        sta ordre_lo,x
        lda ordre_hi
        sta ordre_hi,x
        pla
        sta ordre_hi
        pla
        sta ordre_lo
co_fin
        rts

; =====================================================================
;  Table de transpositions
;
;  Une meme position se rencontre par des ordres de coups differents :
;  la retenir evite d'explorer deux fois le meme sous-arbre.
;
;  La clef est un hachage Zobrist de 16 bits, recalcule a chaque noeud
;  plutot que tenu a jour au fil des coups : parcourir les cinquante
;  cases coute environ un millieme de seconde, soit quelques pour cent
;  du temps d'un noeud, pour beaucoup moins de risques d'erreur.
;
;  La table compte 1024 entrees de 8 octets, logees en RAM ordinaire :
;    0-1 clef, 2-3 score, 4 profondeur, 5 nature de la valeur.
;  La nature dit si le score est exact ou n'est qu'une borne, car un
;  sous-arbre elague ne livre qu'un encadrement.
; =====================================================================

; ---------------------------------------------------------------------
;  calculer_cle : hachage de la position courante
; ---------------------------------------------------------------------
calculer_cle
        lda #0
        sta cle_lo
        sta cle_hi
        lda #1
        sta ck_num
ck_boucle
        ldx ck_num
        dex
        ldy num_vers_idx,x
        lda plateau,y
        beq ck_suivant
        cmp #BORD
        beq ck_suivant
        sta xp_type
        lda ck_num
        sta xp_case
        jsr xor_piece
ck_suivant
        inc ck_num
        lda ck_num
        cmp #51
        bne ck_boucle
        ; le camp au trait fait partie de la position
        lda trait
        beq ck_fin
        lda zob_trait
        eor cle_lo
        sta cle_lo
        lda zob_trait+1
        eor cle_hi
        sta cle_hi
ck_fin
        rts

; ---------------------------------------------------------------------
;  xor_piece : combine a la clef la piece xp_type sur la case xp_case
; ---------------------------------------------------------------------
xor_piece
        ldx xp_type
        dex
        lda zob_base,x
        clc
        adc xp_case
        sec
        sbc #1
        tax
        lda zobrist_lo,x
        eor cle_lo
        sta cle_lo
        lda zobrist_hi,x
        eor cle_hi
        sta cle_hi
        rts

; ---------------------------------------------------------------------
;  pointer_entree : place ptr_table sur l'entree de la clef courante
;  L'index est fait des dix bits de poids faible de la clef, multiplies
;  par huit : une entree occupe huit octets.
; ---------------------------------------------------------------------
pointer_entree
        lda cle_lo
        sta ptr_table
        lda cle_hi
        and #$03
        sta ptr_table+1
        ldx #3
pe_decaler
        asl ptr_table
        rol ptr_table+1
        dex
        bne pe_decaler
        lda ptr_table+1
        clc
        adc #>table_trans
        sta ptr_table+1
        rts

; ---------------------------------------------------------------------
;  sonder_table : cherche la position courante dans la table
;  Sortie  A = 0 si rien d'utilisable, sinon la nature de la valeur,
;          score_lo / score_hi portant alors le score retenu.
; ---------------------------------------------------------------------
sonder_table
        jsr pointer_entree
        ldy #0
        lda (ptr_table),y
        cmp cle_lo
        bne st_rien
        iny
        lda (ptr_table),y
        cmp cle_hi
        bne st_rien
        ; la profondeur enregistree doit valoir celle qu'on cherche
        ldy #4
        lda (ptr_table),y
        cmp prof_reste
        bcc st_rien         ; moins profond : la valeur ne vaut rien ici
        ldy #2
        lda (ptr_table),y
        sta score_lo
        iny
        lda (ptr_table),y
        sta score_hi
        ldy #5
        lda (ptr_table),y
        rts
st_rien
        lda #0
        rts

; ---------------------------------------------------------------------
;  ranger_table : enregistre le resultat du noeud courant
;  Entree  A = nature de la valeur, score_lo / score_hi = score
; ---------------------------------------------------------------------
ranger_table
        sta rt_nature
        jsr pointer_entree
        ldy #0
        lda cle_lo
        sta (ptr_table),y
        iny
        lda cle_hi
        sta (ptr_table),y
        iny
        lda score_lo
        sta (ptr_table),y
        iny
        lda score_hi
        sta (ptr_table),y
        iny
        lda prof_reste
        sta (ptr_table),y
        iny
        lda rt_nature
        sta (ptr_table),y
        rts

; ---------------------------------------------------------------------
;  vider_table : efface la table, au debut de chaque reflexion
; ---------------------------------------------------------------------
vider_table
        lda #<table_trans
        sta ptr_table
        lda #>table_trans
        sta ptr_table+1
        ldx #TAILLE_TABLE_PAGES
        lda #0
        ldy #0
vt_page
        sta (ptr_table),y
        iny
        bne vt_page
        inc ptr_table+1
        dex
        bne vt_page
        rts

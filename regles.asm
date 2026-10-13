; =====================================================================
;  regles.asm - etat de la partie
;  Etape 1 : mise en place et deplacement libre, sans aucun controle
;  de legalite. Le generateur de coups complet viendra a l'etape 2.
; =====================================================================

; ---------------------------------------------------------------------
;  nouvelle_partie : position de depart et redessin complet
;  Noirs sur les cases 1 a 20, Blancs sur les cases 31 a 50.
; ---------------------------------------------------------------------
nouvelle_partie
        ; bordure (cases fantomes) sur tout le plateau ; on compte en
        ; montant, car 143 a son bit de signe a 1 et une boucle terminee
        ; par BPL s'arreterait des le premier tour
        lda #BORD
        ldx #0
-       sta plateau,x
        inx
        cpx #144
        bne -
        ; les 50 cases jouables
        ldx #49
np_case
        ldy num_vers_idx,x
        lda #PION_B
        cpx #30             ; index 30 = case 31
        bcs np_pose
        lda #VIDE
        cpx #20             ; index 20 = case 21
        bcs np_pose
        lda #PION_N
np_pose
        sta plateau,y
        dex
        bpl np_case

        lda #BLANC
        sta trait
        lda #0
        sta selection
        sta nb_saisie
        sta demande_fin
        sta mode_saisie
        ; le curseur part de la case 32, faute d'un coup precedent
        lda #CASE_DEPART
        sta curseur
        lda #20
        sta nb_blancs
        sta nb_noirs
        ; historique vide, y compris l'entree mise de cote
        lda #CAR_ESPACE
        ldx #HIST_LG*HIST_NB-1
-       sta historique,x
        dex
        bpl -
        lda #CAR_ESPACE
        ldx #HIST_LG-1
-       sta hist_perdue,x
        dex
        bpl -

        lda #0
        sta partie_finie
        jsr init_pile_partie
        jsr generer_coups
        jsr dessiner_damier
        jsr afficher_historique
        jsr maj_panneau
        jmp maj_etat

; ---------------------------------------------------------------------
;  piece_au_trait : la piece A appartient-elle au camp au trait ?
;  Entree  A = contenu d'une case (PION_B..DAME_N)
;  Sortie  Z = 1 si la piece est du camp au trait
; ---------------------------------------------------------------------
piece_au_trait
        sec
        sbc #1              ; 0,1 = blanc ; 2,3 = noir
        lsr a               ; 0 = blanc ; 1 = noir
        cmp trait
        rts

; ---------------------------------------------------------------------
;  chercher_coup : coups allant de "selection" vers "arrivee_voulue",
;  parmi ceux qui prennent toutes les cases imposees (filtres).
;  Sortie  A = nombre trouve, premier_coup = index du premier.
;  Plusieurs coups de memes extremites signalent une rafle ambigue : deux
;  chemins qui prennent des pieces differentes. Le joueur les departage en
;  designant une piece a prendre, ajoutee aux filtres.
; ---------------------------------------------------------------------
chercher_coup
        lda #0
        sta cmp_resultat
        ldx #0
cc_boucle
        cpx nb_coups
        beq cc_fin
        stx cmp_num
        txa
        jsr pointer_coup
        ldy #0
        lda (ptr_coup),y
        cmp selection
        bne cc_suivant
        iny
        lda (ptr_coup),y
        cmp arrivee_voulue
        bne cc_suivant
        jsr coup_suit_filtres
        bne cc_suivant
        lda cmp_resultat
        bne cc_compter
        lda cmp_num
        sta premier_coup
cc_compter
        inc cmp_resultat
cc_suivant
        ldx cmp_num
        inx
        bne cc_boucle
cc_fin
        lda cmp_resultat
        rts

; ---------------------------------------------------------------------
;  coup_suit_filtres : le coup pointe par ptr_coup prend-il toutes les
;  cases imposees ? Sortie Z = 1 si oui.
; ---------------------------------------------------------------------
coup_suit_filtres
        lda nb_filtres
        beq csf_oui
        lda #0
        sta cmp_i
csf_filtre
        lda cmp_i
        cmp nb_filtres
        beq csf_oui
        tax
        lda filtres,x
        sta cmp_valeur
        ldy #2
        lda (ptr_coup),y
        sta cmp_total
        lda #0
        sta cmp_j
csf_prise
        lda cmp_j
        cmp cmp_total
        beq csf_non
        clc
        adc #3              ; les prises commencent au 4e octet
        tay
        lda (ptr_coup),y
        cmp cmp_valeur
        beq csf_trouvee
        inc cmp_j
        jmp csf_prise
csf_trouvee
        inc cmp_i
        jmp csf_filtre
csf_oui
        lda #0
        rts
csf_non
        lda #1
        rts

; ---------------------------------------------------------------------
;  oublier_rafle : abandonne la destination en attente et ses filtres
; ---------------------------------------------------------------------
oublier_rafle
        lda #0
        sta attente_rafle
        sta nb_filtres
        rts

; ---------------------------------------------------------------------
;  jouer_coup_choisi : applique le coup A, redessine, passe la main
; ---------------------------------------------------------------------
jouer_coup_choisi
        ; on montre le coup avant de l'appliquer : l'animation a besoin
        ; du plateau tel qu'il est encore
        jsr pointer_coup
        jsr animer_coup
        jsr appliquer_coup_ptr
        jmp jouer_suite

; Variante pour le coup de la machine, deja pointe par ptr_coup.
jouer_coup_pointe
        jsr animer_coup
        jsr appliquer_coup_ptr
jouer_suite
        jsr oublier_rafle
        ; les pieces prises appartiennent au camp adverse
        lda trait
        bne jcc_noirs
        lda nb_noirs
        sec
        sbc coup_nb_prises
        sta nb_noirs
        jmp jcc_hist
jcc_noirs
        lda nb_blancs
        sec
        sbc coup_nb_prises
        sta nb_blancs
jcc_hist
        jsr ajouter_historique
        ; apres ajouter_historique seulement : c'est lui qui met de cote
        ; l'entree chassee, que l'entree de pile doit emporter
        jsr empiler_coup
        lda #0
        sta selection
        ; redessin des cases touchees seulement
        lda coup_depart
        jsr dessiner_case
        lda coup_arrivee
        jsr dessiner_case
        ldx #0
jcc_redessin
        cpx coup_nb_prises
        beq jcc_trait
        stx pz_tmp
        lda prises_cases,x
        jsr dessiner_case
        ldx pz_tmp
        inx
        bne jcc_redessin
jcc_trait
        lda trait
        eor #1
        sta trait
        lda coup_arrivee
        sta curseur         ; le curseur suit la derniere piece jouee
        jsr dessiner_case
        jsr maj_panneau
        jsr afficher_historique
        jsr maj_etat
        jsr generer_coups
        ; plus aucun coup pour le camp au trait : la partie est finie
        lda nb_coups
        beq jcc_finie
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp afficher_camp_msg
jcc_finie
        lda #1
        sta partie_finie
        lda #<t_m_fini
        ldx #>t_m_fini
        jsr message
        ; le camp qui ne peut plus jouer a perdu : le gagnant est l'autre
        lda #LIG_MSG
        sta tmp_ligne
        lda #COL_GAGNANT
        sta tmp_colonne
        lda trait
        eor #1
        jmp afficher_camp

; ---------------------------------------------------------------------
;  ajouter_historique : empile "nn-mm " en tete de la liste des coups
; ---------------------------------------------------------------------
ajouter_historique
        ; decale les entrees d'un cran, la plus ancienne est perdue
        ldx #HIST_LG*HIST_NB-1
ah_decale
        lda historique-HIST_LG,x
        sta historique,x
        dex
        cpx #HIST_LG-1
        bne ah_decale
        ; nouvelle entree : depart, separateur, arrivee. Le separateur
        ; distingue un simple deplacement (-) d'une prise (X).
        lda coup_depart
        jsr decimal
        lda v_dizaine
        ora #CAR_ZERO
        sta historique+0
        lda v_unite
        ora #CAR_ZERO
        sta historique+1
        ldx #CAR_TIRET
        lda coup_nb_prises
        beq ah_separateur
        ldx #CAR_PRISE
ah_separateur
        stx historique+2
        lda coup_arrivee
        jsr decimal
        lda v_dizaine
        ora #CAR_ZERO
        sta historique+3
        lda v_unite
        ora #CAR_ZERO
        sta historique+4
        lda #CAR_ESPACE
        sta historique+5
        rts

; ---------------------------------------------------------------------
;  afficher_historique : recopie les 4 derniers coups lignes 8 a 11
; ---------------------------------------------------------------------
afficher_historique
        lda #0
        sta tmp_index
ah2_boucle
        lda tmp_index
        clc
        adc #8              ; les coups occupent les lignes 8 a 11
        ldx #PAN_X+5
        jsr pos_ecran
        ; decalage dans la table : 6 * numero d'entree
        lda tmp_index
        asl a
        sta tmp_car
        asl a
        clc
        adc tmp_car
        tax
        ldy #0
-       lda historique,x
        sta (ptr_ecran),y
        inx
        iny
        cpy #HIST_LG
        bne -
        inc tmp_index
        lda tmp_index
        cmp #HIST_NB
        bne ah2_boucle
        rts

; ---------------------------------------------------------------------
;  afficher_camp : ecrit BLANCS ou NOIRS en (tmp_ligne, tmp_colonne)
;  Entree  A = BLANC ou NOIR
; ---------------------------------------------------------------------
afficher_camp
        sta tmp_car
        lda #0
        sta attr_texte
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #6
        jsr remplir
        lda #<t_blancs
        ldy #>t_blancs
        ldx tmp_car
        cpx #BLANC
        beq ac_pose
        lda #<t_noirs
        ldy #>t_noirs
ac_pose
        sta ptr_texte
        sty ptr_texte+1
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        jmp afficher_texte

; ---------------------------------------------------------------------
;  afficher_camp_msg : complete le message par le camp au trait
; ---------------------------------------------------------------------
afficher_camp_msg
        lda #LIG_MSG
        sta tmp_ligne
        lda #COL_CAMP_MSG
        sta tmp_colonne
        lda trait
        jmp afficher_camp

; ---------------------------------------------------------------------
;  afficher_aucun : les deux camps sont tenus par des joueurs
; ---------------------------------------------------------------------
afficher_aucun
        lda #0
        sta attr_texte
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #6
        jsr remplir
        lda #<t_aucun
        sta ptr_texte
        lda #>t_aucun
        sta ptr_texte+1
        lda tmp_ligne
        ldx tmp_colonne
        jsr pos_ecran
        jmp afficher_texte

; ---------------------------------------------------------------------
;  maj_panneau : rafraichit le panneau d'informations
; ---------------------------------------------------------------------
maj_panneau
        lda #0
        sta attr_texte
        ; ligne 2 : camp au trait
        lda #2
        sta tmp_ligne
        lda #PAN_X+9
        sta tmp_colonne
        lda trait
        jsr afficher_camp
        ; ligne 3 : camp tenu par l'ordinateur
        lda #3
        sta tmp_ligne
        lda #PAN_X+9
        sta tmp_colonne
        lda camp_ordi
        cmp #ORDI_AUCUN
        bne mp_ordi_camp
        jsr afficher_aucun
        jmp mp_niveau
mp_ordi_camp
        jsr afficher_camp
mp_niveau
        ; ligne 4 : niveau
        lda #4
        sta tmp_ligne
        lda niveau
        ldx #PAN_X+9
        jsr afficher_nb2
        ; ligne 5 : pieces restantes de chaque camp
        lda #5
        sta tmp_ligne
        lda nb_blancs
        ldx #PAN_X+9
        jsr afficher_nb2
        lda #5
        sta tmp_ligne
        lda nb_noirs
        ldx #PAN_X+14
        jmp afficher_nb2

; ---------------------------------------------------------------------
;  tour_ordinateur : si c'est a la machine de jouer, elle reflechit
;  puis joue. Appele depuis la boucle principale.
; ---------------------------------------------------------------------
tour_ordinateur
        lda partie_finie
        bne to_fin
        lda trait
        cmp camp_ordi
        beq to_jouer
to_fin
        rts
to_jouer
        ; prevenir avant de se taire plusieurs secondes
        lda #<t_m_reflexion
        ldx #>t_m_reflexion
        jsr message
        ; duree et profondeur accordees par le niveau
        ldx niveau
        dex
        lda niveau_limite_lo,x
        sta limite_lo
        lda niveau_limite_hi,x
        sta limite_hi
        lda niveau_prof,x
        sta prof_max
        jsr reflechir
        lda coup_ia_depart
        beq to_sans_coup
        ; joue le coup retenu, recopie a part
        lda #<coup_ia
        sta ptr_coup
        lda #>coup_ia
        sta ptr_coup+1
        jmp jouer_coup_pointe
to_sans_coup
        ; la machine n'a plus aucun coup : elle a perdu
        lda #1
        sta partie_finie
        lda #<t_m_fini
        ldx #>t_m_fini
        jsr message
        lda #LIG_MSG
        sta tmp_ligne
        lda #COL_GAGNANT
        sta tmp_colonne
        lda trait
        eor #1
        jmp afficher_camp


; =====================================================================
;  Retour arriere
;
;  Chaque coup joue pour de bon depose dans annul_partie de quoi le
;  defaire, sous la forme :
;      [6 octets d'historique chasse][piece d'origine][depart][arrivee]
;      [nombre de prises][(case, piece) par prise][longueur de l'entree]
;  La longueur est ecrite en dernier : c'est par elle qu'on retrouve le
;  debut de l'entree en remontant.
; =====================================================================

; ---------------------------------------------------------------------
;  init_pile_partie : repart d'une partie sans passe
; ---------------------------------------------------------------------
init_pile_partie
        lda #<annul_partie
        sta ptr_part
        lda #>annul_partie
        sta ptr_part+1
        lda #0
        sta nb_demi_coups
        rts

empiler_part
        ldy #0
        sta (ptr_part),y
        inc ptr_part
        bne +
        inc ptr_part+1
+       rts

depiler_part
        lda ptr_part
        bne +
        dec ptr_part+1
+       dec ptr_part
        ldy #0
        lda (ptr_part),y
        rts

; ---------------------------------------------------------------------
;  empiler_coup : range de quoi defaire le coup qui vient d'etre joue
;  Si la pile est pleine, on cesse d'empiler : le retour arriere ne
;  remontera pas au-dela, mais rien n'est abime.
; ---------------------------------------------------------------------
empiler_coup
        ; place restante : il faut au plus 11 + 2 * MAX_PRISES octets
        lda ptr_part+1
        cmp #>FIN_ANNUL_PARTIE
        bcc ec_place
        rts
ec_place
        ldx #0
ec_hist
        lda hist_perdue,x
        jsr empiler_part
        inx
        cpx #HIST_LG
        bne ec_hist
        lda coup_origine
        jsr empiler_part
        lda coup_depart
        jsr empiler_part
        lda coup_arrivee
        jsr empiler_part
        lda coup_nb_prises
        jsr empiler_part
        ldx #0
ec_prises
        cpx coup_nb_prises
        beq ec_longueur
        stx pz_tmp
        lda prises_cases,x
        jsr empiler_part
        ldx pz_tmp
        lda prises_pieces,x
        jsr empiler_part
        ldx pz_tmp
        inx
        bne ec_prises
ec_longueur
        ; longueur de l'entree : 11 fixes plus deux octets par prise
        lda coup_nb_prises
        asl a
        clc
        adc #11
        jsr empiler_part
        inc nb_demi_coups
        rts

; ---------------------------------------------------------------------
;  defaire_un_coup : remet le plateau comme avant le dernier coup joue
;  Sortie  C = 1 si un coup a ete defait, 0 s'il n'y avait rien.
;  La longueur etant ecrite en fin d'entree, on recule d'abord dessus,
;  puis on relit l'entree en avant, dans l'ordre ou elle a ete ecrite.
; ---------------------------------------------------------------------
defaire_un_coup
        lda nb_demi_coups
        bne du_suite
        clc
        rts
du_suite
        dec nb_demi_coups
        jsr depiler_part
        sta du_long
        ; ptr_part designe l'octet de longueur : le debut de l'entree est
        ; (longueur - 1) octets plus haut, et devient le nouveau sommet
        sec
        lda ptr_part
        sbc du_long
        sta ptr_part
        bcs +
        dec ptr_part+1
+       inc ptr_part
        bne +
        inc ptr_part+1
+
        ; relecture de l'entree
        ldy #0
du_hist
        lda (ptr_part),y
        sta hist_perdue,y
        iny
        cpy #HIST_LG
        bne du_hist
        lda (ptr_part),y
        sta coup_origine
        iny
        lda (ptr_part),y
        sta coup_depart
        iny
        lda (ptr_part),y
        sta coup_arrivee
        iny
        lda (ptr_part),y
        sta coup_nb_prises
        ldx #0
du_prises
        cpx coup_nb_prises
        beq du_plateau
        iny
        lda (ptr_part),y
        sta prises_cases,x
        iny
        lda (ptr_part),y
        sta prises_pieces,x
        inx
        bne du_prises

du_plateau
        ; la piece regagne sa case de depart, sous sa nature d'avant
        ; promotion : une dame faite au dernier coup redevient pion
        ldx coup_depart
        dex
        ldy num_vers_idx,x
        lda coup_origine
        sta plateau,y
        ldx coup_arrivee
        dex
        ldy num_vers_idx,x
        lda #VIDE
        sta plateau,y
        ; les pieces prises reparaissent
        ldx #0
du_rendre
        cpx coup_nb_prises
        beq du_compteurs
        stx pz_tmp
        lda prises_cases,x
        tax
        dex
        ldy num_vers_idx,x
        ldx pz_tmp
        lda prises_pieces,x
        sta plateau,y
        inx
        bne du_rendre
du_compteurs
        ; le trait revient a celui qui venait de jouer
        lda trait
        eor #1
        sta trait
        ; les pieces rendues sont celles de son adversaire
        lda trait
        bne du_noirs
        lda nb_noirs
        clc
        adc coup_nb_prises
        sta nb_noirs
        jmp du_historique
du_noirs
        lda nb_blancs
        clc
        adc coup_nb_prises
        sta nb_blancs
du_historique
        jsr retirer_historique
        sec
        rts

; ---------------------------------------------------------------------
;  retirer_historique : l'inverse d'ajouter_historique
; ---------------------------------------------------------------------
retirer_historique
        ldx #0
rh_decale
        lda historique+HIST_LG,x
        sta historique,x
        inx
        cpx #HIST_LG*(HIST_NB-1)
        bne rh_decale
        ; l'entree chassee en son temps revient au bout de la liste
        ldx #0
rh_rendre
        lda hist_perdue,x
        sta historique+HIST_LG*(HIST_NB-1),x
        inx
        cpx #HIST_LG
        bne rh_rendre
        rts

; ---------------------------------------------------------------------
;  retour_arriere : ramene le joueur a sa position precedente
;  On defait un coup, puis on continue tant que c'est a la machine de
;  jouer : s'arreter sur son trait n'aurait pas de sens, elle rejouerait
;  aussitot le meme coup.
; ---------------------------------------------------------------------
retour_arriere
        jsr defaire_un_coup
        bcc ra_rien
ra_encore
        lda camp_ordi
        cmp #ORDI_AUCUN
        beq ra_fini
        lda trait
        cmp camp_ordi
        bne ra_fini
        jsr defaire_un_coup
        bcs ra_encore
ra_fini
        lda #0
        sta partie_finie
        sta selection
        jsr oublier_rafle
        lda coup_depart
        sta curseur         ; le curseur se pose sur la piece revenue
        jsr generer_coups
        jsr dessiner_damier
        jsr afficher_historique
        jsr maj_panneau
        jsr maj_etat
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp afficher_camp_msg
ra_rien
        lda #<t_m_rien_defaire
        ldx #>t_m_rien_defaire
        jmp message

; =====================================================================
;  clavier.asm - deplacement du curseur, choix des pieces et saisie
;
;  Deux modes :
;    - navigation (par defaut) : le curseur se promene sur les cases
;      foncees, ESPACE ou RETURN choisit une piece puis joue le coup ;
;    - saisie en notation : ouverte par "*", on tape le numero de la case
;      et RETURN y amene le curseur avant de valider.
; =====================================================================

COL_SAISIE  = 13            ; premiere colonne libre apres "VOTRE COUP : "
COL_CASE    = 5             ; premiere colonne libre apres "CASE "

; ---------------------------------------------------------------------
;  maj_etat : redessine la ligne 24 selon le mode en cours
;    navigation : "CASE nn", numero de la case sous le curseur
;    saisie     : "VOTRE COUP : nn-" puis les chiffres tapes et le curseur
;  Le rappel des touches, a droite, n'est jamais efface.
; ---------------------------------------------------------------------
maj_etat
        lda #0
        sta attr_texte
        lda #LIG_SAISIE
        ldx #0
        jsr pos_ecran
        lda #CAR_ESPACE
        ldx #LG_ETAT
        jsr remplir
        lda mode_saisie
        bne me_saisie

; --- mode navigation : numero de la case pointee ---------------------
        lda #<t_case
        sta ptr_texte
        lda #>t_case
        sta ptr_texte+1
        lda #LIG_SAISIE
        ldx #0
        jsr pos_ecran
        jsr afficher_texte
        lda #LIG_SAISIE
        sta tmp_ligne
        lda curseur
        ldx #COL_CASE
        jmp afficher_nb2

; --- mode saisie : "VOTRE COUP : " puis ce qui a ete tape ------------
me_saisie
        lda #<t_votre
        sta ptr_texte
        lda #>t_votre
        sta ptr_texte+1
        lda #LIG_SAISIE
        ldx #0
        jsr pos_ecran
        jsr afficher_texte
        lda #COL_SAISIE
        sta tmp_colonne
        ; piece deja choisie : on rappelle "nn-"
        lda selection
        beq ms_chiffres
        sta pz_tmp
        lda #LIG_SAISIE
        sta tmp_ligne
        lda pz_tmp
        ldx tmp_colonne
        jsr afficher_nb2
        lda #CAR_TIRET
        ldy #2
        sta (ptr_ecran),y
        lda tmp_colonne
        clc
        adc #3
        sta tmp_colonne
ms_chiffres
        ldx #0
ms_boucle
        cpx nb_saisie
        beq ms_curseur
        stx tmp_index
        lda #LIG_SAISIE
        ldx tmp_colonne
        jsr pos_ecran
        ldx tmp_index
        lda saisie,x
        ora #CAR_ZERO
        ldy #0
        sta (ptr_ecran),y
        inc tmp_colonne
        ldx tmp_index
        inx
        bne ms_boucle
ms_curseur
        lda tmp_colonne
        sta col_curseur
        ; fallthrough : pose le curseur dans sa phase courante

; ---------------------------------------------------------------------
;  maj_curseur_texte : curseur clignotant de la ligne de saisie
; ---------------------------------------------------------------------
maj_curseur_texte
        lda #LIG_SAISIE
        ldx col_curseur
        jsr pos_ecran
        lda clign_phase
        beq mc_eteint
        lda #CAR_ESP_INV
        bne mc_pose
mc_eteint
        lda #CAR_ESPACE
mc_pose
        ldy #0
        sta (ptr_ecran),y
        rts

; ---------------------------------------------------------------------
;  clignoter : fait battre le curseur de case, et celui de la saisie
;  La cadence vient de l'horloge systeme : le bit 4 des jiffies change
;  toutes les 16 images, soit environ 3 Hz en 50 Hz.
; ---------------------------------------------------------------------
clignoter
        lda JIFFY_LO
        and #$10
        cmp clign_phase
        beq cl_fin
        sta clign_phase
        lda curseur
        jsr dessiner_case
        lda mode_saisie
        beq cl_fin
        jmp maj_curseur_texte
cl_fin
        rts

; ---------------------------------------------------------------------
;  case_voisine : case atteinte depuis le curseur dans la direction A
;  Entree  A = DIR_GAUCHE .. DIR_D_BD
;  Sortie  A = numero de la case destination, 0 si le bord l'interdit
; ---------------------------------------------------------------------
case_voisine
        cmp #DIR_GAUCHE
        beq cv_gauche
        cmp #DIR_DROITE
        beq cv_droite
        cmp #DIR_HAUT
        beq cv_haut
        cmp #DIR_BAS
        beq cv_bas
        ; diagonales : un decalage constant dans le plateau suffit, les
        ; cases fantomes de la bordure se reconnaissent a leur numero nul
        sec
        sbc #DIR_D_HG
        tax
        lda dir_decalage,x
        sta pz_tmp
        ldx curseur
        dex
        lda num_vers_idx,x
        clc
        adc pz_tmp
        tax
        lda idx_vers_num,x
        rts

; gauche et droite : case foncee voisine de la meme rangee. Les cinq cases
; d'une rangee portent des numeros consecutifs, il suffit donc de regarder
; le rang dans la rangee.
cv_gauche
        lda curseur
        sec
        sbc #1
        jsr div5
        lda v_unite
        beq cv_non          ; deja la premiere case de la rangee
        lda curseur
        sec
        sbc #1
        rts
cv_droite
        lda curseur
        sec
        sbc #1
        jsr div5
        lda v_unite
        cmp #4
        beq cv_non          ; deja la derniere case de la rangee
        lda curseur
        clc
        adc #1
        rts

; haut et bas : rangee voisine, case foncee la plus proche dans la meme
; colonne. Les deux candidates sont a egale distance (une colonne) ; on
; retient celle de meme rang dans la rangee, soit n-5 et n+5. Le curseur
; zigzague alors d'une colonne mais ne derive pas.
cv_haut
        lda curseur
        cmp #6
        bcc cv_non          ; cases 1 a 5 : pas de rangee au-dessus
        sec
        sbc #5
        rts
cv_bas
        lda curseur
        cmp #46
        bcs cv_non          ; cases 46 a 50 : pas de rangee en dessous
        clc
        adc #5
        rts
cv_non
        lda #0
        rts

; ---------------------------------------------------------------------
;  deplacer_curseur : amene le curseur sur la case A
;  Une case nulle (bord atteint) laisse tout en place.
; ---------------------------------------------------------------------
deplacer_curseur
        cmp #0
        beq dep_fin
        sta pz_tmp
        lda curseur
        pha
        lda pz_tmp
        sta curseur         ; mis a jour avant les redessins, pour que
        pla                 ; l'ancienne case perde bien son curseur
        jsr dessiner_case
        lda curseur
        jsr dessiner_case
        jmp maj_etat
dep_fin
        rts

; ---------------------------------------------------------------------
;  valider : ESPACE ou RETURN sur la case pointee par le curseur
; ---------------------------------------------------------------------
valider
        lda partie_finie
        beq +
        jmp val_finie
+       lda curseur
        jsr contenu_case
        bne +
        jmp val_vide

        ; --- il y a une piece sur la case ---
+       jsr piece_au_trait
        beq +
        jmp val_adverse
+
        lda curseur
        cmp selection
        beq val_deselect    ; la piece deja choisie : on la relache
        jsr oublier_rafle
        ; la prise etant obligatoire, une piece peut n'avoir aucun coup
        lda curseur
        jsr compter_coups_piece
        beq val_muette
        ; choix, ou changement de choix
        lda selection
        pha
        lda curseur
        sta selection
        pla
        beq val_marquer     ; il n'y avait pas de choix precedent
        jsr dessiner_case   ; efface le marquage de l'ancienne case
val_marquer
        lda selection
        jsr dessiner_case
        jmp message_selection

val_deselect
        jsr oublier_rafle
        jmp deselectionner

val_adverse
        ; une rafle ambigue attend d'etre departagee : designer une piece
        ; adverse revient a choisir le chemin qui la prend
        lda attente_rafle
        beq val_adverse_msg
        lda nb_filtres
        cmp #MAX_FILTRES
        bcs val_adverse_msg
        tax
        lda curseur
        sta filtres,x
        inc nb_filtres
        jsr chercher_coup
        beq val_chemin_faux
        cmp #1
        beq val_unique
        lda #<t_m_ambigu
        ldx #>t_m_ambigu
        jmp message
val_chemin_faux
        ; cette piece n'est sur aucun des chemins proposes
        dec nb_filtres
        lda #<t_m_pas_chemin
        ldx #>t_m_pas_chemin
        jmp message
val_adverse_msg
        lda #<t_m_adverse
        ldx #>t_m_adverse
        jmp message

val_muette
        ; soit une prise est possible ailleurs, soit la piece est bloquee
        lda meilleure_prise
        beq val_bloquee
        lda #<t_m_prise_obli
        ldx #>t_m_prise_obli
        jmp message
val_bloquee
        lda #<t_m_bloquee
        ldx #>t_m_bloquee
        jmp message

val_finie
        lda #<t_m_fini
        ldx #>t_m_fini
        jmp message

        ; --- la case est vide ---
val_vide
        lda selection
        beq val_sans_choix
        ; toute case d'arrivee designee repart d'une rafle vierge
        jsr oublier_rafle
        lda curseur
        sta arrivee_voulue
        jsr chercher_coup
        beq val_refuse
        cmp #1
        beq val_unique
        ; plusieurs chemins menent a cette case en prenant des pieces
        ; differentes : le joueur designe une piece a prendre
        lda #1
        sta attente_rafle
        lda #<t_m_ambigu
        ldx #>t_m_ambigu
        jmp message
val_unique
        lda premier_coup
        jmp jouer_coup_choisi
val_refuse
        lda #<t_m_illegal
        ldx #>t_m_illegal
        jmp message
val_sans_choix
        lda #<t_m_vide
        ldx #>t_m_vide
        jmp message

; ---------------------------------------------------------------------
;  traiter_touche : aiguille la touche A selon le mode en cours
; ---------------------------------------------------------------------
traiter_touche
        ldx mode_saisie
        beq +
        jmp tt_saisie
+

; --- mode navigation -------------------------------------------------
        cmp #TOUCHE_ESP
        beq tt_valider
        cmp #TOUCHE_RET
        beq tt_valider
        cmp #TOUCHE_SAISIE
        beq tt_vers_ouvrir
        cmp #TOUCHE_Q
        beq tt_quitter
        cmp #TOUCHE_N
        beq tt_nouvelle
        cmp #TOUCHE_AIDE
        beq tt_vers_aide
        cmp #TOUCHE_ORDI
        beq tt_ordi
        cmp #TOUCHE_RETOUR
        beq tt_retour
        cmp #TOUCHE_MENU
        beq tt_menu
        cmp #TOUCHE_ANIM
        beq tt_anim
        ; reste les touches de deplacement
        ldx #0
tn_boucle
        cmp nav_touches,x
        beq tn_trouve
        inx
        cpx #NAV_NOMBRE
        bne tn_boucle
tt_rien
        rts
tn_trouve
        lda nav_directions,x
        jsr case_voisine
        jmp deplacer_curseur

tt_vers_ouvrir
        jmp tt_ouvrir
tt_vers_aide
        jmp tt_aide

tt_valider
        jmp valider

tt_quitter
        lda #1
        sta demande_fin
        rts

tt_nouvelle
        jsr nouvelle_partie
        lda #<t_m_nouvelle
        ldx #>t_m_nouvelle
        jmp message

tt_retour
        jmp retour_arriere

tt_menu
        lda #1
        sta retour_menu
        rts

; A : avec ou sans l'animation des prises et les bruitages
tt_anim
        lda animation
        eor #1
        sta animation
        beq tta_sans
        lda #<t_m_anim_oui
        ldx #>t_m_anim_oui
        jmp message
tta_sans
        lda #<t_m_anim_non
        ldx #>t_m_anim_non
        jmp message

; O fait tourner le camp tenu par la machine : Noirs, Blancs, personne.
tt_ordi
        lda camp_ordi
        cmp #NOIR
        bne tto_aucun
        lda #ORDI_AUCUN     ; depuis le reglage par defaut, on passe au
        jmp tto_poser       ; jeu a deux d'une seule touche
tto_aucun
        cmp #ORDI_AUCUN
        bne tto_noir
        lda #BLANC
        jmp tto_poser
tto_noir
        lda #NOIR
tto_poser
        sta camp_ordi
        jsr maj_panneau
        lda #<t_m_ordi
        ldx #>t_m_ordi
        jmp message

tt_aide
        lda #<t_m_aide
        ldx #>t_m_aide
        jmp message

tt_ouvrir
        lda #1
        sta mode_saisie
        lda #0
        sta nb_saisie
        jmp maj_etat

; --- mode saisie en notation -----------------------------------------
tt_saisie
        cmp #TOUCHE_RET
        beq ts_valider
        cmp #TOUCHE_DEL
        beq ts_effacer
        cmp #TOUCHE_SAISIE
        beq ts_fermer
        cmp #TOUCHE_0
        bcc ts_rien
        cmp #TOUCHE_9+1
        bcs ts_rien
        ; un chiffre : au plus deux dans le tampon
        ldx nb_saisie
        cpx #2
        bcc +
ts_rien
        rts
+       sec
        sbc #TOUCHE_0
        sta saisie,x
        inc nb_saisie
        jmp maj_etat

ts_fermer
        lda #0
        sta mode_saisie
        sta nb_saisie
        jmp maj_etat

; DEL efface un chiffre ; le tampon vide, on retourne a la navigation
ts_effacer
        lda nb_saisie
        beq ts_fermer
        dec nb_saisie
        jmp maj_etat

ts_valider
        lda nb_saisie
        bne +
        rts
+       jsr lire_nombre
        beq ts_invalide
        cmp #51
        bcs ts_invalide
        ; le curseur rejoint la case demandee, puis on valide comme au curseur
        jsr deplacer_curseur
        lda #0
        sta mode_saisie
        sta nb_saisie
        jsr maj_etat
        jmp valider
ts_invalide
        lda #<t_m_invalide
        ldx #>t_m_invalide
        jsr message
        lda #0
        sta nb_saisie
        jmp maj_etat

; ---------------------------------------------------------------------
;  lire_nombre : convertit les chiffres tapes en un nombre
;  Sortie  A = valeur, Z = 1 si le tampon est vide ou ne vaut que des zeros
; ---------------------------------------------------------------------
lire_nombre
        lda nb_saisie
        beq ln_fin
        cmp #1
        beq ln_un
        lda saisie          ; deux chiffres : dizaine x 10 + unite
        asl a
        asl a
        clc
        adc saisie
        asl a
        clc
        adc saisie+1
        rts
ln_un
        lda saisie
ln_fin
        rts

; ---------------------------------------------------------------------
;  message_selection : "PIECE nn SELECTIONNEE - DESTINATION ?"
; ---------------------------------------------------------------------
message_selection
        lda #<t_m_select
        ldx #>t_m_select
        jsr message
        lda #LIG_MSG
        sta tmp_ligne
        lda selection
        ldx #6              ; les deux chiffres du modele sont en colonne 6
        jmp afficher_nb2

; ---------------------------------------------------------------------
;  deselectionner : relache la piece choisie et efface son marquage
; ---------------------------------------------------------------------
deselectionner
        lda selection
        beq ds_fin
        pha
        lda #0
        sta selection
        pla
        jsr dessiner_case
        lda #<t_m_choisir
        ldx #>t_m_choisir
        jsr message
        jmp afficher_camp_msg
ds_fin
        rts

; ---------------------------------------------------------------------
;  message : affiche le texte (A = poids faible, X = poids fort) ligne 23
; ---------------------------------------------------------------------
message
        sta ptr_texte
        stx ptr_texte+1
        lda #0
        sta attr_texte
        lda #LIG_MSG
        jsr effacer_ligne
        lda #LIG_MSG
        ldx #0
        jsr pos_ecran
        jmp afficher_texte

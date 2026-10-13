; =====================================================================
;  donnees.asm - textes, tables de textes et variables du jeu
; =====================================================================

.enc "screen"

; ---------------------------------------------------------------------
;  Textes fixes (codes ecran, termines par 0)
;  Les caracteres accentues passent par les constantes C_* pour pouvoir
;  basculer entre ROM standard et EPROM francaise (voir constantes.asm).
; ---------------------------------------------------------------------
t_titre         .text "JEU DE DAMES INTERNATIONALES"
                .byte 0
t_machine       .text "COMMODORE 8296"
                .byte 0

t_trait         .text "TRAIT  :"
                .byte 0
t_ordi          .text "ORDI   :"
                .byte 0
t_niveau        .text "NIVEAU :"
                .byte 0
t_pieces        .text "PI"
                .byte ACC_E_AIGU
                .text "CES :"
                .byte 0

t_blancs        .text "BLANCS"
                .byte 0
t_noirs         .text "NOIRS"
                .byte 0
t_separ         .text "-"
                .byte 0
t_aucun         .text "AUCUN"
                .byte 0

t_derniers      .text "DERNIERS COUPS"
                .byte 0
t_legende       .text "L"
                .byte ACC_E_AIGU
                .text "GENDE"
                .byte 0

t_pion_b        .text "PION BLANC"
                .byte 0
t_dame_b        .text "DAME BLANCHE"
                .byte 0
t_pion_n        .text "PION NOIR"
                .byte 0
t_dame_n        .text "DAME NOIRE"
                .byte 0

t_votre         .text "VOTRE COUP : "
                .byte 0
t_case          .text "CASE "
                .byte 0
t_touches       .text "R=RETOUR *=COUP ?=AIDE Q=FIN"
                .byte 0

; ---------------------------------------------------------------------
;  Messages de la ligne 23
; ---------------------------------------------------------------------
; "CHOISISSEZ UNE PIECE - TRAIT AUX " fait 33 caracteres : le nom du camp
; est ajoute ensuite en colonne COL_CAMP_MSG par afficher_camp_msg.
t_m_choisir     .text "CHOISISSEZ UNE PI"
                .byte ACC_E_AIGU
                .text "CE - TRAIT AUX "
                .byte 0
; "PIECE 00 SELECTIONNEE - DESTINATION ?" : les deux chiffres en
; colonne 6 et 7 sont remplaces a l'affichage par le numero reel.
t_m_select      .text "PI"
                .byte ACC_E_AIGU
                .text "CE 00 S"
                .byte ACC_E_AIGU
                .text "LECTIONN"
                .byte ACC_E_AIGU
                .text "E - DESTINATION ?"
                .byte 0
t_m_vide        .text "CASE VIDE - CHOISISSEZ UNE DE VOS PI"
                .byte ACC_E_AIGU
                .text "CES"
                .byte 0
t_m_adverse     .text "CETTE PI"
                .byte ACC_E_AIGU
                .text "CE EST "
                .byte ACC_A_GRAVE
                .text " L"
                .byte $27           ; apostrophe
                .text "ADVERSAIRE"
                .byte 0
t_m_invalide    .text "NUM"
                .byte ACC_E_AIGU
                .text "RO DE CASE INVALIDE (1 "
                .byte ACC_A_GRAVE
                .text " 50)"
                .byte 0
; Tient en 80 colonnes : la ligne de message n'est pas extensible.
t_m_aide        .text "FL"
                .byte ACC_E_GRAVE
                .text "CHES/PAV"
                .byte ACC_E_AIGU
                .text " : D"
                .byte ACC_E_AIGU
                .text "PLACER  ESPACE : CHOISIR  * : NUM"
                .byte ACC_E_AIGU
                .text "RO  R : RETOUR  M : MENU"
                .byte 0
t_m_nouvelle    .text "NOUVELLE PARTIE - AUX BLANCS DE JOUER"
                .byte 0
t_m_illegal     .text "COUP IMPOSSIBLE - CHOISISSEZ UNE AUTRE CASE"
                .byte 0
t_m_prise_obli  .text "PRISE OBLIGATOIRE - CETTE PI"
                .byte ACC_E_AIGU
                .text "CE NE PEUT PAS JOUER"
                .byte 0
t_m_bloquee     .text "CETTE PI"
                .byte ACC_E_AIGU
                .text "CE EST BLOQU"
                .byte ACC_E_AIGU
                .text "E"
                .byte 0
t_m_pas_chemin  .text "CETTE PI"
                .byte ACC_E_AIGU
                .text "CE N"
                .byte $27
                .text "EST SUR AUCUN DES CHEMINS"
                .byte 0
t_m_ambigu      .text "RAFLE AMBIGU"
                .byte ACC_E_GRAVE
                .text " - D"
                .byte ACC_E_AIGU
                .text "SIGNEZ UNE PI"
                .byte ACC_E_GRAVE
                .text "CE "
                .byte ACC_A_GRAVE
                .text " PRENDRE"
                .byte 0
; "PARTIE TERMINEE - VAINQUEUR : " fait COL_GAGNANT caracteres, le camp
; gagnant etant ajoute juste apres.
t_m_ordi        .text "O : CAMP TENU PAR L"
                .byte $27
                .text "ORDINATEUR"
                .byte 0
t_m_anim_oui    .text "ANIMATION DES PRISES : AVEC"
                .byte 0
t_m_anim_non    .text "ANIMATION DES PRISES : SANS"
                .byte 0
t_m_rien_defaire .text "AUCUN COUP "
                .byte ACC_A_GRAVE
                .text " D"
                .byte ACC_E_AIGU
                .text "FAIRE"
                .byte 0
t_m_reflexion   .text "L"
                .byte $27
                .text "ORDINATEUR R"
                .byte ACC_E_AIGU
                .text "FL"
                .byte ACC_E_AIGU
                .text "CHIT..."
                .byte 0
t_m_fini        .text "PARTIE TERMIN"
                .byte ACC_E_AIGU
                .text "E - VAINQUEUR : "
                .byte 0

; ---------------------------------------------------------------------
;  Table des textes fixes du cadre et du panneau
;  Format : ligne, colonne, attribut, adresse (poids faible, poids fort)
;  Fin de table : $FF
; ---------------------------------------------------------------------
textes_fixes
        .byte LIG_TITRE,  2, INVERSE
        .word t_titre
        .byte LIG_TITRE, 64, INVERSE
        .word t_machine

        .byte  2, PAN_X, 0
        .word t_trait
        .byte  3, PAN_X, 0
        .word t_ordi
        .byte  4, PAN_X, 0
        .word t_niveau
        .byte  5, PAN_X, 0
        .word t_pieces
        .byte  5, PAN_X+12, 0
        .word t_separ

        .byte  7, PAN_X+5, INVERSE
        .word t_derniers
        .byte 13, PAN_X+9, INVERSE
        .word t_legende

        .byte 15, PAN_X+6, 0
        .word t_pion_b
        .byte 17, PAN_X+6, 0
        .word t_dame_b
        .byte 19, PAN_X+6, 0
        .word t_pion_n
        .byte 21, PAN_X+6, 0
        .word t_dame_n

        .byte LIG_SAISIE, COL_TOUCHES, 0
        .word t_touches
        .byte $FF

; ---------------------------------------------------------------------
;  Empreintes des ROM d'editeur standard connues (somme 16 bits de
;  $E000-$E7FF). Les versions 50 Hz et 60 Hz donnent la meme ; VICE
;  charge une variante qui en donne une autre.
; ---------------------------------------------------------------------
empreintes_lo
        .byte <$528A, <$52AE
empreintes_hi
        .byte >$528A, >$52AE
NB_EMPREINTES = * - empreintes_hi

; ---------------------------------------------------------------------
;  Textes de l'ecran de choix du jeu de caracteres
;  Ils n'emploient que des lettres sans accent (codes 1 a 26), communes
;  aux deux ROM : il faut pouvoir les lire avant d'avoir choisi.
; ---------------------------------------------------------------------
t_rom_standard  .text "1 - ROM STANDARD"
                .byte 0
t_rom_francaise .text "2 - ROM FRANCAISE (EDEX)"
                .byte 0
t_rom_question  .text "QUEL JEU DE CARACTERES A VOTRE MACHINE ?"
                .byte 0
t_rom_indice    .text "RETENEZ CELUI OU LES PIONS SONT DES ANNEAUX BIEN FERMES"
                .byte 0
t_rom_indice2   .text "ET OU LE CADRE EST FAIT DE TRAITS CONTINUS"
                .byte 0
t_rom_touches   .text "1 OU 2 POUR CHOISIR      RETURN POUR VALIDER"
                .byte 0

rom_textes
        .byte LIG_TITRE, 26, INVERSE
        .word t_menu_titre
        .byte 4, 20, 0
        .word t_rom_question
        .byte 18, 12, 0
        .word t_rom_indice
        .byte 19, 12, 0
        .word t_rom_indice2
        .byte 21, 18, 0
        .word t_rom_touches
        .byte $FF

; ---------------------------------------------------------------------
;  Prereglages des formes du damier, dans l'ordre des variables car_*
;  puis des cinq accents.
;
;  ROM standard : celle de VICE, et des 8296 non francises.
;  ROM francaise (EPROM AZ-E-01 du proprietaire) : codes releves sur la
;  machine. Elle n'a pas de losange : la dame y porte un petit carre. Elle
;  n'a pas non plus de c cedille, qui retombe sur un C ordinaire.
; ---------------------------------------------------------------------
rom_standard
        .byte $55, $49, $4A, $4B        ; arcs HG HD BG BD
        .byte $40, $5D, $5A             ; trait horizontal, vertical, dame
        .byte $70, $6E, $6D, $7D        ; coins du cadre
        .byte 5, 5, 1, 21, 3            ; accents : lettres sans accent

rom_francaise
        .byte 82, 84, 70, 71            ; arcs HG HD BG BD
        .byte 102, 97, 83               ; trait horizontal, vertical, dame
        .byte 104, 106, 98, 100         ; coins du cadre
        .byte 127, 114, 113, 117, 3     ; e aigu, e grave, a grave, u grave,
                                        ; et C faute de cedille

; ---------------------------------------------------------------------
;  Textes de l'ecran de reglages
; ---------------------------------------------------------------------
t_menu_niveau   .text "NIVEAU"
                .byte 0
t_menu_camp     .text "VOUS JOUEZ"
                .byte 0
t_menu_blancs   .text "LES BLANCS (VOUS COMMENCEZ)"
                .byte 0
t_menu_noirs    .text "LES NOIRS (L"
                .byte $27
                .text "ORDINATEUR COMMENCE)"
                .byte 0
t_menu_deux     .text "LES DEUX (PARTIE "
                .byte ACC_A_GRAVE
                .text " DEUX JOUEURS)"
                .byte 0
t_menu_rom      .text "JEU DE CARACTERES"
                .byte 0
t_rom_nom_std   .text "ROM STANDARD"
                .byte 0
t_rom_nom_fr    .text "ROM FRANCAISE (EDEX)"
                .byte 0
rom_nom_lo
        .byte <t_rom_nom_std, <t_rom_nom_fr
rom_nom_hi
        .byte >t_rom_nom_std, >t_rom_nom_fr

t_menu_titre    .text "JEU DE DAMES INTERNATIONALES"
                .byte 0
t_menu_note     .text "AUX DAMES, LES BLANCS JOUENT TOUJOURS LE PREMIER COUP"
                .byte 0
t_menu_go       .text "ESPACE : COMMENCER LA PARTIE"
                .byte 0
t_menu_aide0    .text "C : REVOIR LES DEUX JEUX DE CARACTERES"
                .byte 0
t_menu_aide1    .text "8 ET 2 (OU LES FL"
                .byte ACC_E_GRAVE
                .text "CHES) : CHOISIR LA LIGNE"
                .byte 0
t_menu_aide2    .text "4 ET 6 : MODIFIER LE R"
                .byte ACC_E_AIGU
                .text "GLAGE      Q : QUITTER"
                .byte 0
t_menu_part     .text "EN PARTIE : R = RETOUR ARRI"
                .byte ACC_E_GRAVE
                .text "RE   M = CE MENU   N = NOUVELLE"
                .byte 0

menu_textes
        .byte LIG_TITRE, 26, INVERSE
        .word t_menu_titre
        .byte 4, 14, 0
        .word t_menu_note
        .byte 14, 26, 0
        .word t_menu_go
        .byte 18, 14, 0
        .word t_menu_aide0
        .byte 16, 14, 0
        .word t_menu_aide1
        .byte 17, 14, 0
        .word t_menu_aide2
        .byte 20, 12, 0
        .word t_menu_part
        .byte $FF

menu_camp_lo
        .byte <t_menu_blancs, <t_menu_noirs, <t_menu_deux
menu_camp_hi
        .byte >t_menu_blancs, >t_menu_noirs, >t_menu_deux

; ---------------------------------------------------------------------
;  Niveaux de jeu : duree de reflexion, en images (50 par seconde), et
;  profondeur a ne pas depasser.
; ---------------------------------------------------------------------
niveau_limite_lo
        .byte <100, <250, <600
niveau_limite_hi
        .byte >100, >250, >600
niveau_prof
        .byte 4, 6, 8

; ---------------------------------------------------------------------
;  Touches de deplacement du curseur et direction correspondante.
;  Les fleches et le pave numerique sont traites de la meme facon ; il
;  suffit d'ajouter une ligne ici pour reconnaitre un code de plus.
; ---------------------------------------------------------------------
nav_touches
        .byte T_GAUCHE, T_DROITE, T_HAUT, T_BAS
        .byte T_PAV_GAUCHE, T_PAV_DROITE, T_PAV_HAUT, T_PAV_BAS
        .byte T_PAV_HG, T_PAV_HD, T_PAV_BG, T_PAV_BD
NAV_NOMBRE = * - nav_touches

nav_directions
        .byte DIR_GAUCHE, DIR_DROITE, DIR_HAUT, DIR_BAS
        .byte DIR_GAUCHE, DIR_DROITE, DIR_HAUT, DIR_BAS
        .byte DIR_D_HG, DIR_D_HD, DIR_D_BG, DIR_D_BD

; Decalages des quatre diagonales dans le plateau, dans l'ordre
; DIR_D_HG, DIR_D_HD, DIR_D_BG, DIR_D_BD.
dir_decalage
        .byte DIR_HG, DIR_HD, DIR_BG, DIR_BD

; ---------------------------------------------------------------------
;  Legende : les quatre exemples de pieces (ligne, piece)
; ---------------------------------------------------------------------
legende_pieces
        .byte 15, PION_B
        .byte 17, DAME_B
        .byte 19, PION_N
        .byte 21, DAME_N
        .byte $FF

.enc "none"

; =====================================================================
;  Variables en RAM
; =====================================================================
variables

; --- variables de travail de l'affichage -----------------------------
tmp_ligne       .byte 0
tmp_colonne     .byte 0
tmp_rangee      .byte 0
tmp_car         .byte 0
tmp_num         .byte 0
tmp_index       .byte 0
attr_texte      .byte 0
attr_piece      .byte 0
car_milieu      .byte 0
; Formes du damier, remplies au lancement selon la ROM choisie.
car_arc_hg      .byte 0
car_arc_hd      .byte 0
car_arc_bg      .byte 0
car_arc_bd      .byte 0
car_trait_h     .byte 0
car_trait_v     .byte 0
car_dame        .byte 0
car_coin_hg     .byte 0
car_coin_hd     .byte 0
car_coin_bg     .byte 0
car_coin_bd     .byte 0
accents         .fill NB_ACCENTS, 0
rom_choisie     .byte 1         ; 0 = standard, 1 = francaise (EDEX)
som_lo          .byte 0         ; somme de controle de la ROM editeur
som_hi          .byte 0
car_type        .byte 0         ; type de piece en cours de dessin
attr_case       .byte 0         ; $80 quand la case entiere est inversee
                                ; (c'est ainsi que se signale le curseur)
num_courant     .byte 0
v_dizaine       .byte 0
v_unite         .byte 0

; --- etat de la partie -----------------------------------------------
trait           .byte BLANC     ; camp au trait : BLANC ou NOIR
selection       .byte 0         ; piece choisie (0 = aucune)
curseur         .byte 32        ; case sous le curseur
partie_finie    .byte 0         ; 1 quand le camp au trait n'a plus de coup
mode_saisie     .byte 0         ; 0 = navigation, 1 = saisie en notation
nb_blancs       .byte 20
nb_noirs        .byte 20
niveau          .byte 1
montrer_numeros .byte 1         ; 1 = afficher les numeros des cases vides

; --- saisie clavier ---------------------------------------------------
saisie          .fill 2, 0      ; chiffres tapes
nb_saisie       .byte 0
num_tape        .byte 0         ; nombre forme par les chiffres tapes
col_curseur     .byte 0         ; colonne du curseur sur la ligne de saisie
demande_fin     .byte 0         ; passe a 1 quand on quitte le jeu
retour_menu     .byte 0         ; passe a 1 pour revenir a l'ecran de menu
clign_phase     .byte 0         ; phase de clignotement affichee
clign_actif     .byte 0         ; 1 si une piece clignote

; --- historique des coups (4 entrees de 6 caracteres) ----------------
HIST_LG         = 6
HIST_NB         = 4
historique      .fill HIST_LG*HIST_NB, CAR_ESPACE

; --- generateur de coups ---------------------------------------------
trait_gen       .byte 0         ; camp pour lequel on genere
num_gen         .byte 0         ; case en cours d'examen (1..50)
piece_courante  .byte 0         ; piece qui rafle
depart_courant  .byte 0         ; sa case de depart (index plateau)
prof            .byte 0         ; nombre de prises de la rafle courante
meilleure_prise      .byte 0         ; meilleure longueur trouvee
nb_coups        .byte 0         ; coups dans la liste
debordement     .byte 0         ; coups abandonnes faute de place
cmp_resultat    .byte 0         ; nombre de coups trouves
premier_coup    .byte 0         ; index du premier d'entre eux
coup_depart     .byte 0         ; coup en cours d'application
coup_arrivee    .byte 0
coup_nb_prises  .byte 0
coup_piece      .byte 0
arrivee_voulue  .byte 0         ; case d'arrivee demandee par le joueur
attente_rafle   .byte 0         ; 1 si une rafle ambigue reste a departager
nb_filtres      .byte 0         ; cases que le coup doit prendre
filtres         .fill MAX_FILTRES, 0
cmp_total       .byte 0
prises_cases    .fill MAX_PRISES, 0
prises_pieces   .fill MAX_PRISES, 0     ; leur nature, pour les rendre
coup_origine    .byte 0                 ; piece avant promotion
hist_perdue     .fill HIST_LG, 0        ; entree chassee de l'historique
nb_demi_coups   .byte 0                 ; coups empiles, pour le retour
du_long         .byte 0                 ; longueur de l'entree depilee
son_duree       .byte 0                 ; duree du son en cours
att_fin         .byte 0                 ; image a atteindre pour attendre
anim_nb         .byte 0                 ; prises a montrer
anim_index      .byte 0
anim_case       .byte 0                 ; case en cours de marquage
animation       .byte 1                 ; 1 = prises animees et bruitees
loc_suivante    .byte 0         ; case d'arrivee en cours de traitement
cmp_num         .byte 0         ; variables de comparaison des coups
cmp_i           .byte 0
cmp_j           .byte 0
cmp_valeur      .byte 0
cs_dir          .byte 0         ; variables des deplacements simples
cs_delta        .byte 0
cs_case         .byte 0

; Etat propre a chaque niveau de la recherche de rafles : la recursion
; passe par ces tables, la pile du 6502 ne portant que les retours.
pile_prises     .fill MAX_PRISES+1, 0
loc_courant     .fill MAX_PRISES+1, 0
loc_dir         .fill MAX_PRISES+1, 0
loc_delta       .fill MAX_PRISES+1, 0
loc_prise       .fill MAX_PRISES+1, 0
loc_arrivee     .fill MAX_PRISES+1, 0
loc_suites      .fill MAX_PRISES+1, 0

; --- recherche -------------------------------------------------------
score_lo        .byte 0         ; score courant, 16 bits signes
score_hi        .byte 0
num_eval        .byte 0         ; case en cours d'evaluation
prof_rech       .byte 0         ; niveau courant de la recherche
prof_reste      .byte 0         ; demi-coups restant a explorer
meilleur_lo     .byte 0         ; coup retenu a la racine
meilleur_hi     .byte 0
cmp_a_lo        .byte 0         ; operandes de comparer_scores
cmp_a_hi        .byte 0
cmp_b_lo        .byte 0
cmp_b_hi        .byte 0
jr_depart       .byte 0         ; coup en cours d'application
jr_arrivee      .byte 0
jr_nb           .byte 0
jr_piece        .byte 0
jr_origine      .byte 0         ; nature de la piece avant promotion
pz_tmp3         .byte 0
sauve_y         .byte 0         ; Y mis de cote par empiler / depiler
debut_tps_lo    .byte 0         ; horloge au depart de la reflexion
debut_tps_hi    .byte 0
limite_lo       .byte 0         ; duree accordee, en images
limite_hi       .byte 0
temps_ecoule    .byte 0         ; 1 quand le delai est depasse
prof_iter       .byte 0         ; profondeur de l'iteration en cours
prof_max        .byte 0         ; profondeur a ne pas depasser
prof_atteinte   .byte 0         ; derniere profondeur menee a terme
coup_ia_depart  .byte 0         ; coup choisi par la machine
coup_ia_arrivee .byte 0
rang_prefere_actif .byte 0      ; 1 si un coup doit etre essaye en premier
camp_ordi       .byte NOIR      ; camp tenu par la machine
menu_ligne      .byte 0         ; reglage pointe dans l'ecran de menu
menu_camp       .byte 0         ; 0 = joueur blanc, 1 = joueur noir, 2 = a deux
cle_lo          .byte 0         ; hachage Zobrist de la position
cle_hi          .byte 0
ck_num          .byte 0         ; case en cours de hachage
xp_type         .byte 0         ; piece a combiner a la clef
xp_case         .byte 0
rt_nature       .byte 0         ; nature de la valeur rangee
coup_ia         .fill 24, 0     ; coup retenu, recopie hors de la zone

; Etat propre a chaque niveau de la recherche.
rech_alpha_lo   .fill MAX_PROF+2, 0
rech_alpha_hi   .fill MAX_PROF+2, 0
rech_beta_lo    .fill MAX_PROF+2, 0
rech_beta_hi    .fill MAX_PROF+2, 0
rech_ptr_lo     .fill MAX_PROF+2, 0
rech_ptr_hi     .fill MAX_PROF+2, 0
rech_reste      .fill MAX_PROF+2, 0
rech_alpha0_lo  .fill MAX_PROF+2, 0
rech_alpha0_hi  .fill MAX_PROF+2, 0
rech_rang       .fill MAX_PROF+2, 0
rech_courant_lo .fill MAX_PROF+2, 0
rech_courant_hi .fill MAX_PROF+2, 0
rech_debut_lo   .fill MAX_PROF+2, 0
rech_debut_hi   .fill MAX_PROF+2, 0
annul_debut_lo  .fill MAX_PROF+2, 0
annul_debut_hi  .fill MAX_PROF+2, 0

; --- plateau interne 12x12 avec bordure d'une case -------------------
plateau         .fill 144, BORD

; --- sauvegarde de la page zero empruntee ----------------------------
sauvegarde_pz   .fill PZ_NOMBRE, 0

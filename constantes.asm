; =====================================================================
;  constantes.asm - adresses materielles, codes ecran, geometrie
;  Jeu de dames internationales pour Commodore 8296
; =====================================================================

; ---------------------------------------------------------------------
;  Materiel Commodore 8296
; ---------------------------------------------------------------------
ECRAN       = $8000         ; memoire ecran, 80 colonnes x 25 lignes
TAILLE_ECR  = 80*25         ; 2000 octets
LARGEUR     = 80
HAUTEUR     = 25

REG_CARACT  = $E84C         ; VIA PCR : pilote le jeu de caracteres
                            ; (equivalent assembleur de POKE 59468,n)
MODE_GRAPH  = 12            ; majuscules + graphiques (mode du jeu)
MODE_MINUS  = 14            ; minuscules / majuscules

GETIN       = $FFE4         ; KERNAL : lit un caractere clavier (0 = rien)
CHROUT      = $FFD2         ; KERNAL : ecrit un caractere via l'editeur
PET_EFFACER = $93           ; code PETSCII d'effacement de l'ecran
JIFFY_LO    = $008F         ; horloge systeme TI, octet de poids faible
TI_MOYEN    = $008E         ; octet median (TI occupe $8D..$8F)
TI_BAS      = $008F
                            ; (TI occupe $8D..$8F, poids fort en premier)

; ---------------------------------------------------------------------
;  Page zero utilisee par le jeu
;  Le programme ne rend pas la main au BASIC pendant la partie, mais l'IRQ
;  du KERNAL (horloge, clavier, curseur) continue de tourner.
;
;  Zone retenue : $B0..$BF, la zone de travail de la cassette. Mesure faite
;  dans VICE (outils de sondage, voir le journal de l'etape 1) : en laissant
;  tourner les interruptions plusieurs secondes, $B0..$CA restent intacts,
;  tandis que $F8, $F9 et $FA sont modifies par le systeme - c'est la table
;  des lignes ecran de l'editeur, qui s'etend jusqu'a $F8.
;  La zone est tout de meme sauvegardee au demarrage et restauree a la sortie.
;
;  TODO machine reelle : l'EPROM EDEX 8000 est un editeur modifie ; demander
;  au proprietaire de verifier qu'apres une partie, LOAD et SAVE cassette
;  fonctionnent toujours normalement.
; ---------------------------------------------------------------------
PZ_BASE     = $B0
PZ_NOMBRE   = 20            ; $B0..$C3

ptr_ecran   = $B0           ; $B0/$B1 pointeur de travail vers l'ecran
ptr_texte   = $B2           ; $B2/$B3 pointeur vers une chaine
ptr_aux     = $B4           ; $B4/$B5 pointeur auxiliaire
pz_tmp      = $B6           ; octet temporaire
coups_fin   = $B7           ; $B7/$B8 ou ranger le prochain coup genere
ptr_coup    = $B9           ; $B9/$BA coup en cours d'examen
coups_debut = $BB           ; $BB/$BC debut de la tranche du niveau courant
annul_ptr   = $BD           ; $BD/$BE sommet de la pile d'annulation
pz_tmp2     = $BF           ; second octet temporaire
ptr_table   = $C0           ; $C0/$C1 entree de la table de transpositions
ptr_part    = $C2           ; $C2/$C3 sommet de la pile d'annulation de partie

; ---------------------------------------------------------------------
;  Codes ecran PETSCII, mode majuscules + graphiques
;  Verifies en rendant characters-2.901447-10.bin (voir outils/glyphes.py)
;  Ajouter INVERSE ($80) pour la video inverse.
; ---------------------------------------------------------------------
INVERSE     = $80

CAR_ESPACE  = $20           ; espace
CAR_ESP_INV = $A0           ; espace inverse (bloc plein)

; Les formes du damier n'ont pas le meme code d'une ROM a l'autre : elles
; sont donc lues dans des variables (car_*), remplies au demarrage par
; appliquer_rom depuis l'un des deux prereglages de donnees.asm.
; Les codes de la ROM francaise ont ete releves sur la machine du
; proprietaire ; ceux de la ROM standard sont ceux de VICE.
NB_CAR_ROM  = 11            ; formes commutables
NB_ACCENTS  = 5             ; e aigu, e grave, a grave, u grave, c cedille

; Marqueurs d'accent dans les textes. Ils occupent des codes que le jeu
; n'emploie pas ailleurs ($1B a $1F) ; afficher_texte les remplace par le
; caractere de la ROM active, ou par la lettre sans accent.
ACC_E_AIGU  = $1B
ACC_E_GRAVE = $1C
ACC_A_GRAVE = $1D
ACC_U_GRAVE = $1E
ACC_C_CEDIL = $1F

CAR_ZERO    = $30           ; code ecran du chiffre 0
CAR_TIRET   = $2D           ; trait d'union, pour la notation 32-28
CAR_PRISE   = $18           ; X, separateur des prises : 28x19

; ---------------------------------------------------------------------
;  Caracteres accentues
;  La machine reelle porte une EPROM francaise (AZ-E-01 GEN.) dont les
;  codes 112 a 127 sont des minuscules accentuees. Le choix de la ROM se
;  fait au lancement, pas a l'assemblage : voir ecran_rom.asm.
; ---------------------------------------------------------------------

; ---------------------------------------------------------------------
;  ;  Geometrie de l'ecran (disposition validee sur maquette)
;  Une case fait 5 colonnes x 2 lignes : sur le moniteur du 8296 les
;  caracteres sont environ 2,4 fois plus hauts que larges, ce qui donne
;  une case a peu pres carree.
; ---------------------------------------------------------------------
DAM_X       = 2             ; colonne de la case (r,c) = DAM_X + 5*c
DAM_Y       = 2             ; ligne   de la case (r,c) = DAM_Y + 2*r
CASE_L      = 5             ; largeur d'une case en caracteres
CASE_H      = 2             ; hauteur d'une case en caracteres

CADRE_X1    = 1             ; colonne du montant gauche du cadre
CADRE_X2    = 52            ; colonne du montant droit
CADRE_Y1    = 1             ; ligne du bord superieur
CADRE_Y2    = 22            ; ligne du bord inferieur

PAN_X       = 55            ; premiere colonne du panneau d'informations
PAN_L       = 25            ; largeur du panneau (colonnes 55..79)

LIG_TITRE   = 0
LIG_MSG     = 23            ; ligne des messages
LIG_SAISIE  = 24            ; ligne de saisie du coup
COL_CAMP_MSG = 33           ; colonne ou afficher_camp_msg ecrit le camp,
                            ; juste apres le texte t_m_choisir
COL_GAGNANT = 30            ; colonne ou s'ecrit le camp vainqueur
COL_TOUCHES = 51            ; rappel des touches, a droite de la ligne 24
LG_ETAT     = 50            ; largeur de la zone d'etat / de saisie (0..49)

; Decalage de la piece a l'interieur de sa case : colonnes 1 a 3 sur 5.
PIECE_DX    = 1

; Case ou se place le curseur au debut d'une partie, faute d'un coup
; precedent du joueur.
CASE_DEPART = 32

; ---------------------------------------------------------------------
;  Contenu d'une case du plateau interne
; ---------------------------------------------------------------------
VIDE        = 0
PION_B      = 1
DAME_B      = 2
PION_N      = 3
DAME_N      = 4
BORD        = $FF           ; case fantome de la bordure

BLANC       = 0             ; valeurs de la variable "trait"
NOIR        = 1
ORDI_AUCUN  = $FF           ; camp_ordi : personne, les deux camps sont
                            ; tenus par des joueurs

; Decalages diagonaux dans le plateau 12x12 (bordure d'une case).
; Ecrits en complement a deux car l'assembleur travaille sur 8 bits.
DIR_HG      = $F3           ; -13
DIR_HD      = $F5           ; -11
DIR_BG      = 11
DIR_BD      = 13

; ---------------------------------------------------------------------
;  Zones de travail du generateur de coups
;  Placees au-dela du programme, a adresse fixe : elles ne sont pas dans
;  le .prg (ce serait plus d'un kilo-octet de remplissage) et sont mises
;  a zero au demarrage.
; ---------------------------------------------------------------------
MAX_PRISES  = 20            ; profondeur maximale d'une rafle
; --- recherche ------------------------------------------------------
MAX_PROF    = 10            ; profondeur maximale de la recherche
VAL_PION    = 100           ; une dame vaut environ trois pions
VAL_DAME    = 300
SCORE_MAT   = 30000         ; valeur d'une partie perdue
SCORE_INF   = 32000         ; borne de la fenetre alpha-beta

annul_zone     = $3D00      ; 512 octets : pile d'annulation des coups
ordre_lo       = $3F00      ; MAX_COUPS octets : ordre d'examen a la racine
ordre_hi       = $3FC0

; Table de transpositions : 1024 entrees de 8 octets, en RAM ordinaire.
; Le 8296 offre aussi 64 Ko commutables sur $8000-$FFFF via le registre
; $FFF0, mais ce registre est en ecriture seule et conditionne la
; visibilite de l'ecran et des E/S : tant qu'il n'est pas documente avec
; certitude, la RAM d'en dessous suffit largement (le programme et ses
; zones de travail s'arretent avant $4080).
; Pile d'annulation de la partie : de quoi defaire les coups joues, pour
; le retour arriere. Environ 150 demi-coups ; au-dela on cesse d'empiler
; et le retour arriere ne remonte pas plus loin.
annul_partie      = $6100
FIN_ANNUL_PARTIE  = $68FF

table_trans       = $4100
TAILLE_TABLE_PAGES = 32     ; 32 pages de 256 octets = 8 Ko

; Mettre a 0 pour se passer de la table de transpositions : la recherche
; donne alors exactement les memes resultats, seul le temps change.
UTILISER_TABLE = 1

; Nature de la valeur rangee dans la table
VAL_EXACTE  = 1             ; le score est la vraie valeur du noeud
VAL_MINOREE = 2             ; le vrai score est au moins celui-la
VAL_MAJOREE = 3             ; le vrai score est au plus celui-la

MAX_FILTRES = 4             ; cases imposees pour departager une rafle
MAX_COUPS   = 192           ; coups maximum dans une position. Une poignee
                            ; de dames sur un plateau degarni produit vite
                            ; plus d'une centaine de deplacements.
TAILLE_ZONE = 1536          ; octets pour la description des coups

; Carte des zones de travail. Elles sont a adresse fixe, au-dela du
; programme : main.asm verifie a l'assemblage que celui-ci ne les
; rattrape pas (une collision silencieuse abime le plateau en pleine
; recherche, et c'est fort desagreable a diagnostiquer).
DEBUT_ZONES    = $3400
marques        = $3400      ; 144 octets : pieces deja prises dans la rafle
coups_index_lo = $3500      ; MAX_COUPS octets
coups_index_hi = $35C0      ; MAX_COUPS octets
coups_zone     = $3700      ; TAILLE_ZONE octets

; ---------------------------------------------------------------------
;  Codes PETSCII renvoyes par GETIN
;
;  Touches de deplacement du curseur. Les codes des fleches sont les codes
;  de controle CBM habituels ; le keymap de VICE confirme la disposition du
;  clavier "business" du 8296 : gauche et droite sont la meme touche selon
;  SHIFT, de meme que haut et bas.
;
;  Le pave numerique occupe des positions distinctes dans la matrice, mais
;  l'editeur le decode tres probablement vers les memes codes que les
;  chiffres de la rangee du haut : impossible a confirmer sous VICE, dont
;  l'injection de touches court-circuite la matrice. C'est pourquoi les
;  chiffres deplacent le curseur et que la saisie en notation s'ouvre par
;  une touche a part (TOUCHE_SAISIE).
;
;  TODO machine reelle : lancer le jeu, appuyer sur les touches du pave et
;  verifier que le curseur se deplace bien. Si l'EPROM francaise leur donne
;  des codes propres, il suffira de les ajouter a la table nav_touches de
;  donnees.asm pour que chiffres et pave redeviennent independants.
; ---------------------------------------------------------------------
TOUCHE_RET  = $0D           ; RETURN : valide
TOUCHE_ESP  = $20           ; ESPACE : valide aussi
TOUCHE_DEL  = $14           ; DEL : efface un chiffre en saisie
TOUCHE_SAISIE = $2A         ; * : ouvre la saisie en notation
TOUCHE_0    = $30
TOUCHE_9    = $39
TOUCHE_Q    = $51           ; Q = quitter
TOUCHE_N    = $4E           ; N = nouvelle partie
TOUCHE_AIDE = $3F           ; ? = aide
TOUCHE_ORDI = $4F           ; O = camp tenu par l'ordinateur
TOUCHE_RETOUR = $52         ; R = revenir en arriere
TOUCHE_MENU = $4D           ; M = retour au menu
TOUCHE_CALIB = $43          ; C = revoir les deux jeux de caracteres
TOUCHE_ANIM = $41           ; A = animation des prises, avec ou sans

; Fleches du curseur (codes de controle CBM)
T_DROITE    = $1D
T_GAUCHE    = $9D
T_BAS       = $11
T_HAUT      = $91

; Pave numerique, disposition en croix autour du 5
T_PAV_HG    = $37           ; 7
T_PAV_HD    = $39           ; 9
T_PAV_BG    = $31           ; 1
T_PAV_BD    = $33           ; 3
T_PAV_HAUT  = $38           ; 8
T_PAV_BAS   = $32           ; 2
T_PAV_GAUCHE = $34          ; 4
T_PAV_DROITE = $36          ; 6

; Directions, dans l'ordre utilise par case_voisine
DIR_GAUCHE  = 0
DIR_DROITE  = 1
DIR_HAUT    = 2
DIR_BAS     = 3
DIR_D_HG    = 4             ; diagonales
DIR_D_HD    = 5
DIR_D_BG    = 6
DIR_D_BD    = 7

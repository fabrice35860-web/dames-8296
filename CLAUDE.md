# Jeu de dames pour Commodore 8296 — CLAUDE.md

## Langue

Toujours répondre en **français** (explications, commentaires dans le code, messages de commit).

## Objectif

Un jeu de **dames internationales (10×10)** entièrement écrit en **assembleur 6502** pour un
**Commodore 8296**, avec :

- un affichage soigné en caractères PETSCII sur l'écran 80×25 ;
- un adversaire IA de bon niveau (alpha-bêta optimisé) ;
- aucune modification matérielle : le programme doit tourner sur la machine telle quelle.

## Machine cible

- **Commodore 8296** : CPU 6502 à 1 MHz, BASIC 4.0, écran 80×25 monochrome (moniteur intégré).
- **Mémoire écran** : `$8000`–`$87CF` (80 octets par ligne, adresse = `$8000 + ligne*80 + colonne`).
- **CRTC** : MOS 6545‑1.
- **Mode caractères** : `POKE 59468,12` = majuscules + graphiques (mode à utiliser pour le jeu),
  `POKE 59468,14` = minuscules/majuscules. En assembleur : écrire `#12` dans `$E84C`.
- **RAM utilisateur** : `$0400`–`$7FFF`.
- **RAM étendue** : 64 Ko supplémentaires commutables par banques sur `$8000`–`$FFFF` via le
  registre de contrôle en `$FFF0`. **À documenter précisément avant usage** (registre en écriture
  seule, l'écran et les E/S doivent rester visibles). Usage prévu : table de transpositions,
  bibliothèque d'ouvertures (étape 3).
- **Kernal** : lecture clavier via `GETIN` (`JSR $FFE4`).
- **Page zéro** (fixée à l'étape 1) : le jeu utilise **`$B0`–`$BF`**, sauvegardée au démarrage et
  restaurée à la sortie (`sauver_pz` / `rendre_pz` dans `main.asm`).
  - `$B0/$B1` `ptr_ecran`, `$B2/$B3` `ptr_texte`, `$B4/$B5` `ptr_aux`, `$B6` `pz_tmp` ;
    `$B7`–`$BF` sont réservés pour la recherche (étape 3).
  - Choix établi par **mesure dans VICE**, pas d'après une carte mémoire : en marquant une plage
    puis en laissant tourner les interruptions plusieurs secondes, `$B0`–`$CA` restent intacts,
    tandis que **`$F8`, `$F9`, `$FA` sont modifiés par le système** (la table des lignes écran de
    l'éditeur s'étend jusqu'à `$F8`). Une première version utilisait `$F9`–`$FF` : l'IRQ écrasait
    `ptr_ecran` en pleine écriture et une case du damier sur cinquante sortait vide.
  - `$B0`–`$BF` est la zone de travail de la cassette : sans danger tant qu'on ne charge rien,
    et de toute façon restaurée en sortant.

### Particularité de cette machine : ROMs françaises

- Le générateur de caractères est une EPROM française (« AZ‑E‑Ø1 GEN. ») : elle contient **les
  graphiques PETSCII ET des caractères accentués** (é, è, à, ç, ù…), clavier **AZERTY accentué**.
- L'éditeur est une EPROM modifiée (« EDEX 8000 »).
- **Ne jamais supposer qu'on peut changer les ROMs** : le propriétaire ne veut pas manipuler les
  puces. Tout doit fonctionner avec ce jeu de caractères.
- **TODO** : établir la table des codes écran des caractères accentués. Méthode : programme de
  test qui affiche les 256 codes écran (`POKE 32768+I,I`), photo de l'écran réel, puis reporter
  ici la correspondance. Dans VICE (ROM standard), les accents n'apparaîtront pas : prévoir une
  table de remplacement (constantes à un seul endroit) pour basculer facilement entre
  « ROM standard » (émulateur) et « ROM française » (machine réelle).

## Disposition de l'écran (validée sur maquette)

Les caractères du moniteur 80 colonnes sont environ 2,4 fois plus hauts que larges : une case de
**5×2 caractères** paraît à peu près carrée.

```
Ligne 0      : bandeau titre en vidéo inverse
               "JEU DE DAMES INTERNATIONALES"  ...  "COMMODORE 8296"
Lignes 1–22  : cadre (colonnes 1 et 52) + damier en lignes 2–21, colonnes 2–51
               case (ligne r, colonne c) -> x = 2 + c*5, y = 2 + r*2
Colonnes 55–79 : panneau d'informations
               lignes 2–5   : TRAIT / ORDI / NIVEAU / PIÈCES
               ligne 7      : en-tête inverse "DERNIERS COUPS", historique lignes 8–11
               ligne 13     : en-tête inverse "LÉGENDE", exemples de pièces lignes 15–22
                              (4 pièces de 2 lignes : il en faut 8, pas 7 ; la ligne 22 du
                               panneau est libre, le cadre du damier s'arrêtant colonne 52)
Ligne 23     : message (ex. "PIÈCE 32 SÉLECTIONNÉE - DESTINATION ?")
Ligne 24     : ligne d'état, colonnes 0–49, selon le mode :
               navigation -> "CASE 32" (case sous le curseur)
               saisie     -> "VOTRE COUP : 32-" + curseur clignotant
               à droite, colonne 51 : "R=RETOUR *=COUP ?=AIDE Q=FIN"
```

- **Cases claires** : espaces normaux. **Cases foncées** (jouables) : espaces en vidéo inverse.
- Numérotation officielle 1–50 : case n -> rangée `r = (n-1) div 5`,
  colonne `c = 2*((n-1) mod 5) + (1 si r pair, 0 si r impair)`. Noirs en haut (1–20), Blancs en
  bas (31–50).
- **Numéros des cases vides** affichés en vidéo inverse (option activable), pour aider la saisie.

### Dessin des pièces (3×2 caractères, colonnes 1 à 3 de la case)

```
pion :  ╭ ─ ╮        dame :  ╭ ♦ ╮
        ╰ ─ ╯                ╰ ─ ╯
```

- **Pion/dame blanc** : caractères en **vidéo inverse** (anneau sombre sur case claire).
- **Pion/dame noir** : caractères en **vidéo normale** (bloc sombre avec anneau lumineux).
- **Curseur** : le **fond** de la case clignote en inversion vidéo (~3 Hz, bit 4 des jiffies).
  La case foncée passe alors au noir et semble disparaître, ce qui se voit très bien.
  **La pièce, elle, est exclue de cette inversion** : c'est la vidéo inverse qui distingue un
  Blanc d'un Noir, si bien qu'inverser la case entière échangeait les deux couleurs — un pion
  blanc sous le curseur s'affichait exactement comme un pion noir (`55 40 49` au lieu de
  `D5 C0 C9`). Le défaut sautait aux yeux après un coup, puisque le curseur reste sur la pièce
  qu'on vient de déplacer. `dessiner_piece` ne combine donc pas `attr_case`, contrairement au
  fond, aux crochets de sélection et au numéro de case.
- **Pièce choisie** : marquage **fixe**, colonnes 0 et 4 de la case en vidéo normale
  (deux barres sombres, effet de crochets). Les deux effets se cumulent sans se gêner :
  l'attribut de case (`attr_case`) est combiné une fois pour toutes avant l'écriture, si bien
  que chaque caractère n'est écrit qu'une fois et que rien ne scintille.

### Sélection au curseur et saisie en notation

- Le curseur ne circule que sur les **cases foncées**. Flèches ou pavé numérique :
  `8/2/4/6` comme les flèches, `7/9/1/3` en diagonale.
- **Haut/bas** = `n-5` / `n+5`. Les deux cases foncées de la rangée voisine sont à égale
  distance (une colonne) ; retenir celle de même rang dans la rangée fait zigzaguer le curseur
  d'une colonne mais **sans dérive** (32 -> 37 -> 42 -> 47 revient toujours aux colonnes 3 et 2).
- **Gauche/droite** = `n-1` / `n+1`, en restant dans la rangée : les cinq cases d'une rangée
  portent des numéros consécutifs, il suffit de regarder le rang dans la rangée (`div5`).
- ESPACE ou RETURN : choisit la pièce, la relâche si c'est la même, change de pièce si c'en est
  une autre à soi, et joue le coup si la case est vide.
- Après un coup, le curseur **reste sur la case d'arrivée** (la dernière pièce jouée) ; en début
  de partie il part de la case 32 (`CASE_DEPART`).
- **`*` ouvre la saisie en notation** ; RETURN y amène le curseur sur la case tapée puis valide,
  si bien que les deux modes aboutissent au même code (`valider`). `*` ou DEL sur un tampon vide
  referme la saisie.

**Pourquoi `*` et pas directement un chiffre** : sur le clavier « business » du 8296, le pavé
numérique occupe des positions distinctes dans la matrice, mais l'éditeur le décode très
probablement vers **les mêmes codes PETSCII que les chiffres de la rangée du haut**. Les chiffres
servant à déplacer le curseur, ils ne peuvent plus ouvrir la saisie : il faut une touche à part.
Si la machine réelle révèle que le pavé émet des codes propres, il suffira d'ajouter ces codes à
la table `nav_touches` de `donnees.asm` pour rendre chiffres et pavé indépendants.

Codes écran PETSCII (mode graphique) — **vérifiés** en rendant les glyphes de
`characters-2.901447-10.bin` (le générateur du 8296) : tous les codes ci-dessous sont les bons.
Ajouter `$80` pour la vidéo inverse.

| Forme | Code écran |
|---|---|
| ╭ arc haut-gauche | `$55` |
| ╮ arc haut-droit | `$49` |
| ╰ arc bas-gauche | `$4A` |
| ╯ arc bas-droit | `$4B` |
| ─ trait horizontal centré | `$40` |
| ♦ losange | `$5A` |
| ● cercle plein / ○ cercle vide | `$51` / `$57` |
| │ trait vertical (cadre) | `$5D` |
| ┌ ┐ └ ┘ coins du cadre | `$70` `$6E` `$6D` `$7D` |
| espace / espace inverse | `$20` / `$A0` |

## Règles (dames internationales, règles officielles FFJD)

- 20 pions par camp, sur les cases foncées des 4 premières rangées. Les Blancs commencent.
- Pion : avance d'une case en diagonale ; **prend en avant et en arrière**.
- **Prise obligatoire**, rafles multiples dans un même coup.
- **Prise majoritaire** : obligation de jouer la rafle qui prend le **plus de pièces**
  (une dame compte comme une pièce). Entre rafles de même longueur, libre choix.
- **Dame volante** : se déplace et prend à distance sur toute la diagonale, peut s'arrêter sur
  n'importe quelle case libre après la pièce prise.
- Pièces prises retirées **à la fin** de la rafle ; une pièce ne peut pas être sautée deux fois
  (mais elle bloque le passage tant qu'elle n'est pas retirée).
- **Promotion** uniquement si le pion **termine** son coup sur la dernière rangée (pas s'il y passe
  pendant une rafle).
- Notation : `32-28` (déplacement), `28x19` (prise) ; pour une rafle ambiguë, accepter la saisie
  des cases intermédiaires.
- Option envisagée plus tard : « règles familiales » (sans prise majoritaire).

## Architecture du code

- **Assembleur** : 64tass. Sortie `.prg` avec adresse de chargement `$0401` et petite ligne BASIC
  `10 SYS1040` (code à partir de `$0410`), pour un lancement par `RUN`.
- **Plateau interne** : représentation avec **cases fantômes** en bordure, de sorte que les
  4 directions diagonales soient des décalages constants (pas de test de bord). Valider le schéma
  exact dans le prototype de référence avant de le coder en 6502.
- Contenu d'une case : vide, pion blanc, pion noir, dame blanche, dame noire, bordure.
- **Jouer/annuler sur place** (make/unmake) avec pile d'annulation, jamais de copie du plateau
  dans la recherche.
- **Générateur de coups** : d'abord recherche des prises (récursive pour les rafles, en gardant
  seulement les plus longues), sinon déplacements simples.
- **IA** : alpha-bêta + approfondissement itératif limité par le temps (horloge système / jiffies),
  tri des coups. Évaluation : matériel (dame ≈ 3 pions), avancement, centre, protection de la
  dernière rangée. Ensuite : table de transpositions (hachage Zobrist 16 bits) en RAM étendue.
- **Affichage** : redessiner uniquement les cases modifiées ; animations optionnelles
  (glissement case par case, clignotement des pièces prises).
- Organisation des sources : un fichier par module (`main.asm`, `ecran.asm`, `clavier.asm`,
  `coups.asm` le moteur de règles, `regles.asm` le lien avec l'interface, `ia.asm`, `donnees.asm`),
  constantes regroupées dans `constantes.asm`. `coups.asm` et `ia.asm` ne dépendent pas de
  l'affichage : c'est ce qui permet de les éprouver sur banc.
- Commentaires en français, noms de labels explicites.

## Plan de travail

1. **Affichage et saisie** — *fait, validé dans VICE, à valider sur la vraie machine*.
   Damier, pièces, panneau, légende, historique, **sélection au curseur** (flèches et pavé
   numérique) avec saisie en notation en complément, déplacement libre d'une pièce (aucune règle),
   aide, nouvelle partie, retour propre au BASIC.
   Modules : `main.asm`, `ecran.asm`, `clavier.asm`, `regles.asm`, `donnees.asm`,
   `donnees_tables.asm` (généré), `constantes.asm`.

   **À vérifier sur la 8296 réelle** (rien de tout cela n'est observable dans VICE) :
   - les **accents** : le jeu tourne avec `ROM_FR = 0` dans `constantes.asm`, donc sans accent
     (« PIECES », « LEGENDE »). Relever les codes écran réels de é, è, à, ç, ù avec un programme
     affichant les 256 codes, puis remplir le bloc `ROM_FR = 1` — c'est le seul endroit à toucher ;
   - les **proportions** : la case de 5x2 caractères paraît-elle carrée sur le moniteur ?
   - la **page zéro** : après une partie, LOAD et SAVE cassette fonctionnent-ils encore
     (l'EPROM EDEX 8000 pourrait utiliser `$B0`–`$BF` autrement que le KERNAL standard) ;
   - la **vitesse du clignotement** : réglée sur le bit 4 des jiffies, soit ~3 Hz en 50 Hz ;
   - les **flèches du curseur** et la touche **DEL** : `-keybuf` ne transmet que des caractères
     déjà décodés, ces codes de contrôle ne lui passent pas. Le pavé numérique, lui, est testé
     automatiquement puisqu'il émet des chiffres ordinaires. Les flèches empruntent exactement le
     même chemin de code (table `nav_touches`), seuls leurs codes `$1D/$9D/$11/$91` restent à
     confirmer ;
   - le **pavé numérique** : vérifier que `7/9/1/3` et `8/2/4/6` déplacent bien le curseur, et
     relever si ces touches émettent des codes différents des chiffres du haut (voir plus haut).
2. **Règles** — *fait, validé contre l'oracle sur 420 positions*.
   `coups.asm` contient le moteur, indépendant de l'affichage : génération des coups légaux
   (`generer_coups`), recherche dans la liste (`compter_coups_piece`) et application
   (`appliquer_coup`, prises retirées et promotion). `regles.asm` fait le lien avec l'interface.
   - **Format d'un coup** : `[départ][arrivée][nombre de prises][cases prises…]`, rangés bout à
     bout dans `coups_zone`, `coups_index` pointant chacun. Les numéros sont les officiels 1–50.
   - **Rafles** : recherche en profondeur, l'état de chaque niveau étant rangé dans des tables
     indexées par `prof` — la pile du 6502 ne porte que les adresses de retour.
   - **Prise majoritaire** appliquée au fil de l'eau : dès qu'une rafle plus longue apparaît, la
     liste est vidée. Deux chemins menant au même résultat sont fusionnés (`coup_deja_connu`).
   - **Rafle ambiguë** : deux chemins de mêmes extrémités mais de butins différents. Le joueur
     désigne alors une pièce à prendre ; elle s'ajoute aux `filtres` qui restreignent la recherche.
   - **Fin de partie** : détectée quand le camp au trait n'a plus aucun coup.

   **Ce qui n'est pas couvert automatiquement** : le départage interactif d'une rafle ambiguë.
   Le banc d'essai vérifie que les deux coups sont bien générés, mais le jeu démarre toujours en
   position initiale, et aucune de ces rafles n'y survient en quelques coups. À vérifier à la main.
3. **IA** — *fait, validée contre une référence Python jusqu'à la profondeur 4*.
   `ia.asm` contient l'évaluation et la recherche ; `regles.asm` déclenche le tour de la machine.
   - **Évaluation** (negamax, du point de vue du camp au trait) : pion 100, dame 300, plus une
     valeur de position lue dans `bonus_pion` / `bonus_dame` (avancement vers la promotion,
     colonnes centrales, dernière rangée encore gardée). Les tables sont générées par
     `outils/generer_tables.py`, la symétrie Noirs/Blancs se faisant par `case n ↔ 51-n`.
   - **Jouer/annuler sur place** : la recherche ne recopie jamais le plateau. `jouer_rech` empile
     dans `annul_zone` de quoi défaire le coup, `annuler_rech` dépile. La pièce d'avant promotion
     est empilée elle aussi, sans quoi une dame resterait dame en remontant.
   - **Listes de coups par niveau** : chaque appel réserve sa tranche à partir de `coups_fin` et
     la rend en repartant ; `vider_coups` revient au début de la tranche, pas à celui de la zone.
   - **Alpha-bêta** avec approfondissement itératif limité par l'horloge système, profondeur et
     durée venant du niveau (`niveau_limite_*`, `niveau_prof`).
   - **Tri des coups** à la racine : `construire_ordre` range les adresses des coups dans une
     table (les déplacer coûterait cher, leur longueur variant) et met en tête celui retenu à
     l'itération précédente.
   - **Table de transpositions** : hachage Zobrist 16 bits tenu à jour au fil des coups,
     1024 entrées de 8 octets. Elle se désactive par `UTILISER_TABLE = 0` dans `constantes.asm`,
     la recherche donnant alors exactement les mêmes résultats.

   **Mesures** (dans VICE, donc à la vitesse de la vraie machine) :
   - une génération de coups coûte **~29 ms en ouverture**, 7 à 13 ms ensuite. C'est ce qui fixe
     tout le reste : la profondeur 3 revient à ~1 s par position, la profondeur 4 à ~3 s ;
   - la table de transpositions coûte **+12 % à la profondeur 3 et +2 % à la profondeur 4**, sans
     rien rapporter à ces profondeurs. Elle est tout de même activée : le surcoût s'efface quand on
     descend, et en finale (peu de pièces, génération rapide) l'approfondissement va bien plus bas.
     Si l'on cherche de la vitesse, c'est le **générateur de coups** qu'il faut optimiser, pas la
     recherche.

   **Pourquoi la table n'est pas en RAM étendue**, contrairement au plan initial : le programme et
   ses zones de travail s'arrêtent avant `$3C00`, ce qui laisse **plus de 16 Ko de RAM ordinaire**
   libres sous `$8000`. La table y tient largement, sans toucher au registre `$FFF0`, qui est en
   écriture seule et conditionne la visibilité de l'écran et des E/S. Le passer en banques
   demanderait de le documenter avec certitude d'abord — ce que le plan exige — pour un gain nul
   tant que la table tient en dessous. La RAM étendue reste donc disponible pour une table
   beaucoup plus grande ou une bibliothèque d'ouvertures.

   **À vérifier sur la 8296 réelle** : la durée de réflexion, réglée en images d'écran (50 par
   seconde) — une machine en 60 Hz réfléchirait un cinquième de temps en moins.
4. **Finitions** — *menu, retour arrière et choix du camp faits ; animations restantes*.
   - **Écran de réglages** (`menu.asm`), affiché au lancement et rappelé par **M** : niveau (1–3)
     et camp du joueur. Navigation par `8`/`2` ou les flèches, `4`/`6` pour modifier, ESPACE pour
     commencer. Aux dames les Blancs jouent toujours le premier coup : **choisir son camp revient
     donc à décider qui commence**, et l'écran le rappelle. « LES DEUX » donne une partie à deux
     joueurs sans ordinateur.
   - **Retour arrière** par **R**. Chaque coup joué pour de bon dépose dans `annul_partie` de quoi
     le défaire : `[6 octets d'historique chassé][pièce d'origine][départ][arrivée][nombre de
     prises][(case, pièce) par prise][longueur]`. La longueur en fin d'entrée permet de reculer
     dessus puis de relire l'entrée en avant. La pièce d'origine est conservée, sans quoi une dame
     faite au dernier coup resterait dame en remontant.
     R ramène le joueur à **sa** position précédente : défaire un seul demi-coup rendrait la main
     à l'ordinateur, qui rejouerait aussitôt. La pile tient environ 150 demi-coups ; au-delà on
     cesse d'empiler et le retour ne remonte pas plus loin, sans rien abîmer.
   - **Remise à zéro** : **N** rejoue une partie en gardant les réglages, M les change.
   - Restent à faire : les animations (glissement, clignotement des pièces prises) et la gestion
     de la nulle.

   **Piège de l'historique** : `ajouter_historique` met de côté l'entrée qu'il chasse, et c'est
   elle que la pile emporte. L'empilement doit donc venir **après** lui, pas avant — sinon on
   empile l'entrée chassée du coup précédent et l'historique se décale d'un cran au retour.

Valider chaque étape dans VICE puis sur la vraie machine avant de passer à la suivante.

## Outils et tests

- Installation : `sudo apt install vice 64tass`.
- **ROMs VICE** : Debian ne livre pas les ROMs. Les prendre dans une archive officielle de VICE
  (par exemple `SDL2VICE-3.9-win64.zip` sur zimmers.net) et les déposer dans le dossier
  **utilisateur**, sans droits root :
  ```
  unzip -j -o vice.zip "SDL2VICE-3.9-win64/PET/*.bin"    -d ~/.local/share/vice/PET/
  unzip -j -o vice.zip "SDL2VICE-3.9-win64/DRIVES/*"     -d ~/.local/share/vice/DRIVES/
  ```
  Les ROMs **DRIVES sont indispensables** : sans elles `-autostart` échoue en silence et laisse un
  écran noir, ce qui ressemble à s'y méprendre à un plantage du programme.
- Assemblage : `64tass --cbm-prg -o dames.prg main.asm` (ajouter `-L dames.lst` pour un listing).
- Test avec capture d'écran, et injection de touches :
  ```
  xpet -model 8296 -autostart dames.prg -limitcycles 26000000 \
       -exitscreenshot ecran.png -warp +sound -keybuf '32
  28
  '
  ```
  `-keybuf` écrit dans le tampon clavier ; `\n` y vaut RETURN. **Limites** : les lettres doivent
  être tapées en **minuscules** (`n`, `q`), les majuscules ASCII arrivant shiftées, et la touche
  **DEL (`$14`) ne passe pas** — l'effacement d'un chiffre se vérifie donc à la main.
- `outils/lire_ecran.py capture.png` : relit la capture et reconstitue la grille 80x25 de **codes
  écran**, en comparant chaque cellule aux glyphes du générateur de caractères. C'est ce qui permet
  de vérifier l'affichage sans regarder l'image, et ce qui servira à relire la mémoire de
  l'émulateur à l'étape 2. Détails utiles :
  - sur les captures de VICE, une cellule fait **8x9 pixels** (8 de dessin, 1 de blanc) ;
  - les deux jeux de caractères (graphique et minuscules) sont reconnus automatiquement ;
  - VICE prend parfois sa capture au milieu d'un rafraîchissement : quelques cellules sortent
    déformées, elles sont alors rattachées au glyphe le plus proche et signalées. **Un écran
    partiellement incohérent n'est donc pas forcément un bug du jeu** : refaire la capture à un
    autre nombre de cycles avant de conclure.
- `outils/test_affichage.py` : joue une douzaine de scénarios (position de départ, sélection,
  saisies refusées, coup joué, historique, aide, nouvelle partie, retour au BASIC, clignotement)
  et vérifie le contenu des lignes attendues. À lancer après toute modification de l'affichage.
- `outils/generer_tables.py` : régénère `donnees_tables.asm` (tables cases <-> plateau <-> écran,
  bonus de position, hachage Zobrist).
- **`outils/carte_memoire.py`** dresse la carte de la RAM et dit ce qu'il reste. À lancer après
  chaque ajout un peu gros : les zones de travail sont à adresse fixe et le programme finit par
  les rattraper. État au moment où le menu a été ajouté : programme 9 308 octets, **9,0 Ko libres**
  en RAM utilisateur, dont 6 Ko d'un seul tenant en `$6800`–`$7FFF`, et **1 955 octets de marge**
  avant la première zone de travail. Les 64 Ko de RAM étendue n'ont jamais été touchés.
- **`outils/test_ia.py`** compare l'évaluation et la recherche à `outils/reference_ia.py`, qui
  reproduit exactement le même barème et le même parcours. Il vérifie aussi, à chaque position,
  que **le plateau et la clef de hachage sont revenus à leur état de départ** : c'est ce qui
  attrape les erreurs de jouer/annuler, invisibles autrement. Le coup retenu n'est pas comparé
  directement — à score égal, les deux gardent le premier rencontré, et ils ne produisent pas les
  coups dans le même ordre — mais on vérifie qu'il atteint bien le score optimal.
  Lancer `python3 outils/test_ia.py -p 3 -n 12`.
- **`outils/mesurer_vitesse.py`** chronomètre le générateur de coups sur quelques positions.
- **Référence des règles** : `outils/reference.py` génère les coups légaux d'une position. Il sert
  d'oracle. `outils/test_reference.py` le juge lui-même sur 16 positions calculées à la main
  (rafle en carré revenant à la case de départ, blocage par une pièce déjà prise, promotion et
  traversée sans promotion, dame volante, rafle ambiguë…) — un oracle non vérifié ne vaut rien.
- **`outils/test_coups.py`** compare le générateur 6502 à l'oracle :
  1. il tire une batterie (cas construits + positions aléatoires à germe fixe) ;
  2. il l'écrit dans `test_positions.asm` et assemble `test_coups.prg` ;
  3. VICE l'exécute, le programme dépose ses résultats en `$3000` ;
  4. le pilote les relit **par le moniteur distant de VICE** et compare, position par position.

  Il vérifie aussi le **plateau obtenu** après application du premier coup, ce qui couvre le
  retrait des pièces prises et la promotion. Lancer `python3 outils/test_coups.py -n 300`.

  Pièges rencontrés, à ne pas réapprendre :
  - le moniteur fait précéder ses réponses de l'**invite de la commande précédente** : attendre
    une invite décale tout le dialogue. La lecture se repère donc à l'adresse annoncée en tête de
    chaque ligne, et réclame une tranche à la fois ;
  - les octets arrivent **par groupes de quatre séparés de deux espaces**, le rendu caractère
    venant après trois espaces ;
  - les zones de travail sont à adresse fixe (`$3000` et au-delà) ; la table des positions,
    embarquée dans le `.prg`, finirait par mordre dessus. D'où le traitement **par lots de 60
    positions**, chacun assemblé et exécuté séparément. `main.asm` se termine par un
    `.cerror * > DEBUT_ZONES` : le programme a déjà grandi jusqu'à recouvrir ces zones, ce qui
    abîme le plateau en pleine recherche et ne se voit qu'au bout d'un long moment.
- Le propriétaire teste aussi sur la **vraie 8296** : garder un `.prg` à jour et lui signaler
  ce qui doit être vérifié sur machine réelle (notamment les accents).
  
  
  ## AFFICHAGE — *appliqué*

  Consigne d'origine, conservée pour mémoire. Tout a été implémenté tel quel, à une réserve
  près : « taper un chiffre bascule en mode saisie » était incompatible avec « 7/9/1/3 déplace
  le curseur », les deux séries de touches émettant selon toute vraisemblance les mêmes codes.
  Arbitrage retenu : les chiffres déplacent le curseur, et **`*` ouvre la saisie en notation**.
  Voir « Sélection au curseur et saisie en notation » plus haut.

  Remplace la sélection par coordonnées par une sélection au curseur.

Curseur :
- Il se déplace uniquement sur les cases foncées (jouables).
- Flèches gauche/droite : case foncée précédente/suivante de la même rangée.
- Flèches haut/bas : rangée voisine, case foncée la plus proche dans la même colonne.
- Pavé numérique : 7/9/1/3 = déplacements diagonaux, 8/2/4/6 = mêmes rôles que les flèches.
- Position de départ : la dernière pièce jouée par le joueur, sinon la case 32.

Validation (ESPACE ou RETURN) :
- Sur une pièce du joueur : sélection. Sur la pièce déjà sélectionnée : désélection.
  Sur une autre pièce du joueur : changement de sélection.
- Sur une case vide avec une pièce sélectionnée : le coup est joué
  (pas encore de vérification des règles, c'est l'étape 2).

Affichage :
- Curseur : toute la case 5x2 clignote en inversion vidéo (~2 Hz).
- Pièce sélectionnée : marquage fixe, colonnes 0 et 4 de la case en vidéo normale (effet de crochets).
- Ligne d'état : "CASE nn" pour la case sous le curseur.

Conserver la saisie en notation : taper un chiffre bascule en mode saisie, comme avant.

Les codes des touches curseur et du pavé numérique viennent de GETIN ($FFE4).
Vérifie-les dans VICE, et prévois-les comme constantes dans constantes.asm :
l'éditeur de la machine réelle est une ROM française modifiée, les codes pourraient différer.

Adapation ROM EDEX :
Codes écran validés sur la vraie 8296 (ROM française) : remplis le
préréglage "ROM FRANCAISE" de la table de correspondance avec :

  arc haut-gauche  ╭ : 82      arc haut-droit  ╮ : 84
  arc bas-gauche   ╰ : 70      arc bas-droit   ╯ : 71
  trait horizontal ─ : 102     (pions et cadre)
  marque de dame     : 83      (petit carré, remplace le losange absent)
  trait vertical   │ : 97
  coins du cadre     : ┌ 104   ┐ 106   └ 98   ┘ 100

Inversion vidéo : +128 comme sur la ROM standard (vérifié).
Codes 112 à 127 : caractères accentués (§ à è ì ò ù â ê î ô û Ä Ö Ü ß é),
à utiliser pour les textes accentués du panneau en mode ROM FRANCAISE.

Le préréglage "ROM FRANCAISE" doit être le choix par défaut au démarrage.

Ajoute un écran de choix au démarrage du jeu :
- Afficher côte à côte deux échantillons (pion blanc, pion noir, coin de
  cadre et trait), l'un avec le préréglage ROM STANDARD, l'autre avec
  le préréglage ROM FRANCAISE (EDEX). Libellés : "1 - ROM STANDARD" et
  "2 - ROM FRANCAISE (EDEX)". Les libellés n'utilisent que des lettres
  sans accent (codes 1-26), communs aux deux ROMs.
- Touches 1 et 2 pour choisir, RETURN pour valider la présélection.
- Présélection automatique : lire quelques octets de la ROM éditeur
  ($E000-$E7FF) et les comparer à l'éditeur standard de la 8296
  (référence : ROM d'éditeur de VICE). S'ils diffèrent, présélectionner
  ROM FRANCAISE. Choisir des octets significatifs et documenter ce choix.
- Le choix s'applique à toute la partie, et reste modifiable depuis le
  menu (avec l'écran de calibrage existant).
- Les textes accentués du panneau (codes 112-127) ne sont utilisés
  qu'en mode ROM FRANCAISE ; en mode standard, utiliser les lettres
  sans accent.

### Adaptation ROM EDEX — *appliqué*

Les formes du damier ne sont plus des constantes d'assemblage mais des **variables**
(`car_arc_hg`, `car_trait_h`, `car_dame`…), remplies au lancement par `appliquer_rom` depuis
l'un des deux préréglages de `donnees.asm`. Les accents suivent le même chemin : les textes
portent des **marqueurs** (`ACC_E_AIGU` = `$1B` à `ACC_C_CEDIL` = `$1F`, des codes que le jeu
n'emploie pas ailleurs) et `afficher_texte` les remplace par le caractère de la ROM active, ou
par la lettre sans accent en mode standard. Un seul jeu de textes sert donc aux deux ROM.

L'EPROM française n'a ni losange ni c cédille : la dame y porte un **petit carré** (code 83) et
le ç retombe sur un C. Ses accents (codes 112–127) sont des **minuscules** : en mode français on
lit donc « PIèCES », seule façon d'avoir l'accent avec ce générateur.

`ecran_rom.asm` montre au lancement les deux jeux côte à côte — un pion blanc, un pion noir et un
petit cadre fermé, tracés chacun avec son préréglage — et laisse choisir par `1`/`2`, `RETURN`
pour valider. Les libellés n'emploient que des lettres sans accent, communes aux deux ROM : il
faut pouvoir les lire **avant** d'avoir choisi. Le réglage reste modifiable depuis le menu
(3ᵉ ligne), et `C` y rouvre l'écran de comparaison.

> **Réserve importante, à trancher avant d'essayer sur la machine.**
> Le fichier `characters.901447-azerty.bin` déposé dans le projet **ne concorde pas** avec les
> codes ci-dessus. Vérifié en le chargeant dans VICE (`xpet -chargen …`) :
> - aux codes 82, 84, 70, 71 il porte les lettres **R, T, F, G** ; le damier s'affiche
>   « R&T / F&G » au lieu des pions ;
> - les **arcs arrondis et le losange en sont absents** : on n'y retrouve aucune des quatre
>   formes d'arc du jeu graphique standard ;
> - ses accents sont aux codes **92 à 121**, et non 112 à 127 ;
> - c'est un fichier de 4 Ko qui répète deux fois le même 2 Ko, et dont les deux jeux sont des
>   variantes du jeu **minuscules** — il n'y a pas de jeu majuscules + graphiques dedans.
>
> Autrement dit, ce fichier n'est pas le générateur qui a servi à relever les codes. Les codes
> retenus dans le préréglage sont ceux de la section ci-dessus, **relevés sur la vraie 8296**,
> qui restent la source la plus fiable pour la machine. Mais l'adaptation ne peut pas être
> validée dans l'émulateur tant qu'on ne dispose pas du générateur correspondant : le vérifier
> demande un essai sur la machine, ou le bon fichier d'EPROM.

**Présélection** : `detecter_rom` fait la somme sur 16 bits de toute la ROM de l'éditeur
(`$E000`–`$E7FF`) et la compare aux empreintes des éditeurs standard connus. Celles des versions
50 Hz et 60 Hz se trouvent être identiques (`$528A`), ce qui rend la reconnaissance robuste ;
VICE charge une variante qui vaut `$52AE`, également admise. Toute autre somme est tenue pour
une ROM française — c'est le défaut voulu, et au pire une touche corrige. Vérifié : dans VICE la
présélection tombe bien sur « ROM STANDARD ».

### Déplacement sonore et suivi des mouvements — *appliqué*

`son.asm`. Le haut-parleur du PET est branché sur CB2 du VIA : on met le registre à décalage en
roue libre (`ACR` = `$10`) et la hauteur dans `T2`. **Piège** : CB2 commande aussi le jeu de
caractères (`$E84C`), il faut donc le remettre après chaque son, sinon l'écran repasse en
minuscules. Vérifié : l'affichage est intact après un bip.

Un bip court et aigu pour un déplacement, un son plus grave et plus long pour une prise. Lors
d'une rafle, chaque pièce mangée est redessinée **barrée d'une croix** (elle garde sa vidéo, donc
sa couleur), avec une demi-seconde entre chacune : on suit ainsi le trajet de la pièce qui mange.
L'animation a lieu **avant** `appliquer_coup`, qui a besoin du plateau encore intact.

**La touche `A`** coupe animation et bruitages, pour qui veut aller vite.

Limite connue : le format d'un coup ne retient que le départ, l'arrivée et les pièces prises, pas
les cases intermédiaires. L'animation suit donc les **prises** dans l'ordre de la rafle, ce qui
revient au même pour un pion ; pour une dame qui s'arrête loin derrière sa proie, le trajet exact
n'est pas rejoué. Purement cosmétique : le coup appliqué reste exact.

**Pour les tests** : les pauses saturent le tampon clavier de 10 caractères que VICE remplit à
toute vitesse, et les touches au-delà se perdent. Les scénarios de `test_affichage.py` coupent
donc l'animation par un `a` en tête. Un joueur humain n'a pas ce souci : le tampon du KERNAL
mémorise ce qu'il tape pendant l'animation.

Evolution deplacement sonore et suivi des mouvements :
Chaque deplacement doit être accompagné d'un son, si une piece est prise le son doit être different. 
Il faut que lorsque le deplacement est sur plusieurs case, mettre une tempo 1/2 secondes entre chaque deplacement et
changer la forme de la piece lorsqu'il y a une prise.

# Command & Conquer : mapping de la roue, v3

Version du 17/11/2026 pour Dany. WoW Classic / Forever, Warsong Gulch (WSG), côté Alliance, tranche 20-29.
Source principale : `/workspace/wsg-recherche/glossaire-wsg.md` (recherche du 17/11/2026). Sources reprises du glossaire. Une ligne sans source fiable est marquée « non vérifié ».

## Changements depuis la v2 (décisions de Dany, 17/11/2026 13h11)

- Nombre d'ennemis pour INC : validé (forme proposée plus bas).
- Pas de part BUFFS ni ÉQUIPE : la roue reste à 5 actions x 8 choix.
- Messages en anglais, par défaut et pour le moment. Une version FR reste faisable plus tard (colonne en plus).
- Phrases courtes : 3 à 7 mots, claires pour un novice. Terme court entre parenthèses seulement quand il aide (ex. EFR, zerg, turtle).
- Rappel des règles d'interaction : la roue s'ouvre sous le curseur sur une touche, le choix se fait en glissant la souris assez loin dans une direction, sans clic. Étape 2 dynamique selon l'action. Pas de chevrons, pas de repère « 1/2 ». Icônes au premier plan, texte discret.

## Repères de carte

| Lieu | Ce que c'est | Source (date) |
|---|---|---|
| Flag room (FR / EFR) | Salle du drapeau, chez nous / chez eux | warcraft.wiki.gg (date non vue) ; revengeofthegnomes (18/11/2011) |
| Tunnel | Entrée principale de la base, buff vitesse | warcraft.wiki.gg ; wowhead map (28/03/2022) |
| Ramp | Entrée secondaire, près de la cabane Berserking | warcraft.wiki.gg ; wowhead map (28/03/2022) |
| Roof | Au-dessus de la salle du drapeau, « là où tout se joue » | wowhead map (28/03/2022) |
| Balcony | 2e niveau qui surplombe la salle du drapeau | xpoff (04/06/2009) ; wowhead map (28/03/2022) |
| GY side / Lobby | Route côté cimetière ; lobby = entrée basse côté cimetière | macros xpoff (date non vue) ; wowhead map (28/03/2022) |
| Mid west / Mid east | Ouest : souches, catapulte. Est : chantier, grue | wowhead map (28/03/2022) |
| Banana | Chemin extérieur du tunnel jusqu'au toit, rassemblement de l'attaque | wowhead map (28/03/2022) |

## Niveau 1 : les 5 actions

| Part | Action | Sens | Source (date) |
|---|---|---|---|
| 1 | DEF | Défendre un endroit chez nous | Defense, Turtle, Escort : wowisclassic (26/11/2019) ; xpoff ; foreverbattlegrounds (10/11/2026) |
| 2 | ATTAQUE | Attaquer un endroit chez eux | Offense, Zerg, Banana : wowisclassic (2019) ; wowhead map (2022) |
| 3 | INC | Des ennemis arrivent (avec nombre) | Inc / Inc X : wowisclassic (2019) ; revengeofthegnomes (2011) |
| 4 | FLAG | Notre porteur et leur drapeau | FC, Pick, Cap, macros xpoff ; wowhead |
| 5 | RECUP | Leur porteur a notre drapeau | EFC, Return : wowisclassic (2019) ; revengeofthegnomes (2011) ; foreverbattlegrounds (2026) |

## Niveau 2 : 8 choix par action, messages EN

### 1. DEF

| # | Choix | Message /bg | Mots | Source (date) |
|---|---|---|---|---|
| 1 | Salle | Defend our flag room | 4 | wowisclassic (26/11/2019) ; warcraft.wiki.gg (date non vue) |
| 2 | Toit | Defend our roof | 3 | Roof, lieu clé de la défense : wowhead map (28/03/2022) |
| 3 | Balcon | Defend our balcony | 3 | Rogue au balcon en défense : wowhead map (28/03/2022) |
| 4 | Tunnel | Defend our tunnel | 3 | wowhead map (28/03/2022) |
| 5 | Rampe | Defend our ramp | 3 | Hunter qui garde la ramp : wowhead map (28/03/2022) |
| 6 | Lobby | Guard our GY side entrance | 5 | Lobby : wowhead map (28/03/2022) |
| 7 | Escorte | Protect our flag carrier | 4 | Escort : foreverbattlegrounds (10/11/2026) |
| 8 | Turtle | Everyone defend our base (turtle) | 5 | Turtle : xpoff page 2 (date non vue) ; revengeofthegnomes (18/11/2011) |

### 2. ATTAQUE

| # | Choix | Message /bg | Mots | Source (date) |
|---|---|---|---|---|
| 1 | Leur salle | Attack their flag room (EFR) | 5 | EFR : revengeofthegnomes (18/11/2011) |
| 2 | Leur toit | Attack their roof | 3 | wowhead map (28/03/2022) |
| 3 | Leur balcon | Attack their balcony | 3 | wowhead map (28/03/2022) |
| 4 | Leur tunnel | Attack through their tunnel | 4 | Tunnel + préfixe « e » : wowhead map (2022) ; wowisclassic (2019) |
| 5 | Leur rampe | Attack through their ramp | 4 | Idem |
| 6 | Banana | Group up at their banana | 5 | Rassemblement de l'offense : wowhead map (28/03/2022) |
| 7 | Milieu | Take control of mid | 4 | Contrôle du mid = passage sûr du porteur : wowhead map (28/03/2022) |
| 8 | Tous | Everyone attack their base (zerg) | 5 | Zerg : xpoff (04/06/2009) ; revengeofthegnomes (18/11/2011) |

Volontairement absent : camper leur cimetière (GYC, revengeofthegnomes 2011), cité comme piège de débutant (wowisclassic, 2019).

### 3. INC (avec nombre)

Message sans nombre / avec nombre (exemple pour 3).

| # | Choix | Message /bg | Avec nombre | Source (date) |
|---|---|---|---|---|
| 1 | Tunnel | Incoming at our tunnel | 3 incoming at our tunnel | « INC TUN » : revengeofthegnomes (18/11/2011) |
| 2 | Rampe | Incoming at our ramp | 3 incoming at our ramp | « INC RAMP » : revengeofthegnomes (18/11/2011) |
| 3 | Côté cimetière | Incoming at our GY side | 3 incoming at our GY side | Route « GY Side » : macros xpoff (date non vue) |
| 4 | Toit | Incoming on our roof | 3 incoming on our roof | Roof : wowhead map (2022). Call « inc roof » mot pour mot : **non vérifié** |
| 5 | Balcon | Incoming from our balcony | 3 incoming from our balcony | « They're dropping from Balcony now » : wowhead team comp (12/03/2020) |
| 6 | Banana | Incoming up our banana | 3 incoming up our banana | Banana : wowhead map (2022). Call « inc banana » mot pour mot : **non vérifié** |
| 7 | Milieu ouest | Incoming mid west | 3 incoming mid west | West / East : wowhead map (28/03/2022) ; xpoff 19s (date non vue) |
| 8 | Milieu est | Incoming mid east | 3 incoming mid east | Idem |

Sources du nombre : « Inc X = X ennemis arrivent » (wowisclassic, 26/11/2019) ; « Three in tunnel. Priest, Warrior, Warlock. » (wowhead team comp, 12/03/2020). Format 10 contre 10 (warcraft.wiki.gg, date non vue), d'où un plafond « 5+ ».

#### Choisir le nombre : 3 options

| Option | Fonctionnement | Pour | Contre |
|---|---|---|---|
| A. 3e étape | Après le lieu, une petite roue 1 / 2 / 3 / 4 / 5+ s'ouvre ; on glisse vers le nombre. Relâcher la touche sans glisser = envoi sans nombre | Même geste que les étapes 1 et 2, rien à apprendre ; marche sans molette | Un mouvement de plus (environ une demi-seconde, estimation **non vérifiée**) |
| B. Molette | Pendant l'étape 2 d'INC, la molette règle le nombre affiché au centre, puis on glisse vers le lieu | Le plus rapide pour un joueur entraîné | Il faut régler AVANT de glisser, car le glissé envoie tout de suite ; la molette sert souvent au zoom caméra ou au spam-clic du drapeau (« Interact with Mouseover » sur la molette, conseil wowhead intro 12/03/2020) |
| C. Touche | Touches 1 à 5 tenues ou tapées pendant que la roue est ouverte | Rapide | Les touches 1 à 5 sont en général la barre d'actions ; demande les deux mains en plein combat |

**Recommandation : option A (3e étape), seulement pour INC.** Elle garde le même geste partout (ouvrir, glisser, glisser), n'entre en conflit avec aucune touche ni avec la molette, et le « sans nombre » reste possible. Le comportement exact de l'API (capturer la molette ou une touche pendant que la roue est ouverte) est **non vérifié** sur Forever ; l'option A n'en dépend pas.

### 4. FLAG

| # | Choix | Message /bg | Mots | Source (date) |
|---|---|---|---|---|
| 1 | Je l'ai | I have their flag, escort me | 6 | FC + Escort : warcraft.wiki.gg (date non vue) ; foreverbattlegrounds (10/11/2026) |
| 2 | Par tunnel | Our flag carrier going tunnel | 5 | Macro « Our Flag Carrier is going TUNNEL! » : xpoff macros (date non vue) |
| 3 | Par rampe | Our flag carrier going ramp | 5 | Macro « ... going RAMP! » : xpoff macros (date non vue) |
| 4 | Côté cimetière | Our flag carrier going GY side | 6 | Macro « ... going GY Side! » : xpoff macros (date non vue) |
| 5 | Aide | Our flag carrier needs help (peel) | 6 | Peel : wowhead map (28/03/2022) ; escort : foreverbattlegrounds (10/11/2026) |
| 6 | Ramassez | Their flag dropped, pick it up | 6 | Pick / Repick : wowhead team comp (12/03/2020) ; Zurk Maps « PICK » (date non vue) |
| 7 | Capturez | Our flag is home, cap now | 6 | Cap : warcraft.wiki.gg (date non vue) ; condition de capture : wowhead intro (12/03/2020) |
| 8 | Bloqué | Can't cap, get our flag back | 6 | Deux drapeaux sortis, personne ne marque : foreverbattlegrounds (10/11/2026) ; wowhead intro (12/03/2020) |

### 5. RECUP

| # | Choix | Message /bg | Mots | Source (date) |
|---|---|---|---|---|
| 1 | Notre tunnel | Enemy carrier at our tunnel (EFC) | 5 | « EFC TUN » : revengeofthegnomes (2011) ; « EFC tunnel » : foreverbattlegrounds (10/11/2026) |
| 2 | Notre rampe | Enemy carrier at our ramp | 5 | « efc ramp » : wowisclassic (26/11/2019) ; foreverbattlegrounds (10/11/2026) |
| 3 | Côté cimetière | Enemy carrier at our GY side | 6 | Macro « The Enemy Flag Carrier is going GY Side! » : xpoff (date non vue) |
| 4 | Milieu ouest | Enemy carrier mid west | 4 | wowhead map (28/03/2022) ; xpoff 19s (date non vue) |
| 5 | Milieu est | Enemy carrier mid east | 4 | « /bg EFC IS EAST SIDE!!! » : xpoff 19s (date non vue) |
| 6 | Leur toit | Enemy carrier on their roof | 5 | « EFC roof » : foreverbattlegrounds (10/11/2026) |
| 7 | Leur salle | Enemy carrier in their flag room | 6 | EFR : revengeofthegnomes (2011). Call « EFC EFR » mot pour mot : **non vérifié** |
| 8 | Au sol | Our flag dropped, click to return | 6 | Return : xpoff (04/06/2009) ; retour auto après 15 s : wowhead intro (12/03/2020) |

Note : « (EFC) » n'apparaît qu'au choix 1 pour que le novice apprenne le terme ; à retirer si Dany préfère. Option non retenue pour l'instant : PV de leur porteur dans le message (Sweatybetty, wago ; Zurk Maps, CurseForge ; dates non vues), lecture des PV ennemis sur Forever **non vérifiée**.

## Point bloquant Forever (à tester avant tout développement)

- Deux sites Forever indiquent que les add-ons **ne peuvent pas envoyer de message de chat dans un BG** (« Callouts are manual in Forever »). Sources : foreverbattlegrounds.com add-ons (07/11/2026) et WSG (10/11/2026). Statut « reported », non confirmé par Blizzard.
- Origine probable : restrictions héritées de Midnight (« Instance communication lockdown »). Source : wowforevertierlist.com (31/10/2026), application aux BG non confirmée.
- Sur Classic Era, l'envoi en /bg par add-on fonctionne (Sweatybetty, Zurk Maps ; script SendChatMessage, forum Blizzard 09/06/2019).
- Premier test en jeu sur Forever : un add-on minimal qui envoie une ligne en /bg. Si c'est bloqué, la roue devra se limiter à l'affichage local ou à une aide à la saisie : **non vérifié**.

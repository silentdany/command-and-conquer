# Roue Arathi Basin : recherche et plan

Note du 23/11/2026, pour préparer la roue Arathi Basin (AB) et le changement automatique de roue selon le BG.
Rien n'est codé ici : ce sont des faits sourcés, une proposition de roue à valider par Dany, et un plan technique.
Les sources sont en bas. Une ligne sans source fiable est marquée **à vérifier**.

## 1. Arathi Basin sur Forever

| Point | Ce qu'on sait | Source |
|---|---|---|
| Disponible | Oui, un des 4 BG de lancement (4/11/2026), niveau 20 à 60, 15 contre 15 | fextralife, loreforeverwow, wowforevertierlist |
| Bases | 5 : Stables (ST), Gold Mine (GM, « Mine »), Blacksmith (BS), Lumber Mill (LM), Farm | warcraft.wiki.gg (abréviations), wowhead |
| Départs | Alliance : Trollbane Hall (nord-ouest). Horde : Defiler's Den (sud-est) | wowforeverinfo, icy-veins |
| Victoire | 2000 ressources | wowforeverinfo, lfcarry |
| Ressources | 10 par tick ; 1 base ≈ 12 s, 2 ≈ 9 s, 3 ≈ 6 s, 4 ≈ 3 s ; 5 bases = 30 par tick (fin quasi immédiate). Un guide Forever (wowforever.games) dit autre chose pour 5 bases : **à vérifier en jeu** | lfcarry, wowforeverinfo, turtle-wow |
| Semaine bonus AB | Du 24/11 au 1/12/2026 (plus d'honneur) : **bon moment pour tester en vrai** | résumé de recherche (client du jeu, cité par un site tiers) |

### Géographie (nord en haut, comme la carte du jeu)

```
   ST (NO, près de l'Alliance)        GM (NE, la plus basse, isolée)
                     BS (centre, la plus disputée)
   LM (SO, en hauteur)                Farm (SE, près de la Horde)
```

- ST, BS et Farm : toutes les sources sont d'accord.
- LM au sud-ouest et GM au nord-est : wowhead et le wiki Forever (wowcalc) ; un vieux guide Classic met LM au sud-est. **À vérifier** sur la carte en jeu (deux minutes en BG suffisent).
- LM en hauteur, GM en contrebas : GM « la zone la plus basse » (icy-veins) ; la hauteur de LM vient de ma mémoire du jeu, **à vérifier**.

### Ce que les joueurs disent

- Format de base d'un INC : un nombre et une base, mis à jour quand d'autres arrivent : « 4 inc BS », « inc 3 LM » (wow-pro ; scoots 2007, macros « INC BS (middle) »).
- Après un INC, rester sur le drapeau, ne pas poursuivre (wow-pro, wowforeverinfo).
- « LUMBER CLEAR » / « INC LUMBER » : presets de l'add-on PvPCallouts (GitHub). « clear » ou « safe » n'est défini nulle part comme standard, mais il est courant : **à vérifier** auprès des joueurs Forever.
- « Ninja » : prendre une base discrètement (wow-pro).
- Stratégie la plus citée sur Forever : tenir 3 bases. Alliance ST + LM + BS, Horde Farm + GM + BS ; laisser un garde à GM (isolée). Variante à 4 bases : un groupe par GM, LM, BS et la base proche prise en passant (wowforeverinfo, foreverbattlegrounds).
- Une base attaquée change de main au bout d'environ une minute (règle de Classic, **à vérifier** sur Forever) : c'est la fenêtre où un call « reprendre X » sert le plus.
- Les guides Forever recommandent des macros pour les calls, parce que les add-ons ne peuvent pas écrire en BG (foreverbattlegrounds) : c'est exactement ce que fait déjà la roue.

## 2. Ce qui change par rapport au Goulet

| Goulet | Arathi |
|---|---|
| Tout tourne autour des deux porteurs (EFC, FC) | Pas de drapeau à porter : EFC, FC et CAP n'ont aucun sens |
| Lieux en double (chez nous / chez eux), couleur = côté | Chaque base existe une seule fois ; son « côté » change pendant la partie (qui la tient) |
| 6 lieux (anneau à 6 cases) | 5 bases : un pentagone, la texture `sector5` existe déjà |
| Anneau « côté » (FLIP) | Inutile |
| Anneau « nombre » | Gardé tel quel (ALL, 1, 2, 3, 5) |

## 3. Proposition de roue AB (à valider par Dany)

Même logique que le Goulet : attaque à droite, défense à gauche, urgence en haut.

**Étape 1, 5 actions (pentagone) :**

| Case | Action | Relâcher sur une base | Avec un nombre |
|---|---|---|---|
| 1 haut | **INC** | `INC: enemies coming at BS` | `INC: 3 enemies coming at BS` |
| 2 haut droite | **ATTACK** | `ATTACK: go take GM` | `ATTACK: 3 go take GM` |
| 3 bas droite | **RETAKE** (ils sont en train de la prendre) | `RETAKE: they are capping LM, retake it now` | `RETAKE: 2 retake LM now` |
| 4 bas gauche | **DEF** | `DEF: defend ST` | `DEF: 2 defend ST` |
| 5 haut gauche | **CLEAR** (rien en vue, base sûre) | `CLEAR: FARM is safe` | — |

**Étape 2, les 5 bases placées comme sur la carte** (le pentagone colle presque à la géographie) :
BS en haut (le centre ne peut pas être une case : c'est la zone morte), GM haut droite (NE), FARM bas droite (SE), LM bas gauche (SO), ST haut gauche (NO).
Pour un joueur Horde, la carte reste la même (nord en haut), comme la minicarte : pas de rotation.

Questions pour Dany :
1. Les 5 actions conviennent ? (RETAKE et CLEAR sont mes propositions ; alternatives : HELP, LOST.)
2. Bases fixes « nord en haut », ou tournées pour que notre départ soit toujours en bas ?
3. Couleur des bases : l'add-on pourrait colorer l'icône de chaque base selon son propriétaire actuel (bleu = à nous, rouge = à eux, gris = neutre ou contestée). C'est de l'affichage seulement (code non sécurisé, permis en combat), le message ne change pas. Possible seulement si Forever laisse lire l'état des bases en BG (voir § 5).
4. Les touches directes (« EFC only »…) : en AB, la 1re touche directe ouvrirait INC, la 2e ATTACK, etc. ? Ou des touches génériques « action 1 » à « action 5 » ? Renommer les touches existantes ferait perdre les raccourcis déjà réglés.

## 4. Changer de roue automatiquement selon le BG

### Détecter le BG

Le code détecte déjà l'entrée en BG (`IsInInstance()` → `"pvp"`, sur `PLAYER_ENTERING_WORLD` et `ZONE_CHANGED_NEW_AREA`, `Core.lua`). Il suffit d'ajouter *quel* BG :

| Méthode | Pour | Contre |
|---|---|---|
| `GetInstanceInfo()`, 8e valeur = `instanceID` | Un nombre, pas une langue. Classic : **489** = Goulet, **529** = Arathi, **30** = Alterac. Jeu actuel : **2106** = Goulet, **2107** = Arathi (warcraft.wiki.gg/InstanceID) | Forever tourne sur le moteur moderne (page Notion « Documentation API Forever ») : les IDs peuvent être ceux du jeu actuel ou ceux de Classic, **à vérifier** (accepter les deux). Pourrait être « secret » : **à vérifier** |
| `GetInstanceInfo()` 1re valeur, ou `GetRealZoneText()` | Toujours disponible | Nom traduit (« Bassin Arathi » en client français) : à garder en secours, avec les noms FR et EN |
| `C_Map.GetBestMapForUnit("player")` | uiMapID 1460 (Goulet), 1461 (Arathi) en Classic | La sonde dit la position indisponible en BG ; l'ID de carte peut-être aussi |

Choix proposé : `instanceID` d'abord, nom en secours, et sinon le Goulet (la roue actuelle). Hors BG : roue choisie avec `/cnc map wsg|ab|auto` pour s'entraîner.

### Quand changer la roue

Les attributs des cadres sécurisés ne changent que hors combat. Ça tombe bien : on arrive en BG par un écran de chargement, puis la phase de préparation, donc hors combat. Si jamais on est en combat, le code remet déjà la mise à jour à `PLAYER_REGEN_ENABLED` (`pendingSetup`).

### Comment (plan technique)

1. **Data.lua** : `ns.MAPS = { WSG = {...}, AB = {...} }` (actions, lieux, touches directes par carte) ; `ns.BuildTree(map)` prend la carte en paramètre. Le Goulet garde exactement ses chemins et messages : les tests et `web/situations.txt` le vérifient.
2. **Wheel.lua** : toutes les cartes chargées une fois à `Build()`, avec un préfixe dans les attributs (`WSG:m1-2`, `AB:next-3`...). Un seul attribut `map` choisit la roue ; les snippets sécurisés lisent `self:GetAttribute(map .. ":m" .. path)`. Changer de BG = changer un attribut, au lieu d'effacer puis réécrire des centaines d'attributs (plus sûr : aucun reste de l'ancienne roue).
3. **Anneau** : un anneau de plus, 5 cases avec centre, pour les bases d'AB (`{ n = 5, outer = 165, center = true }`). Les anneaux sont tous construits au chargement ; l'arbre de chaque carte dit lequel ouvrir.
4. **Core.lua** : `currentMap()` appelée là où `updatePrefix()` l'est déjà ; une ligne dans le rapport (`zone`, avec l'instanceID lu, pour confirmer les IDs Forever dès la première partie).
5. **Tests** (`tools/wheelsim.lua`, `tools/sim/wowemu.lua`) : émuler `GetInstanceInfo`, simuler chaque carte, vérifier le changement de carte et le report hors combat.
6. **Site** (repo `cnc-site`, qui télécharge l'add-on à chaque build) : le sélecteur de BG de la landing montre déjà Arathi « coming soon » ; il faudra la roue AB jouable, des situations AB au training ground et la carte d'Arathi (fichiers du jeu via wago.tools, coordonnées des bases).

## 5. À tester en jeu avec la sonde (avant de coder la détection)

D'abord chercher dans ForeverAPI (zmarotrix) et ForeverPlusPlus, les sources Forever listées sur la page Notion « Documentation API Forever ». Puis ajouter à `probe/CnCProbe` une commande qui affiche, au Goulet et en Arathi :

- toutes les valeurs de `GetInstanceInfo()` (surtout la 8e), `GetRealZoneText()`, `GetZoneText()`, `GetSubZoneText()`, et `issecretvalue` sur chacune si la fonction existe ;
- `C_Map.GetBestMapForUnit("player")` ;
- l'état des bases : `C_AreaPoiInfo.GetAreaPOIForMap(mapID)` puis `GetAreaPOIInfo` (la texture dit qui tient la base), ou les widgets de score (`C_UIWidgetManager`). Lisible = couleur des bases possible (question 3).

`GetSubZoneText()` donnerait le nom de la base où l'on est (« Blacksmith »...) : utile pour un futur « INC ici », mais seulement hors combat, puisque la roue sécurisée ne peut pas recevoir d'information nouvelle en combat. Idée à garder pour plus tard.

## Sources

Recherche web du 23/11/2026 (pages consultées via résumés de recherche ; la lecture directe de ces sites est bloquée depuis l'environnement de travail).

- [Battlegrounds, WoW Forever wiki (fextralife)](https://wowforever.wiki.fextralife.com/Battlegrounds)
- [WoW Forever Battlegrounds (Lore Forever)](https://loreforeverwow.com/guides/wow-forever-battlegrounds)
- [Arathi Basin in WoW Forever (wowforevertierlist)](https://wowforevertierlist.com/pvp/battlegrounds/arathi-basin)
- [WoW Forever Arathi Basin guide: map, openings and how to hold bases (wowforeverinfo)](https://wowforeverinfo.com/guides/arathi-basin/)
- [WoW Forever Arathi Basin Guide: 5 Bases, Tick Math (lfcarry)](https://lfcarry.com/guides/wow-forever-arathi-basin)
- [WoW Forever Beta Arathi Basin AB Strategy Guide (wowforever.games)](https://www.wowforever.games/611.html)
- [Arathi Basin Guide for WoW Forever (foreverbattlegrounds)](https://foreverbattlegrounds.com/battlegrounds/arathi-basin/)
- [Arathi Basin Guide, WoW Forever PvP (wowcalc)](https://wowcalc.net/en/forever/wiki/pvp/battlegrounds/arathi-basin)
- [Arathi Basin PvP Battleground Guide (Icy Veins, Classic)](https://icy-veins.com/wow-classic/arathi-basin-pvp-battleground-guide)
- [Arathi Basin Battleground Strategy, WoW Classic (Wowhead)](https://www.wowhead.com/classic/guide/arathi-basin-battleground-strategy-wow-classic)
- [Arathi Basin RBG guide, terminologie (Wowhead)](https://www.wowhead.com/cn/guide/arathi-basin-rated-battlegrounds-rbg-guide)
- [Abbreviation guide (warcraft.wiki.gg)](https://warcraft.wiki.gg/wiki/Abbreviation_guide)
- [Arathi Basin (Turtle WoW wiki)](https://turtle-wow.fandom.com/wiki/Arathi_Basin)
- [Victory in Arathi Basin, by Kaeldar (wow-pro)](https://www.wow-pro.com/pvpab-victory-in-arathi-basin-by-kaeldar-of-never-lose/)
- [Arathi Basin Strategy Guide (scoots, 18/03/2007)](https://scoots.wordpress.com/2007/03/18/arathi-basin-strategy-guide/)
- [PvPCallouts (GitHub)](https://github.com/73tone/PvPCallouts)
- [Battleground Callouts (CurseForge)](https://www.curseforge.com/wow/addons/battleground-callouts)
- [Highground Battlegrounds (CurseForge, compatible Forever)](https://www.curseforge.com/wow/addons/highground-battlegrounds)
- [InstanceID (warcraft.wiki.gg)](https://warcraft.wiki.gg/wiki/InstanceID)
- [API GetInstanceInfo (warcraft.wiki.gg)](https://warcraft.wiki.gg/wiki/API_GetInstanceInfo)
- [UiMapID (warcraft.wiki.gg)](https://warcraft.wiki.gg/wiki/UiMapID)
- [WoW Forever Addon Restrictions (wowforevertierlist)](https://wowforevertierlist.com/addons/restrictions)

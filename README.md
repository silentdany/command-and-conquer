# Command & Conquer

Add-on WoW: Forever (interface 16001) pour lancer des calls en Warsong Gulch avec une roue radiale.
Tout l'add-on est en anglais pour le moment.

**Geste : tenir la touche, glisser, relâcher.** Version 0.8 (refonte validée par Dany le 19/11/2026) : tout tourne autour des deux porteurs, plus des ordres très simples.

1. Tenir la touche de la roue : la roue s'ouvre sous le curseur.
2. Étape 1, 5 cases en pentagone : **EFC** (leur porteur, en haut), **ATTACK** (haut droite), **FC** (notre porteur, bas droite), **DEF** (bas gauche), **INC** (haut gauche). Attaque à droite, défense à gauche, urgence en haut.
3. Étape 2, les lieux en « pyramide », même disposition partout : salle du drapeau en haut, toit en haut à droite, rampe en bas à droite, mid en bas, cimetière (GY) en bas à gauche, tunnel en haut à gauche.
4. Relâcher : le message part en /bg (avec un ping ciblé si une cible convient).

La roue s'ouvre sous le curseur, puis chaque anneau sur la case choisie ; près d'un bord de l'écran, l'anneau (le premier aussi, depuis la 0.8.2) s'ouvre décalé juste assez pour rester entier. Si une case se retrouve alors sous le curseur, elle n'est prise qu'après un vrai mouvement. Chaque décalage est noté dans le rapport (`[fit ...]`, ou `norect` si le jeu ne donne pas la position des cases).

**Couleur = côté** : bleu = chez nous, rouge = chez eux. Jamais de mot à lire. Mid n'a pas de côté.

| Action | Relâcher après l'action | Étape 2 | Étapes optionnelles |
|---|---|---|---|
| EFC (leur porteur) | `EFC: attack their flag carrier` + ping | lieux en bleu (pas de salle) : `EFC: their flag carrier is at OUR RAMP` | grosse case en haut = même lieu en rouge (chez eux) ; CANCEL en bas à gauche |
| FC (notre porteur) | `FC: escort our carrier` + ping | CAP en haut (`CAP: our flag is home, cap now`), lieux en rouge : `FC: escort our carrier, THEIR TUNNEL` | grosse case en haut = même lieu en bleu ; CANCEL |
| DEF | — (centre = annuler) | lieux en bleu : `DEF: defend OUR FLAG ROOM` | nombre : ALL (haut), 1, 2, 3, CANCEL, 5 : `DEF: 3 defend OUR FLAG ROOM` |
| ATTACK | — | lieux en rouge : `ATTACK: attack THEIR ROOF` | nombre : `ATTACK: everyone attack THEIR ROOF` |
| INC | — | lieux en bleu : `INC: enemies coming at OUR TUNNEL` | case du haut = même lieu en rouge (scouting), puis nombre ; ou nombre directement : `INC: 3 enemies coming at OUR TUNNEL` |

Relâcher au centre d'une étape optionnelle envoie ce qui est déjà choisi ; la case **CANCEL** (croix rouge, toujours en bas à gauche) annule. Format des messages : abréviation pro en tête, phrase simple pour les novices, côté et lieu en majuscules. Carte complète : [CommandAndConquer/Data.lua](CommandAndConquer/Data.lua) (la même source sert à l'add-on, aux tests et à la page d'entraînement).

Touches directes (Échap > Raccourcis > AddOns) : « EFC only », « ATTACK only », « FC only », « DEF only », « INC only » ouvrent directement l'étape 2.

### Mode expérimental

- **Pas d'anti-spam** (décidé le 22/11/2026) : chaque relâchement envoie son call. Il demandait un minuteur sécurisé, qui ne marche pas sur Forever.
- **Expérimental** (`/cnc exp on`, éteint par défaut, chaque nouveauté avec repli automatique) :
  - `hover` : une case n'est prise qu'après 0,1 s sur son icône (contre les faux calls en glissant trop vite) ;
  - `undo` : retaper la touche (sans rien choisir) dans les 3 s après un call envoie « Ignore my last call » ;
  - `carrier` : pings et marque tête de mort sur les unités des portraits des porteurs (`/cnc carrier enemy arena1`, `/cnc carrier friend arena2`, unités à confirmer avec `/cnct carriers`), repli sur la cible ; « I have their flag » automatique si tu portes. Attention : le code source Blizzard ne met pas `UnitIsUnit` dans l'environnement sécurisé, donc cette dernière partie ne marchera que si Forever l'ajoute (le rapport le dit).
- Les fonctions minutées (hover, undo) reposent sur `RegisterAutoHide` ; un auto-test au chargement vérifie qu'il marche, sinon elles restent coupées. Sur Forever il ne marche pas (`/cnc timers`, 22/11/2026 : jamais déclenché en 20 s, à l'écran comme hors écran), donc hover et undo restent coupés.
- **Rapport** : l'add-on note ce qui a marché ou bloqué (auto-test, calls envoyés, actions bloquées) dans ses SavedVariables, à la déconnexion ou au `/reload`. `tools/update-cnc.bat` le copie dans le presse-papiers. `/cnc report` en affiche le résumé.

## Page d'entraînement (simulateur)

`web/` : une page où l'on s'entraîne à faire ses calls, sans lancer WoW. **La roue de la page, c'est la roue de l'add-on** : le navigateur exécute les vrais fichiers Lua de l'add-on (Data.lua, Wheel.lua, Core.lua… dans l'ordre du `.toc`) avec [wasmoon](https://github.com/ceifa/wasmoon), sur la même émulation de l'API WoW que les tests (`tools/sim/wowemu.lua`), avec les mêmes textures (exportées en PNG).

- **Entraînement** : une situation au hasard (croquis de la carte + consigne), la page compare le call envoyé au call attendu, mesure le temps, compte les erreurs, garde les meilleurs temps (navigateur). `N` = situation suivante.
- **Bac à sable** : roue libre, faux chat /bg, pings affichés, interrupteurs (combat, cible, options expérimentales, « je porte le drapeau »). Les commandes `/cnc` se tapent dans le chat.
- Touches : `Tab` ou `Espace` tenu, `1` à `5` pour les touches directes.
- Situations : [web/situations.txt](web/situations.txt), une ligne par situation, avec le call attendu en touches de la roue (`INC > TUN > 3`). Les tests vérifient que chaque situation existe encore dans la roue.
- Site : landing page de l'add-on (`web/landing/`) sur https://cnc.accura.dev, page d'entraînement sous `/training-ground/`. Vercel reconstruit et publie à chaque push (`vercel.json`, build en Node seul : `tools/tga2png.mjs` convertit les textures).
- Habillage : les deux pages ressemblent à un écran de jeu Forever (score, minicarte, cadres, chat, barre d'action), tout dessiné en CSS (`web/hud/hud.css`), sur des fonds originaux floutés par zone. Sons synthétisés (`web/sound.js`), coupables. Crédits : [web/CREDITS.md](web/CREDITS.md).
- En local : `npm ci --prefix web && node tools/build-web.mjs && python3 -m http.server -d _site`.

## Pourquoi « relâcher pour envoyer »

Testé en jeu le 17/11/2026 (Forever 1.60.1, build 70938) avec `probe/CnCProbe` :

| Contexte | Hors BG | Dans le Goulet |
|---|---|---|
| `SendChatMessage` appelé par un add-on | OK | Bloqué (`ADDON_ACTION_BLOCKED`) |
| Bouton sécurisé qui lance une macro `/bg …` sur un clic ou une touche du joueur | OK | **OK** |
| Lecture du chat par un add-on | OK | Contenu caché (« secret ») |
| Macro `/ping [@cible]` lancée par le bouton sécurisé | — | **OK** |
| Position du joueur sur la carte (`C_Map`, `UnitPosition`) | — | Indisponible |
| Ping de minicarte par un add-on (`Minimap:PingLocation`) | — | Bloqué (`ADDON_ACTION_BLOCKED`) |

La roue utilise donc un bouton sécurisé : tout le choix (action, lieu, nombre) se fait dans l'environnement sécurisé du jeu, et la macro part au relâchement de la touche, qui est une action du joueur.

## Installer

Copier le dossier `CommandAndConquer` dans `Interface/AddOns/` du client Forever.
Mises à jour (Windows) : copier `tools/update-cnc.bat` dans `Interface/AddOns/` et le double-cliquer à chaque nouvelle version, puis `/reload` en jeu.

Ensuite :

1. Échap > Raccourcis > AddOns : lier « C&C: wheel » à une touche (un bouton latéral de souris est idéal).
2. Automatique : en BG les calls partent en /bg ; ailleurs ils te sont chuchotés, pour t'entraîner.
3. `/cnc scale 1.3` : taille de la roue (0.6 à 2, défaut 1).
4. `/cnc ping` : pings avec les calls, oui ou non.
5. `/cnc status` : mode, taille, pings et touches liées.
6. `/cnc debug` : affiche dans le chat ce que la roue voit (diagnostic).

## Structure

| Dossier | Rôle |
|---|---|
| `CommandAndConquer/` | L'add-on |
| `probe/CnCProbe/` | Add-on de test : qu'est-ce qu'un add-on a le droit d'envoyer, et où |
| `.github/workflows/test.yml` | Tests automatiques à chaque push : syntaxe Lua, fichiers des `.toc`, icônes, simulation de la roue |
| `tools/update-cnc.bat` | Mise à jour en un double-clic depuis GitHub (Windows), à placer dans `Interface/AddOns/` |
| `tools/sim/wowemu.lua` | Émulation de l'API WoW (cadres, souris, raccourcis, code sécurisé, macros), partagée par les tests et la page |
| `tools/wheelsim.lua` | Test hors jeu de la roue : `lua5.1 tools/wheelsim.lua` (et `node tools/websim-check.mjs` : le même test en Lua 5.4, moteur de la page) |
| `web/`, `web/landing/`, `tools/build-web.mjs`, `vercel.json` | Page d'entraînement, landing page, construction et publication (Vercel) |
| `tools/make_media.py` | Génère les textures de la roue et les icônes (game-icons.net, CC BY 3.0, voir `CommandAndConquer/CREDITS.md`) |
| `docs/` | Carte v3 (historique ; la carte actuelle est Data.lua), recherche Arathi Basin et roue par BG (`recherche-arathi.md`) |

## Jalons

| Jalon | Statut |
|---|---|
| 1. Un add-on peut-il écrire en /bg sur Forever ? | Fait : non en direct, oui par bouton sécurisé |
| 2. Prototype de la roue (étapes 1 à 3) | v0.5 : 6 options par roue, SCOUT, EFC avec côté et escorteurs, étapes après la 2e optionnelles (clic droit abandonné : non fonctionnel sur Forever) |
| 3. Premier essai en BG réel | Fait (17/11) : les calls partent dans le canal Instance |
| 4. Refonte v0.8 (porteurs, pentagone, couleurs de côté) et page d'entraînement | Codé le 20/11, à tester en jeu |

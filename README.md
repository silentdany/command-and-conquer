# Command & Conquer

Add-on WoW: Forever (interface 16001) pour lancer des calls en Warsong Gulch avec une roue radiale.
Tout l'add-on est en anglais pour le moment.

**Geste : tenir la touche, glisser, relâcher.** 6 options maximum par roue.

1. Appuyer sur la touche de la roue et la garder enfoncée : la roue s'ouvre sous le curseur.
2. Glisser vers une action : DEF, FLAG, EFC, ATTACK, SCOUT, INC.
3. Glisser vers un choix (6 par action).
4. INC et SCOUT : glisser vers le nombre d'ennemis (INC : 1 à 5+ ; SCOUT : CLEAR, 1 à 5+), ou relâcher pour envoyer sans nombre.
5. Relâcher la touche : le message part en /bg. Revenir au centre avant de relâcher = rien n'est envoyé.

Clic droit = une étape en arrière ; deux clics droits de suite = fermer la roue.
Le choix se déclenche quand le curseur atteint l'icône d'une part ; la part visée s'éclaire avant.

Un même lieu garde la même direction dans toutes les actions, pour que la main apprenne le geste :

| Direction | Lieu |
|---|---|
| Haut | Salle du drapeau (FR / EFR) |
| Haut droite | Toit |
| Bas droite | Rampe |
| Bas | Tunnel |
| Bas gauche | Côté GY |
| Haut gauche | Mid |

Les options qui ne sont pas des lieux prennent la place du lieu le moins utile pour l'action (ESCORT pour DEF, ZERG pour ATTACK, HELP et CAP! pour FLAG).
Des touches directes (INC, SCOUT, EFC, FLAG, DEF, ATTACK) sautent l'étape 1.

Carte actuelle des messages : [CommandAndConquer/Data.lua](CommandAndConquer/Data.lua). Base de départ validée : [docs/mapping-roue-v3.md](docs/mapping-roue-v3.md) (8 choix, réduite à 6 le 17/11/2026).

## Pourquoi « relâcher pour envoyer »

Testé en jeu le 17/11/2026 (Forever 1.60.1, build 70938) avec `probe/CnCProbe` :

| Contexte | Hors BG | Dans le Goulet |
|---|---|---|
| `SendChatMessage` appelé par un add-on | OK | Bloqué (`ADDON_ACTION_BLOCKED`) |
| Bouton sécurisé qui lance une macro `/bg …` sur un clic ou une touche du joueur | OK | **OK** |
| Lecture du chat par un add-on | OK | Contenu caché (« secret ») |

La roue utilise donc un bouton sécurisé : tout le choix (action, lieu, nombre) se fait dans l'environnement sécurisé du jeu, et la macro part au relâchement de la touche, qui est une action du joueur.

## Installer

Copier le dossier `CommandAndConquer` dans `Interface/AddOns/` du client Forever.
Mises à jour (Windows) : copier `tools/update-cnc.bat` dans `Interface/AddOns/` et le double-cliquer à chaque nouvelle version, puis `/reload` en jeu.

Ensuite :

1. Échap > Raccourcis > AddOns : lier « C&C: wheel » à une touche (un bouton latéral de souris est idéal).
2. Automatique : en BG les calls partent en /bg ; ailleurs ils te sont chuchotés, pour t'entraîner.
3. `/cnc scale 1.3` : taille de la roue (0.6 à 2, défaut 1).
4. `/cnc status` : mode, taille et touches liées.

## Structure

| Dossier | Rôle |
|---|---|
| `CommandAndConquer/` | L'add-on |
| `probe/CnCProbe/` | Add-on de test : qu'est-ce qu'un add-on a le droit d'envoyer, et où |
| `tools/update-cnc.bat` | Mise à jour en un double-clic depuis GitHub (Windows), à placer dans `Interface/AddOns/` |
| `tools/wheelsim.lua` | Test hors jeu de la roue (émule l'API WoW et le code sécurisé) : `lua5.1 tools/wheelsim.lua CommandAndConquer` |
| `tools/make_media.py` | Génère les textures de la roue et les icônes (game-icons.net, CC BY 3.0, voir `CommandAndConquer/CREDITS.md`) |
| `docs/` | Carte des messages validée |

## Jalons

| Jalon | Statut |
|---|---|
| 1. Un add-on peut-il écrire en /bg sur Forever ? | Fait : non en direct, oui par bouton sécurisé |
| 2. Prototype de la roue (étapes 1 à 3) | v0.4 : 6 options par roue, action SCOUT, clic droit pour revenir ou fermer |
| 3. Premier essai en BG réel | À faire |

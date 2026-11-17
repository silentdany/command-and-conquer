# Command & Conquer

Add-on WoW (Classic Era / WoW: Forever) pour lancer des calls en Warsong Gulch avec une roue radiale.
Une touche ouvre la roue sous le curseur, on glisse la souris vers un choix, l'add-on écrit une phrase courte en anglais dans /bg.

- Étape 1 : action (DEF, ATTAQUE, INC, FLAG, RECUP)
- Étape 2 : 8 choix selon l'action
- Étape 3 : nombre d'ennemis (1 à 5+), seulement après INC

Carte complète des messages : [docs/mapping-roue-v3.md](docs/mapping-roue-v3.md).

## Où en est le projet

| Jalon | Statut |
|---|---|
| 1. Un add-on peut-il écrire en /bg sur Forever ? | Add-on de test prêt (`probe/CnCProbe`), à lancer en jeu |
| 2. Prototype de la roue (étapes 1 à 3) | Pas commencé, dépend du jalon 1 |
| 3. Premier essai en BG réel | Pas commencé |

## Jalon 1 : l'add-on de test (CnCProbe)

### Installer

Copier le dossier `probe/CnCProbe` dans `World of Warcraft/<version>/Interface/AddOns/`.
Si l'add-on est marqué « périmé », cocher « Charger les add-ons périmés » dans la liste des add-ons.

### Tester

1. `/cnct info` : version du client et API disponibles.
2. Hors BG, pour vérifier que tout marche : `/cnct run` (seul, il se chuchote à lui-même ; en groupe, il écrit en /p).
3. Dans le Goulet : `/cnct run`. Le rapport s'affiche au bout de ~9 s, avec un verdict.
4. Optionnel : lier une touche (Échap > Raccourcis > AddOns > Command & Conquer Probe), puis l'appuyer et la relâcher en BG.

Ce que le test mesure :

| Test | Contexte d'envoi | Ce que ça dit pour la roue |
|---|---|---|
| `slash` | Commande tapée (touche Entrée) | Envoi possible depuis une action du joueur |
| `binding` | Relâchement d'une touche liée | La roue peut envoyer au relâchement de sa touche |
| `timer` / `onupdate` | Code sans action du joueur | La roue peut envoyer dès le glissé, comme prévu |
| `addon` | Message add-on à add-on | Repli : seuls les joueurs équipés le voient |

`/cnct editbox` pré-remplit une ligne /bg (envoi manuel avec Entrée) : c'est le repli si tout est bloqué.

### Renvoyer les résultats

Le plus simple : une capture du rapport dans le chat.
Sinon, le fichier `WTF/Account/<COMPTE>/SavedVariables/CnCProbe.lua` garde les 30 derniers tests.

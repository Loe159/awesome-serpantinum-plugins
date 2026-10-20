# LPIC Daily — plugin Serpantinum

Compagnon quotidien pour [LPIC Daily](https://github.com/Loe159/lpic-daily) :
compteur d'activités dans la Bar, prochaine recommandation cliquable,
progression de couverture et de maîtrise, streak et activité des 14 derniers jours.

## Prérequis

- Serpantinum avec le système de plugins externes (API 1).
- LPIC Daily installé dans le `PATH`, avec `lpic status --json` et
  `lpic launch --next` (intégration introduite pour ce plugin).
- Python 3 pour ouvrir un terminal depuis le plugin.
- Un terminal configuré dans les paramètres du Launcher Serpantinum (ou un
  terminal courant pris en charge par le mécanisme de repli).

Installer le dépôt `awesome-serpantinum-plugins` depuis les paramètres Plugins
de Serpantinum. Le format multi-plugin installe ce dossier indépendamment
des autres plugins du dépôt. Le module LPIC Daily est ajouté à la Bar par défaut ;
son placement peut être modifié dans les paramètres de la Bar.

## Fonctionnement

Le plugin exécute `lpic status --json` au démarrage, à l'ouverture et toutes les
5 minutes. Pendant que la popup est ouverte, il actualise toutes les 5 secondes
pour refléter les activités terminées. Il n'accède pas directement à SQLite.

Un clic sur la prochaine activité lance `lpic launch --next` dans un terminal.
LPIC Daily recalcule la recommandation au moment du lancement ; les prérequis
et le choix cours/quiz/lab restent gérés par la TUI, avec les labs tmux habituels.

« Ouvrir ma séance » lance simplement `lpic`.
Les notifications restent gérées par LPIC Daily : aucun rappel doublon.

La popup utilise la palette, la typographie et le facteur d'échelle du thème
Serpantinum, avec animations d'ouverture/fermeture et positionnement sur
la Bar et l'écran d'origine. Un clic hors de la popup la ferme.

## Tester

```bash
python3 -m json.tool lpic-daily/plugin.json
python3 -m py_compile lpic-daily/services/launch.py
python3 -m unittest discover -s lpic-daily/services -p 'test_*.py'
```

Les tests d'intégration QML nécessitent une session Serpantinum/Quickshell
et sont distincts des tests Python.

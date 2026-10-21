# Todoist pour Serpantinum

Plugin communautaire indépendant : tâches Todoist dans la Bar, popup native et notifications.

## Installer

Installer le dossier `todoist/` via le gestionnaire de plugins communautaires.
Prérequis : Python 3, `libsecret` (`secret-tool`), `xdg-open` et `notify-send`.
Un trousseau Secret Service déverrouillé est nécessaire ; aucune clé API à copier.

Dans Paramètres → Plugins, activer Todoist puis ouvrir sa page de paramètres.\nCliquer sur **Se connecter** pour autoriser l'accès dans le navigateur. Ajouter `plugin:todoist` dans la Bar
via l'interface native. Le premier clic sur le logo rouge ouvre aussi l'écran de connexion.
La connexion OAuth enregistre un client public Todoist avec PKCE ; le callback est
reçu sur le loopback local pendant trois minutes. Les jetons sont sauvegardés
uniquement dans Secret Service.

## Fonctions

- Bar : logo Todoist et compteur des tâches du jour.
- Quatre onglets : Aujourd'hui (avec retards), À venir, Boîte de réception, Projets.
- Quick Add Todoist en langage naturel ; création détaillée.
- Terminer / annuler, éditer, modifier la priorité, reporter au lendemain,
  déplacer de projet.
- Synchronisation après les mutations, à l'ouverture, toutes les cinq minutes
  et sur Refresh (animation de 1,2 s).
- Cache de dernière synchronisation hors connexion.
- Notifications d'échéances proches (délai 5/15/30/60/120 min) et de retards,
  dédupliquées par tâche et par échéance.

Les notifications utilisent `notify-send`, avec logo SVG local, et ne permettent
pas encore d'ouvrir directement une tâche.

## Tests

```bash
python3 -m unittest discover -s todoist/services -p 'test_*.py' -v
python3 -m json.tool todoist/plugin.json
SERPANTINUM_TARGET_FILE="$PWD/todoist/Plugin.qml" \
  QT_QPA_PLATFORM=offscreen quickshell -p /chemin/serpantinum/src/quickshell/Runner.qml
```

Un avertissement `No PanelWindow backend loaded` est normal en offscreen.
Un essai interactif Wayland et l'autorisation d'un vrai compte sont nécessaires
pour valider la connexion de bout en bout.

## Paramètres natifs

La page **Paramètres → Plugins → Todoist** contient la connexion/déconnexion OAuth,
la fréquence de synchronisation (1, 5, 15 ou 30 minutes, 5 par défaut),
un bouton Refresh et les notifications d'échéances et de retards. L'anticipation
des rappels est configurable (5, 15, 30, 60 ou 120 minutes).
Les interrupteurs utilisent les composants natifs Serpantinum.

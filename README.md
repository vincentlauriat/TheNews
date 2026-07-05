# TheNews

Outil de **veille d'information multi-sources** pour macOS + iOS/iPadOS, en SwiftUI (codebase partagé).
TheNews agrège dans une **même interface** les flux RSS du *Monde* **et** des *Echos*, te laisse
suivre les rubriques qui t'intéressent (tous journaux confondus), définir des **sujets de veille**
par mots-clés, et t'**alerte** localement quand un nouvel article correspond — sans serveur,
100 % sur l'appareil.

> Mix de [NewsWatch](../TheWorld) (*Le Monde*) et [LesEchos](../LesEchos) : même architecture,
> déjà agnostique de la source, réunie en une seule app **multi-journaux**.

## Fonctionnalités

| Fonctionnalité | macOS | iOS/iPadOS |
|---|:---:|:---:|
| **Deux journaux agrégés** : Le Monde (11 rubriques) + Les Echos (9 rubriques) | ✅ | ✅ |
| Sidebar **groupée par journal** (une section par source) | ✅ | ✅ |
| Abonnement / désabonnement par rubrique, toutes sources | ✅ | ✅ |
| Vue « Tous les articles » (agrégation multi-flux, multi-sources) | ✅ | ✅ |
| Sujets de veille par mots-clés (insensible casse/accents) | ✅ | ✅ |
| Section « Alertes » + badge d'articles non lus | ✅ | ✅ |
| Favoris & « tout marquer comme lu » | ✅ | ✅ |
| Navigation entre articles par swipe horizontal | — | ✅ |
| Notifications locales sur nouveaux articles suivis | ✅ | ✅ |
| Rafraîchissement en tâche de fond | périodique (30 min) | `BGAppRefreshTask` |
| Réglages : apparence, langue (fr/en), notifications | ✅ | ✅ |

> Le flux RSS ne fournit que le titre, le chapô et l'image ; l'article complet s'ouvre dans le
> navigateur (réservé aux abonnés du journal concerné).

## Build

Prérequis : Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate            # génère TheNews.xcodeproj
open TheNews.xcodeproj        # macOS : scheme TheNews — iOS : scheme TheNewsiOS
```

## Release (macOS)

```bash
./Scripts/release.sh 1.0.0   # build → sign Developer ID → DMG → notarize → staple
```

## Architecture

Voir [`ARCHITECTURE.md`](ARCHITECTURE.md). En bref :

```
TheNews/
├── TheNewsApp.swift            # @main — SwiftData container, BGTask (iOS), delegate notifs
├── Models/                     # Source (Le Monde + Les Echos), Feed (catalogue combiné), Article, FeedSubscription, WatchTopic
├── ViewModels/FeedViewModel    # portée (tous/alertes/favoris/rubrique), refresh parallèle multi-sources
├── Views/                      # sidebar groupée par source, liste, détail, réglages, éditeur de sujets
├── Services/                   # RSSParser, RSSService, FeedStore, SubscriptionStore,
│                               # MatchingEngine, NotificationService, RefreshEngine
├── Localization/               # AppSettings + tables fr/en
└── Assets.xcassets/            # AppIcon
Scripts/                        # release.sh, make-thenews-icon.swift, make-dmg-background.swift
project.yml                     # config XcodeGen (2 cibles, 2 schemes)
```

Aucune dépendance externe : parsing `XMLParser`, persistance **SwiftData**, notifications
`UserNotifications`, tâches de fond `BackgroundTasks` — tout natif. **Ajouter un 3ᵉ journal** ne
demande qu'une entrée dans `Source.all` + un catalogue `Feed` (voir ARCHITECTURE.md).

## Licence

MIT — voir [`LICENSE`](LICENSE).
